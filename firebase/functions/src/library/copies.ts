import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { CopyStatus, manualCopyStatuses, terminalCopyStatuses } from '../shared/contracts';
import { dayTimestamp, isoDate, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextSequence } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText, usable } from '../shared/masters';

const text = z.string().trim().min(1).max(120);
const CONDITIONS = ['good', 'fair', 'poor'] as const;

/** Most copies one call creates: 200 copy writes plus the record, counter and audit stay under Firestore's 500 writes per transaction. */
const MAX_COPIES = 200;

/** Barcodes the system issues; scanned ones may not use this shape, so they never take a future number. */
const GENERATED = /^LB\d{6,}$/i;

async function loadCopy(context: CallableContext, barcode: string) {
  const ref = context.doc(`libraryCopies/${barcode}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('Book copy');
  const copy = snapshot.data()!;
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
      quantity: z.number().int().min(1).max(MAX_COPIES),
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
        .max(MAX_COPIES)
        .optional(),
      /** Per-copy shelf, condition, price and acquisition date, in copy order; a missing value takes the one above. Lets one call carry a whole title's copies (bulk import). */
      details: z
        .array(
          z.object({
            shelf: text.nullish(),
            condition: z.enum(CONDITIONS).optional(),
            price: z.number().min(0).max(10_000_000).optional(),
            date: isoDate.optional(),
          }),
        )
        .max(MAX_COPIES)
        .optional(),
    }),
    handler: async (context, i) => {
      if (i.barcodes && i.barcodes.length !== i.quantity)
        throw failed('Enter one barcode per copy');
      if (i.barcodes && new Set(i.barcodes.map((code) => code.toLowerCase())).size !== i.quantity)
        throw failed('Barcodes must be different for every copy');
      if (i.details && i.details.length !== i.quantity)
        throw failed('Enter the details of every copy');
      const [librarySnapshot, titleSnapshot] = await context.transaction.getAll(
        context.doc(`libraries/${i.libraryId}`),
        context.doc(`libraryCatalogue/${i.catalogueId}`),
      );
      usable(librarySnapshot, 'Library', false);
      usable(titleSnapshot, 'Title', false);

      const date = dayTimestamp(i.date ?? todayIST());
      const book = context.newDoc('libraryBooks');
      const ids =
        i.barcodes ??
        (await nextSequence(context, 'libraryCopy', i.quantity)).map(
          (sequence) => `LB${String(sequence).padStart(6, '0')}`,
        );
      // One batched read instead of a round trip per copy; the counter is read last so its lock is held briefly.
      const refs = ids.map((barcode) => context.doc(`libraryCopies/${barcode}`));
      const existing = (await context.transaction.getAll(...refs)).find(
        (snapshot) => snapshot.exists,
      );
      if (existing)
        throw new HttpsError('already-exists', `Barcode "${existing.id}" already exists`);
      let totalPrice = 0;
      ids.forEach((barcode, index) => {
        const detail = i.details?.[index];
        const price = detail?.price ?? i.price;
        totalPrice += price;
        context.set(refs[index], {
          catalogueId: i.catalogueId,
          libraryId: i.libraryId,
          shelf: detail?.shelf ?? i.shelf ?? null,
          barcode,
          bookId: book.id,
          acquiredDate: detail?.date ? dayTimestamp(detail.date) : date,
          price,
          condition: detail?.condition ?? i.condition,
          status: CopyStatus.available,
          remarks: i.remarks ?? null,
          activeLoanId: null,
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        });
      });
      const after = {
        catalogueId: i.catalogueId,
        libraryId: i.libraryId,
        quantity: i.quantity,
        date,
        price: i.price,
        totalPrice,
        reference: i.reference ?? null,
        remarks: i.remarks ?? null,
        barcodes: ids,
      };
      context.set(book, { ...after, createdAt: serverTimestamp(), createdBy: context.uid });
      context.audit({ action: 'libraryBook.create', documentPath: book.path, after });
      return { id: book.id, barcodes: ids };
    },
  }),

  /** Maintenance, damage, loss and withdrawal. Lost and withdrawn copies never become available again here (a lost copy that turns up is put back by dismissing its incident). */
  copySetStatus: defineCallable({
    name: 'library.copy.setStatus',
    input: z.object({
      id,
      status: z.enum(manualCopyStatuses),
      reason: z.string().trim().max(500).nullish(),
    }),
    handler: async (context, i) => {
      const { ref, copy } = await loadCopy(context, i.id);
      if ((terminalCopyStatuses as readonly string[]).includes(copy.status))
        throw failed(`Copy is ${copy.status}`);
      if (!(manualCopyStatuses as readonly string[]).includes(copy.status))
        throw failed(`Copy is ${copy.status}`);
      if (copy.status === i.status) return { id: ref.id };
      if (
        i.status !== CopyStatus.available &&
        i.status !== CopyStatus.underMaintenance &&
        !i.reason
      )
        throw failed('A reason is required');
      context.update(ref, { status: i.status, updatedAt: serverTimestamp() });
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
