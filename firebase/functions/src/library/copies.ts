import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { Ctx } from '../shared/callable';
import { claimUniqueKey, nextNumber, uniqueKeyRef } from '../shared/keys';
import { def, failed, id, missing, note, usable } from '../shared/masters';
import { holdDays, hold, nextWaiting, release } from './reservations';

const text = z.string().trim().min(1).max(120);
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const CONDITIONS = ['good', 'fair', 'poor'] as const;
const UP = () => FieldValue.serverTimestamp();

/** Statuses a librarian may set by hand; issued / reserved / in_transit belong to circulation and transfers. */
const MANUAL = ['available', 'under_maintenance', 'damaged', 'lost', 'withdrawn'] as const;
const TERMINAL = ['lost', 'withdrawn'];

export const accessionNo = (n: number) => `ACC-${String(n).padStart(6, '0')}`;

async function loadCopy(ctx: Ctx, copyId: string) {
  const ref = ctx.doc(`libCopies/${copyId}`);
  const snap = await ctx.tx.get(ref);
  if (!snap.exists) throw missing('libCopy');
  const d = snap.data()!;
  ctx.requireCampus(d.campusId);
  return { ref, d };
}

export const copies = {
  /**
   * Records books entering a library (FRS 11.6) and creates one copy per unit.
   * Accession numbers come from one school-wide counter and double as the copy's
   * document ID and barcode, so they cannot repeat.
   */
  acquisitionCreate: def({
    name: 'lib.acquisition.create',
    perm: 'lib.catalogue.manage',
    input: z.object({
      type: z.enum(['purchase', 'donation', 'opening']),
      catalogueId: id,
      libraryId: id,
      qty: z.number().int().min(1).max(100),
      date: day.optional(),
      vendorOrDonor: text.nullish(),
      price: z.number().min(0).max(10_000_000).default(0),
      reference: text.nullish(),
      remarks: note,
      shelf: text.nullish(),
      condition: z.enum(CONDITIONS).default('good'),
    }),
    handler: async (ctx, i) => {
      if (i.type === 'purchase' && i.price <= 0) throw failed('A purchase needs a price');
      const lib = usable(await ctx.tx.get(ctx.doc(`libLibraries/${i.libraryId}`)), 'Library', false);
      ctx.requireCampus(lib.campusId);
      usable(await ctx.tx.get(ctx.doc(`libCatalogue/${i.catalogueId}`)), 'Title', false);

      const counter = ctx.doc('counters/ACC');
      const first = (((await ctx.tx.get(counter)).data()?.next as number | undefined) ?? 0) + 1;
      ctx.set(counter, { next: first + i.qty - 1, updatedAt: UP() });

      const date = i.date ?? new Date().toISOString().slice(0, 10);
      const acq = ctx.newDoc('libAcquisitions');
      const number = await nextNumber(ctx, 'ACQ');
      const ids = Array.from({ length: i.qty }, (_, n) => accessionNo(first + n));
      ids.forEach((acc) =>
        ctx.set(ctx.doc(`libCopies/${acc}`), {
          accessionNo: acc,
          catalogueId: i.catalogueId,
          libraryId: i.libraryId,
          campusId: lib.campusId,
          shelf: i.shelf ?? null,
          barcode: acc,
          rfidTag: null,
          acquisitionId: acq.id,
          acquiredOn: date,
          price: i.price,
          source: i.type,
          vendorOrDonor: i.vendorOrDonor ?? null,
          condition: i.condition,
          status: 'available',
          remarks: i.remarks ?? null,
          activeLoanId: null,
          heldReservationId: null,
          createdAt: UP(),
          createdBy: ctx.uid,
          updatedAt: UP(),
        }),
      );
      const after = {
        number,
        type: i.type,
        catalogueId: i.catalogueId,
        libraryId: i.libraryId,
        campusId: lib.campusId,
        qty: i.qty,
        date,
        vendorOrDonor: i.vendorOrDonor ?? null,
        price: i.price,
        reference: i.reference ?? null,
        remarks: i.remarks ?? null,
        copyIds: ids,
      };
      // New copies serve the waiting list first, in queue order.
      const waiting = await nextWaiting(ctx, i.catalogueId, i.libraryId, i.qty);
      const days = waiting.length ? await holdDays(ctx) : 0;
      for (const [n, w] of waiting.entries()) await hold(ctx, w, ctx.doc(`libCopies/${ids[n]}`), ids[n], days);
      ctx.set(acq, { ...after, createdAt: UP(), createdBy: ctx.uid });
      ctx.audit({ action: 'libAcquisition.create', ref: acq.path, after });
      return { id: acq.id, number, copyIds: ids };
    },
  }),

  /** Shelf, condition, remarks and RFID tag. Status and library have their own callables. */
  copyUpdate: def({
    name: 'lib.copy.update',
    perm: 'lib.catalogue.manage',
    input: z.object({
      id,
      shelf: text.nullish(),
      condition: z.enum(CONDITIONS),
      remarks: note,
      rfidTag: z.string().trim().min(1).max(64).nullish(),
    }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadCopy(ctx, i.id);
      const tag = i.rfidTag ?? null;
      if (tag) await claimUniqueKey(ctx, 'libRfid', tag, ref.path);
      if (d.rfidTag && d.rfidTag.toLowerCase() !== tag?.toLowerCase()) ctx.delete(uniqueKeyRef(ctx, 'libRfid', d.rfidTag));
      const after = { shelf: i.shelf ?? null, condition: i.condition, remarks: i.remarks ?? null, rfidTag: tag };
      ctx.update(ref, { ...after, updatedAt: UP() });
      ctx.audit({ action: 'libCopy.update', ref: ref.path, before: { shelf: d.shelf, condition: d.condition, remarks: d.remarks, rfidTag: d.rfidTag }, after });
      return { id: ref.id };
    },
  }),

  /** Moves an available copy to another library (a copy belongs to one library at a time). */
  copyMove: def({
    name: 'lib.copy.move',
    perm: 'lib.catalogue.manage',
    input: z.object({ id, libraryId: id, shelf: text.nullish() }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadCopy(ctx, i.id);
      if (d.status !== 'available') throw failed(`Copy is ${d.status}`);
      if (d.libraryId === i.libraryId) throw failed('Copy is already in this library');
      const lib = usable(await ctx.tx.get(ctx.doc(`libLibraries/${i.libraryId}`)), 'Library', false);
      ctx.requireCampus(lib.campusId);
      const after = { libraryId: i.libraryId, campusId: lib.campusId, shelf: i.shelf ?? null };
      ctx.update(ref, { ...after, updatedAt: UP() });
      ctx.audit({ action: 'libCopy.move', ref: ref.path, before: { libraryId: d.libraryId, shelf: d.shelf }, after });
      return { id: ref.id };
    },
  }),

  /** Maintenance, damage, loss and withdrawal. Lost and withdrawn copies never become available again. */
  copySetStatus: def({
    name: 'lib.copy.setStatus',
    perm: 'lib.catalogue.manage',
    input: z.object({ id, status: z.enum(MANUAL), reason: z.string().trim().max(500).nullish() }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadCopy(ctx, i.id);
      if (TERMINAL.includes(d.status)) throw failed(`Copy is ${d.status}`);
      if (!MANUAL.includes(d.status)) throw failed(`Copy is ${d.status}`);
      if (d.status === i.status) return { id: ref.id };
      if (i.status !== 'available' && i.status !== 'under_maintenance' && !i.reason) throw failed('A reason is required');
      if (i.status === 'available') await release(ctx, ref, d);
      else ctx.update(ref, { status: i.status, updatedAt: UP() });
      ctx.audit({ action: 'libCopy.status', ref: ref.path, before: { status: d.status }, after: { status: i.status }, reason: i.reason ?? undefined });
      return { id: ref.id };
    },
  }),
};
