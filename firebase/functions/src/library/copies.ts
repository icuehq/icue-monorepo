import '../region';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { claimUniqueKey, nextNumber, uniqueKeyRef } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText, usable } from '../shared/masters';
import { holdDays, hold, nextWaiting, release } from './reservations';
import { isoDate } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';

const text = z.string().trim().min(1).max(120);
const CONDITIONS = ['good', 'fair', 'poor'] as const;

/** Statuses a librarian may set by hand; issued / reserved / in_transit belong to circulation and transfers. */
const MANUAL = ['available', 'under_maintenance', 'damaged', 'lost', 'withdrawn'] as const;
const TERMINAL = ['lost', 'withdrawn'];

export const accessionNumber = (sequence: number) => `ACC-${String(sequence).padStart(6, '0')}`;

async function loadCopy(context: CallableContext, copyId: string) {
  const ref = context.doc(`libraryCopies/${copyId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryCopy');
  const copy = snapshot.data()!;
  context.requireCampus(copy.campusId);
  return { ref, copy };
}

export const copies = {
  /**
   * Records books entering a library (FRS 11.6) and creates one copy per unit.
   * Accession numbers come from one school-wide counter and double as the copy's
   * document ID and barcode, so they cannot repeat.
   */
  acquisitionCreate: defineCallable({
    name: 'library.acquisition.create',
    permission: 'library.catalogue.manage',
    input: z.object({
      type: z.enum(['purchase', 'donation', 'opening']),
      catalogueId: id,
      libraryId: id,
      quantity: z.number().int().min(1).max(100),
      date: isoDate.optional(),
      vendorOrDonor: text.nullish(),
      price: z.number().min(0).max(10_000_000).default(0),
      reference: text.nullish(),
      remarks: optionalText,
      shelf: text.nullish(),
      condition: z.enum(CONDITIONS).default('good'),
    }),
    handler: async (context, i) => {
      if (i.type === 'purchase' && i.price <= 0) throw failed('A purchase needs a price');
      const library = usable(await context.transaction.get(context.doc(`libraries/${i.libraryId}`)), 'Library', false);
      context.requireCampus(library.campusId);
      usable(await context.transaction.get(context.doc(`libraryCatalogue/${i.catalogueId}`)), 'Title', false);

      const counter = context.doc('counters/ACC');
      const first = (((await context.transaction.get(counter)).data()?.next as number | undefined) ?? 0) + 1;
      context.set(counter, { next: first + i.quantity - 1, updatedAt: serverTimestamp() });

      const date = i.date ?? new Date().toISOString().slice(0, 10);
      const acq = context.newDoc('libraryAcquisitions');
      const number = await nextNumber(context, 'ACQ');
      const ids = Array.from({ length: i.quantity }, (_, offset) => accessionNumber(first + offset));
      ids.forEach((copyId) =>
        context.set(context.doc(`libraryCopies/${copyId}`), {
          accessionNumber: copyId,
          catalogueId: i.catalogueId,
          libraryId: i.libraryId,
          campusId: library.campusId,
          shelf: i.shelf ?? null,
          barcode: copyId,
          rfidTag: null,
          acquisitionId: acq.id,
          acquiredDate: date,
          price: i.price,
          source: i.type,
          vendorOrDonor: i.vendorOrDonor ?? null,
          condition: i.condition,
          status: 'available',
          remarks: i.remarks ?? null,
          activeLoanId: null,
          heldReservationId: null,
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        }),
      );
      const after = {
        number,
        type: i.type,
        catalogueId: i.catalogueId,
        libraryId: i.libraryId,
        campusId: library.campusId,
        quantity: i.quantity,
        date,
        vendorOrDonor: i.vendorOrDonor ?? null,
        price: i.price,
        reference: i.reference ?? null,
        remarks: i.remarks ?? null,
        copyIds: ids,
      };
      // New copies serve the waiting list first, in queue order.
      const waiting = await nextWaiting(context, i.catalogueId, i.libraryId, i.quantity);
      const days = waiting.length ? await holdDays(context) : 0;
      for (const [index, snapshot] of waiting.entries()) await hold(context, snapshot, context.doc(`libraryCopies/${ids[index]}`), ids[index], days);
      context.set(acq, { ...after, createdAt: serverTimestamp(), createdBy: context.uid });
      context.audit({ action: 'libraryAcquisition.create', documentPath: acq.path, after });
      return { id: acq.id, number, copyIds: ids };
    },
  }),

  /** Shelf, condition, remarks and RFID tag. Status and library have their own callables. */
  copyUpdate: defineCallable({
    name: 'library.copy.update',
    permission: 'library.catalogue.manage',
    input: z.object({
      id,
      shelf: text.nullish(),
      condition: z.enum(CONDITIONS),
      remarks: optionalText,
      rfidTag: z.string().trim().min(1).max(64).nullish(),
    }),
    handler: async (context, i) => {
      const { ref, copy } = await loadCopy(context, i.id);
      const tag = i.rfidTag ?? null;
      if (tag) await claimUniqueKey(context, 'libraryRfid', tag, ref.path);
      if (copy.rfidTag && copy.rfidTag.toLowerCase() !== tag?.toLowerCase()) context.delete(uniqueKeyRef(context, 'libraryRfid', copy.rfidTag));
      const after = { shelf: i.shelf ?? null, condition: i.condition, remarks: i.remarks ?? null, rfidTag: tag };
      context.update(ref, { ...after, updatedAt: serverTimestamp() });
      context.audit({ action: 'libraryCopy.update', documentPath: ref.path, before: { shelf: copy.shelf, condition: copy.condition, remarks: copy.remarks, rfidTag: copy.rfidTag }, after });
      return { id: ref.id };
    },
  }),

  /** Moves an available copy to another library (a copy belongs to one library at a time). */
  copyMove: defineCallable({
    name: 'library.copy.move',
    permission: 'library.catalogue.manage',
    input: z.object({ id, libraryId: id, shelf: text.nullish() }),
    handler: async (context, i) => {
      const { ref, copy } = await loadCopy(context, i.id);
      if (copy.status !== 'available') throw failed(`Copy is ${copy.status}`);
      if (copy.libraryId === i.libraryId) throw failed('Copy is already in this library');
      const library = usable(await context.transaction.get(context.doc(`libraries/${i.libraryId}`)), 'Library', false);
      context.requireCampus(library.campusId);
      const after = { libraryId: i.libraryId, campusId: library.campusId, shelf: i.shelf ?? null };
      context.update(ref, { ...after, updatedAt: serverTimestamp() });
      context.audit({ action: 'libraryCopy.move', documentPath: ref.path, before: { libraryId: copy.libraryId, shelf: copy.shelf }, after });
      return { id: ref.id };
    },
  }),

  /** Maintenance, damage, loss and withdrawal. Lost and withdrawn copies never become available again. */
  copySetStatus: defineCallable({
    name: 'library.copy.setStatus',
    permission: 'library.catalogue.manage',
    input: z.object({ id, status: z.enum(MANUAL), reason: z.string().trim().max(500).nullish() }),
    handler: async (context, i) => {
      const { ref, copy } = await loadCopy(context, i.id);
      if (TERMINAL.includes(copy.status)) throw failed(`Copy is ${copy.status}`);
      if (!MANUAL.includes(copy.status)) throw failed(`Copy is ${copy.status}`);
      if (copy.status === i.status) return { id: ref.id };
      if (i.status !== 'available' && i.status !== 'under_maintenance' && !i.reason) throw failed('A reason is required');
      if (i.status === 'available') await release(context, ref, copy);
      else context.update(ref, { status: i.status, updatedAt: serverTimestamp() });
      context.audit({ action: 'libraryCopy.status', documentPath: ref.path, before: { status: copy.status }, after: { status: i.status }, reason: i.reason ?? undefined });
      return { id: ref.id };
    },
  }),
};
