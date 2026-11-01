import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { todayIST } from '../inventory/stock';
import type { Ctx } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { def, failed, id, missing, note, usable } from '../shared/masters';
import { holdDays, hold, nextWaiting } from './reservations';

const UP = () => FieldValue.serverTimestamp();
const CONDITIONS = ['good', 'fair', 'poor'] as const;
const MAX_COPIES = 100;

async function loadTransfer(ctx: Ctx, transferId: string, campus: 'campusId' | 'toCampusId') {
  const ref = ctx.doc(`libTransfers/${transferId}`);
  const snap = await ctx.tx.get(ref);
  if (!snap.exists) throw missing('libTransfer');
  const d = snap.data()!;
  ctx.requireCampus(d[campus]);
  return { ref, d };
}

/** Inter-library transfers (FRS 11.15): request → approval → dispatch → receipt. A copy in transit cannot be issued. */
export const transfers = {
  transferRequest: def({
    name: 'lib.transfer.request',
    perm: 'lib.catalogue.manage',
    input: z.object({
      fromLibraryId: id,
      toLibraryId: id,
      copyIds: z.array(id).min(1).max(MAX_COPIES),
      remarks: note,
    }),
    handler: async (ctx, i) => {
      if (i.fromLibraryId === i.toLibraryId) throw failed('Source and destination must differ');
      if (new Set(i.copyIds).size !== i.copyIds.length) throw failed('A copy is listed twice');
      const from = usable(await ctx.tx.get(ctx.doc(`libLibraries/${i.fromLibraryId}`)), 'Source library', false);
      const to = usable(await ctx.tx.get(ctx.doc(`libLibraries/${i.toLibraryId}`)), 'Destination library', false);
      ctx.requireCampus(from.campusId);
      const snaps = await ctx.tx.getAll(...i.copyIds.map((c) => ctx.doc(`libCopies/${c}`)));
      const lines = snaps.map((s) => {
        const c = s.data();
        if (!c) throw missing('libCopy');
        if (c.libraryId !== i.fromLibraryId) throw failed(`${s.id} is not in the source library`);
        if (c.status !== 'available') throw failed(`${s.id} is ${c.status}`);
        return { copyId: s.id, accessionNo: c.accessionNo, catalogueId: c.catalogueId, received: false, condition: null };
      });
      const ref = ctx.newDoc('libTransfers');
      const number = await nextNumber(ctx, 'LTR');
      const after = {
        number,
        fromLibraryId: i.fromLibraryId,
        toLibraryId: i.toLibraryId,
        campusId: from.campusId,
        toCampusId: to.campusId,
        lines,
        status: 'requested',
        requestedOn: todayIST(),
        remarks: i.remarks ?? null,
      };
      ctx.set(ref, { ...after, requestedBy: ctx.uid, createdAt: UP(), updatedAt: UP() });
      ctx.audit({ action: 'libTransfer.request', ref: ref.path, after });
      return { id: ref.id, number };
    },
  }),

  /** Approval is a separate permission from requesting, so one person cannot do both without `lib.settings`. */
  transferApprove: def({
    name: 'lib.transfer.approve',
    perm: 'lib.settings',
    input: z.object({ id }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadTransfer(ctx, i.id, 'campusId');
      if (d.status !== 'requested') throw failed(`Transfer is ${d.status}`);
      ctx.update(ref, { status: 'approved', approvedBy: ctx.uid, approvedOn: todayIST(), updatedAt: UP() });
      ctx.audit({ action: 'libTransfer.approve', ref: ref.path, before: { status: d.status }, after: { status: 'approved' } });
      return { id: ref.id };
    },
  }),

  /** Every copy must still be on the shelf; they leave circulation as `in_transit`. */
  transferDispatch: def({
    name: 'lib.transfer.dispatch',
    perm: 'lib.catalogue.manage',
    input: z.object({ id }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadTransfer(ctx, i.id, 'campusId');
      if (d.status !== 'approved') throw failed(`Transfer is ${d.status}`);
      const snaps = await ctx.tx.getAll(...(d.lines as Array<{ copyId: string }>).map((l) => ctx.doc(`libCopies/${l.copyId}`)));
      for (const s of snaps) {
        if (s.data()?.status !== 'available' || s.data()?.libraryId !== d.fromLibraryId) throw failed(`${s.id} is no longer available`);
      }
      for (const s of snaps) ctx.update(s.ref, { status: 'in_transit', transferId: ref.id, updatedAt: UP() });
      ctx.update(ref, { status: 'dispatched', dispatchedBy: ctx.uid, dispatchedOn: todayIST(), updatedAt: UP() });
      ctx.audit({ action: 'libTransfer.dispatch', ref: ref.path, before: { status: d.status }, after: { status: 'dispatched' } });
      return { id: ref.id };
    },
  }),

  /**
   * Confirms arrival of some or all copies at the destination. Each arrived copy changes library and is
   * offered to the destination's waiting list before going on the shelf. Copies not yet received stay in transit.
   */
  transferReceive: def({
    name: 'lib.transfer.receive',
    perm: 'lib.catalogue.manage',
    input: z.object({
      id,
      copies: z.array(z.object({ copyId: id, condition: z.enum(CONDITIONS).default('good') })).min(1).max(MAX_COPIES),
      shelf: z.string().trim().min(1).max(120).nullish(),
      remarks: note,
    }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadTransfer(ctx, i.id, 'toCampusId');
      if (d.status !== 'dispatched' && d.status !== 'partially_received') throw failed(`Transfer is ${d.status}`);
      const ids = i.copies.map((c) => c.copyId);
      if (new Set(ids).size !== ids.length) throw failed('A copy is listed twice');
      const lines = d.lines as Array<{ copyId: string; received: boolean; condition: string | null }>;
      for (const c of i.copies) {
        const line = lines.find((l) => l.copyId === c.copyId);
        if (!line) throw failed(`${c.copyId} is not part of this transfer`);
        if (line.received) throw failed(`${c.copyId} was already received`);
      }
      const snaps = await ctx.tx.getAll(...ids.map((c) => ctx.doc(`libCopies/${c}`)));
      // Titles with a waiting list at the destination serve it first, in queue order (as new acquisitions do).
      const waiting = new Map<string, Awaited<ReturnType<typeof nextWaiting>>>();
      for (const [n, s] of snaps.entries()) {
        const c = s.data();
        if (c?.status !== 'in_transit' || c.transferId !== ref.id) throw failed(`${s.id} is not in transit on this transfer`);
        const condition = i.copies[n].condition;
        ctx.update(s.ref, { libraryId: d.toLibraryId, campusId: d.toCampusId, shelf: i.shelf ?? null, condition, transferId: null, updatedAt: UP() });
        if (!waiting.has(c.catalogueId)) {
          const need = snaps.filter((x) => x.data()?.catalogueId === c.catalogueId).length;
          waiting.set(c.catalogueId, await nextWaiting(ctx, c.catalogueId, d.toLibraryId, need));
        }
        const next = waiting.get(c.catalogueId)!.shift();
        if (next) await hold(ctx, next, s.ref, s.id, await holdDays(ctx));
        else ctx.update(s.ref, { status: 'available', heldReservationId: null, activeLoanId: null });
        const line = lines.find((l) => l.copyId === s.id)!;
        line.received = true;
        line.condition = condition;
      }
      const status = lines.every((l) => l.received) ? 'received' : 'partially_received';
      ctx.update(ref, {
        lines,
        status,
        receivedBy: ctx.uid,
        ...(status === 'received' ? { receivedOn: todayIST() } : {}),
        ...(i.remarks ? { receiptRemarks: i.remarks } : {}),
        updatedAt: UP(),
      });
      ctx.audit({ action: 'libTransfer.receive', ref: ref.path, before: { status: d.status }, after: { status, copyIds: ids } });
      return { id: ref.id, status };
    },
  }),
};
