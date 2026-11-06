import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { dayTimestamp, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { openIncident } from './incidents';
import { holdDays, hold, nextWaiting } from './reservations';

const CONDITIONS = ['good', 'fair', 'poor'] as const;
const MAX_COPIES = 100;

async function loadTransfer(
  context: CallableContext,
  transferId: string,
  campus: 'campusId' | 'toCampusId',
) {
  const ref = context.doc(`libraryTransfers/${transferId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryTransfer');
  const transfer = snapshot.data()!;
  context.requireCampus(transfer[campus]);
  return { ref, transfer };
}

/** Inter-library transfers (FRS 11.15): request → approval → dispatch → receipt. A copy in transit cannot be issued. */
export const transfers = {
  transferRequest: defineCallable({
    name: 'library.transfer.request',
    permission: 'library.catalogue',
    input: z.object({
      fromLibraryId: id,
      toLibraryId: id,
      copyIds: z.array(id).min(1).max(MAX_COPIES),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      if (i.fromLibraryId === i.toLibraryId) throw failed('Source and destination must differ');
      if (new Set(i.copyIds).size !== i.copyIds.length) throw failed('A copy is listed twice');
      const from = usable(
        await context.transaction.get(context.doc(`libraries/${i.fromLibraryId}`)),
        'Source library',
        false,
      );
      const destinationLibrary = usable(
        await context.transaction.get(context.doc(`libraries/${i.toLibraryId}`)),
        'Destination library',
        false,
      );
      context.requireCampus(from.campusId);
      const snapshots = await context.transaction.getAll(
        ...i.copyIds.map((copyId) => context.doc(`libraryCopies/${copyId}`)),
      );
      const lineItems = snapshots.map((snapshot) => {
        const toLibraryData = snapshot.data();
        if (!toLibraryData) throw missing('libraryCopy');
        if (toLibraryData.libraryId !== i.fromLibraryId)
          throw failed(`${snapshot.id} is not in the source library`);
        if (toLibraryData.status !== 'available')
          throw failed(`${snapshot.id} is ${toLibraryData.status}`);
        return {
          copyId: snapshot.id,
          accessionNumber: toLibraryData.accessionNumber,
          catalogueId: toLibraryData.catalogueId,
          received: false,
          condition: null,
        };
      });
      const ref = context.newDoc('libraryTransfers');
      const number = await nextNumber(context, 'LTR');
      const after = {
        number,
        fromLibraryId: i.fromLibraryId,
        toLibraryId: i.toLibraryId,
        campusId: from.campusId,
        toCampusId: destinationLibrary.campusId,
        lineItems,
        status: 'requested',
        requestedDate: dayTimestamp(todayIST()),
        remarks: i.remarks ?? null,
      };
      context.set(ref, {
        ...after,
        requestedBy: context.uid,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      await enqueue(context, `library-transfer-request__${ref.id}`, {
        to: { permission: 'library.settings', campusId: from.campusId },
        category: 'library.transfer',
        title: 'Transfer needs approval',
        body: `${number}: ${i.copyIds.length} copies from ${from.name} to ${destinationLibrary.name}.`,
        data: { transferId: ref.id },
      });
      context.audit({ action: 'libraryTransfer.request', documentPath: ref.path, after });
      return { id: ref.id, number };
    },
  }),

  /** Approval is a separate permission from requesting, so one person cannot do both without `library.settings`. */
  transferApprove: defineCallable({
    name: 'library.transfer.approve',
    permission: 'library.settings',
    input: z.object({ id }),
    handler: async (context, i) => {
      const { ref, transfer } = await loadTransfer(context, i.id, 'campusId');
      if (transfer.status !== 'requested') throw failed(`Transfer is ${transfer.status}`);
      context.update(ref, {
        status: 'approved',
        approvedBy: context.uid,
        approvedDate: dayTimestamp(todayIST()),
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'libraryTransfer.approve',
        documentPath: ref.path,
        before: { status: transfer.status },
        after: { status: 'approved' },
      });
      return { id: ref.id };
    },
  }),

  /** Withdraws or rejects a transfer before dispatch; the copies never left the shelf. */
  transferCancel: defineCallable({
    name: 'library.transfer.cancel',
    permission: 'library.catalogue',
    input: z.object({ id, reason: z.string().trim().min(1).max(500) }),
    handler: async (context, i) => {
      const { ref, transfer } = await loadTransfer(context, i.id, 'campusId');
      if (transfer.status !== 'requested' && transfer.status !== 'approved')
        throw failed(`Transfer is ${transfer.status}`);
      context.update(ref, {
        status: 'cancelled',
        cancelReason: i.reason,
        cancelledBy: context.uid,
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'libraryTransfer.cancel',
        documentPath: ref.path,
        before: { status: transfer.status },
        reason: i.reason,
      });
      return { id: ref.id };
    },
  }),

  /** Every copy must still be on the shelf; they leave circulation as `in_transit`. */
  transferDispatch: defineCallable({
    name: 'library.transfer.dispatch',
    permission: 'library.catalogue',
    input: z.object({ id }),
    handler: async (context, i) => {
      const { ref, transfer } = await loadTransfer(context, i.id, 'campusId');
      if (transfer.status !== 'approved') throw failed(`Transfer is ${transfer.status}`);
      const snapshots = await context.transaction.getAll(
        ...(transfer.lineItems as { copyId: string }[]).map((lineItem) =>
          context.doc(`libraryCopies/${lineItem.copyId}`),
        ),
      );
      for (const snapshot of snapshots) {
        if (
          snapshot.data()?.status !== 'available' ||
          snapshot.data()?.libraryId !== transfer.fromLibraryId
        )
          throw failed(`${snapshot.id} is no longer available`);
      }
      for (const snapshot of snapshots)
        context.update(snapshot.ref, {
          status: 'in_transit',
          transferId: ref.id,
          updatedAt: serverTimestamp(),
        });
      context.update(ref, {
        status: 'dispatched',
        dispatchedBy: context.uid,
        dispatchedDate: dayTimestamp(todayIST()),
        updatedAt: serverTimestamp(),
      });
      await enqueue(context, `library-transfer-dispatch__${ref.id}`, {
        to: { permission: 'library.catalogue', campusId: transfer.toCampusId },
        category: 'library.transfer',
        title: 'Books on the way',
        body: `${transfer.number}: ${snapshots.length} copies dispatched to your library.`,
        data: { transferId: ref.id },
      });
      context.audit({
        action: 'libraryTransfer.dispatch',
        documentPath: ref.path,
        before: { status: transfer.status },
        after: { status: 'dispatched' },
      });
      return { id: ref.id };
    },
  }),

  /**
   * Confirms arrival of some or all copies at the destination. Each arrived copy changes library and is
   * offered to the destination's waiting list before going on the shelf. Copies not yet received stay in transit.
   */
  transferReceive: defineCallable({
    name: 'library.transfer.receive',
    permission: 'library.catalogue',
    input: z.object({
      id,
      copies: z
        .array(z.object({ copyId: id, condition: z.enum(CONDITIONS).default('good') }))
        .min(1)
        .max(MAX_COPIES),
      shelf: z.string().trim().min(1).max(120).nullish(),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      const { ref, transfer } = await loadTransfer(context, i.id, 'toCampusId');
      if (transfer.status !== 'dispatched' && transfer.status !== 'partially_received')
        throw failed(`Transfer is ${transfer.status}`);
      const ids = i.copies.map((copy) => copy.copyId);
      if (new Set(ids).size !== ids.length) throw failed('A copy is listed twice');
      const lineItems = transfer.lineItems as {
        copyId: string;
        received: boolean;
        condition: string | null;
      }[];
      for (const copy of i.copies) {
        const line = lineItems.find((lineItem) => lineItem.copyId === copy.copyId);
        if (!line) throw failed(`${copy.copyId} is not part of this transfer`);
        if (line.received) throw failed(`${copy.copyId} was already received`);
      }
      const snapshots = await context.transaction.getAll(
        ...ids.map((copyId) => context.doc(`libraryCopies/${copyId}`)),
      );
      // Titles with a waiting list at the destination serve it first, in queue order (as new acquisitions do).
      const waiting = new Map<string, Awaited<ReturnType<typeof nextWaiting>>>();
      for (const [index, snapshot] of snapshots.entries()) {
        const copyDocument = snapshot.data();
        if (copyDocument?.status !== 'in_transit' || copyDocument.transferId !== ref.id)
          throw failed(`${snapshot.id} is not in transit on this transfer`);
        const condition = i.copies[index].condition;
        context.update(snapshot.ref, {
          libraryId: transfer.toLibraryId,
          campusId: transfer.toCampusId,
          shelf: i.shelf ?? null,
          condition,
          transferId: null,
          updatedAt: serverTimestamp(),
        });
        if (!waiting.has(copyDocument.catalogueId)) {
          const need = snapshots.filter(
            (other) => other.data()?.catalogueId === copyDocument.catalogueId,
          ).length;
          waiting.set(
            copyDocument.catalogueId,
            await nextWaiting(context, copyDocument.catalogueId, transfer.toLibraryId, need),
          );
        }
        const next = waiting.get(copyDocument.catalogueId)!.shift();
        if (next) await hold(context, next, snapshot.ref, snapshot.id, await holdDays(context));
        else
          context.update(snapshot.ref, {
            status: 'available',
            heldReservationId: null,
            activeLoanId: null,
          });
        const line = lineItems.find((lineItem) => lineItem.copyId === snapshot.id)!;
        line.received = true;
        line.condition = condition;
      }
      const status = lineItems.every((lineItem) => lineItem.received)
        ? 'received'
        : 'partially_received';
      context.update(ref, {
        lineItems,
        status,
        receivedBy: context.uid,
        ...(status === 'received' ? { receivedDate: dayTimestamp(todayIST()) } : {}),
        ...(i.remarks ? { receiptRemarks: i.remarks } : {}),
        updatedAt: serverTimestamp(),
      });
      await enqueue(
        context,
        `library-transfer-receive__${ref.id}__${status}__${lineItems.filter((lineItem) => lineItem.received).length}`,
        {
          to: { permission: 'library.catalogue', campusId: transfer.campusId },
          category: 'library.transfer',
          title: 'Transfer received',
          body: `${transfer.number}: ${status === 'received' ? 'all copies' : `${ids.length} copies`} received at the destination.`,
          data: { transferId: ref.id },
        },
      );
      context.audit({
        action: 'libraryTransfer.receive',
        documentPath: ref.path,
        before: { status: transfer.status },
        after: { status, copyIds: ids },
      });
      return { id: ref.id, status };
    },
  }),

  /** Closes a transfer whose remaining copies never arrived: each is marked lost and gets an incident. */
  transferCloseShort: defineCallable({
    name: 'library.transfer.closeShort',
    permission: 'library.catalogue',
    input: z.object({ id, reason: z.string().trim().min(1).max(500) }),
    handler: async (context, i) => {
      const { ref, transfer } = await loadTransfer(context, i.id, 'toCampusId');
      if (transfer.status !== 'dispatched' && transfer.status !== 'partially_received')
        throw failed(`Transfer is ${transfer.status}`);
      const missingIds = (transfer.lineItems as { copyId: string; received: boolean }[])
        .filter((lineItem) => !lineItem.received)
        .map((lineItem) => lineItem.copyId);
      if (!missingIds.length) throw failed('Every copy has arrived');
      const snapshots = await context.transaction.getAll(
        ...missingIds.map((copyId) => context.doc(`libraryCopies/${copyId}`)),
      );
      for (const snapshot of snapshots) {
        const copy = snapshot.data();
        if (!copy) throw missing('libraryCopy');
        context.update(snapshot.ref, {
          status: 'lost',
          transferId: null,
          updatedAt: serverTimestamp(),
        });
        await openIncident(context, {
          type: 'lost',
          copy,
          copyId: snapshot.id,
          severity: null,
          description: `Lost in transit (${transfer.number}): ${i.reason}`,
          charge: 0,
          repairStatus: null,
          title: 'Lost book recorded',
          body: `${copy.accessionNumber} did not arrive in transfer ${transfer.number}.`,
        });
      }
      context.update(ref, {
        status: 'received',
        closedShort: true,
        shortfall: missingIds,
        closeReason: i.reason,
        receivedDate: dayTimestamp(todayIST()),
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'libraryTransfer.closeShort',
        documentPath: ref.path,
        after: { shortfall: missingIds },
        reason: i.reason,
      });
      return { id: ref.id, shortfall: missingIds.length };
    },
  }),
};
