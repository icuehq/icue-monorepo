import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { dayTimestamp, isoDate, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber, nextSequence } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText, usable } from '../shared/masters';
import { holdDays, hold, nextWaiting, release } from './reservations';

const text = z.string().trim().min(1).max(120);
const CONDITIONS = ['good', 'fair', 'poor'] as const;

/** Statuses a librarian may set by hand; issued / reserved / in_transit belong to circulation and transfers. */
const MANUAL = ['available', 'under_maintenance', 'damaged', 'lost', 'withdrawn'] as const;
const TERMINAL = ['lost', 'withdrawn'];

/** Barcodes the system issues; scanned ones may not use this shape, so they never take a future number. */
const GENERATED = /^LB\d{6,}$/i;

async function loadCopy(context: CallableContext, barcode: string) {
  const ref = context.doc(`libraryCopies/${barcode}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryCopy');
  const copy = snapshot.data()!;
  context.requireCampus(copy.campusId);
  return { ref, copy };
}

export const copies = {
  /**
   * Records books entering a library (FRS 11.6) and creates one copy per unit.
   * The scanned barcode is the copy's document ID, so it cannot repeat.
   */
  createBook: defineCallable({
    name: 'library.book.create',
    input: z.object({
      catalogueId: id,
      libraryId: id,
      quantity: z.number().int().min(1).max(100),
      date: isoDate.optional(),
      price: z.number().min(0).max(10_000_000).default(0),
      reference: text.nullish(),
      remarks: optionalText,
      shelf: text.nullish(),
      condition: z.enum(CONDITIONS).default('good'),
      /** Scanned barcode of each copy, in order; it becomes the copy's document ID. Omitted: the system issues `LB000123` codes. */
      barcodes: z
        .array(
          z
            .string()
            .trim()
            .min(1)
            .max(64)
            .regex(/^[^/]+$/, 'Barcode cannot contain /')
            .refine((code) => !GENERATED.test(code), 'LB barcodes are issued by the system'),
        )
        .min(1)
        .max(100)
        .optional(),
    }),
    handler: async (context, i) => {
      if (i.barcodes && i.barcodes.length !== i.quantity)
        throw failed('Enter one barcode per copy');
      if (i.barcodes && new Set(i.barcodes.map((code) => code.toLowerCase())).size !== i.quantity)
        throw failed('Barcodes must be different for every copy');
      const library = usable(
        await context.transaction.get(context.doc(`libraries/${i.libraryId}`)),
        'Library',
        false,
      );
      context.requireCampus(library.campusId);
      usable(
        await context.transaction.get(context.doc(`libraryCatalogue/${i.catalogueId}`)),
        'Title',
        false,
      );

      const date = dayTimestamp(i.date ?? todayIST());
      const book = context.newDoc('libraryBooks');
      const number = await nextNumber(context, 'ACQ');
      const ids =
        i.barcodes ??
        (await nextSequence(context, 'libraryCopy', i.quantity)).map(
          (sequence) => `LB${String(sequence).padStart(6, '0')}`,
        );
      for (const barcode of ids) {
        const ref = context.doc(`libraryCopies/${barcode}`);
        if ((await context.transaction.get(ref)).exists)
          throw new HttpsError('already-exists', `Barcode "${barcode}" already exists`);
        context.set(ref, {
          catalogueId: i.catalogueId,
          libraryId: i.libraryId,
          campusId: library.campusId,
          shelf: i.shelf ?? null,
          barcode,
          bookId: book.id,
          acquiredDate: date,
          price: i.price,
          condition: i.condition,
          status: 'available',
          remarks: i.remarks ?? null,
          activeLoanId: null,
          heldReservationId: null,
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        });
      }
      const after = {
        number,
        catalogueId: i.catalogueId,
        libraryId: i.libraryId,
        campusId: library.campusId,
        quantity: i.quantity,
        date,
        price: i.price,
        reference: i.reference ?? null,
        remarks: i.remarks ?? null,
        barcodes: ids,
      };
      // New copies serve the waiting list first, in queue order.
      const waiting = await nextWaiting(context, i.catalogueId, i.libraryId, i.quantity);
      const days = waiting.length ? await holdDays(context) : 0;
      for (const [index, snapshot] of waiting.entries())
        await hold(context, snapshot, context.doc(`libraryCopies/${ids[index]}`), ids[index], days);
      context.set(book, { ...after, createdAt: serverTimestamp(), createdBy: context.uid });
      context.audit({ action: 'libraryBook.create', documentPath: book.path, after });
      return { id: book.id, number, barcodes: ids };
    },
  }),

  /** Maintenance, damage, loss and withdrawal. Lost and withdrawn copies never become available again here (a lost copy that turns up is released by dismissing its incident). */
  copySetStatus: defineCallable({
    name: 'library.copy.setStatus',
    input: z.object({ id, status: z.enum(MANUAL), reason: z.string().trim().max(500).nullish() }),
    handler: async (context, i) => {
      const { ref, copy } = await loadCopy(context, i.id);
      if (TERMINAL.includes(copy.status)) throw failed(`Copy is ${copy.status}`);
      if (!MANUAL.includes(copy.status)) throw failed(`Copy is ${copy.status}`);
      if (copy.status === i.status) return { id: ref.id };
      if (i.status !== 'available' && i.status !== 'under_maintenance' && !i.reason)
        throw failed('A reason is required');
      if (i.status === 'available') await release(context, ref, copy);
      else context.update(ref, { status: i.status, updatedAt: serverTimestamp() });
      context.audit({
        action: 'libraryCopy.status',
        documentPath: ref.path,
        before: { status: copy.status },
        after: { status: i.status },
        reason: i.reason ?? undefined,
      });
      return { id: ref.id };
    },
  }),
};
