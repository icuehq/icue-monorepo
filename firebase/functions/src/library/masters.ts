import '../region';
import { z } from 'zod';
import { claimUniqueKey, uniqueKeyRef } from '../shared/keys';
import { code, defineCallable, failed, id, missing, name, optionalText, saveMaster, defineSetStatus, usable } from '../shared/masters';
import { DEFAULT_CATEGORIES } from './defaults';
import { cleanIsbn, isIsbn10, isIsbn13, toIsbn13 } from './isbn';
import { serverTimestamp } from '../shared/firestore';

const text = (max: number) => z.string().trim().min(1).max(max);
const norm = (value: string | null | undefined) => (value ?? '').toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean).join(' ');

/** Identity of a title: the ISBN-13 when there is one, else the bibliographic details. */
export function identityKey(title: { isbn13: string | null; title: string; authors: string[]; edition?: string | null; publisher?: string | null; year?: number | null }) {
  return title.isbn13
    ? `isbn:${title.isbn13}`
    : `bib:${[title.title, title.authors[0], title.edition, title.publisher].map(norm).join('|')}|${title.year ?? ''}`;
}

export const masters = {
  libraryUpsert: defineCallable({
    name: 'library.library.upsert',
    permission: 'library.settings',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      campusId: z.number().int(),
      description: optionalText,
      location: optionalText,
      staffIds: z.array(z.number().int()).max(20).default([]),
      contact: optionalText,
      hours: optionalText,
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'libraries',
        entityType: 'library',
        id: i.id,
        code: i.code,
        build: async (before) => {
          if (before && before.campusId !== i.campusId) throw failed('A library cannot move to another campus');
          return {
            name: i.name,
            campusId: i.campusId,
            description: i.description ?? null,
            location: i.location ?? null,
            staffIds: [...new Set(i.staffIds)],
            contact: i.contact ?? null,
            hours: i.hours ?? null,
          };
        },
      }),
  }),
  librarySetStatus: defineSetStatus('library.library.setStatus', 'library.settings', 'libraries', 'library'),

  categoryUpsert: defineCallable({
    name: 'library.category.upsert',
    permission: 'library.catalogue.manage',
    input: z.object({ id: id.optional(), code: code.optional(), name, description: optionalText, parentId: id.nullish() }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'libraryCategories',
        entityType: 'libraryCategory',
        id: i.id,
        code: i.code,
        build: async (before) => {
          if (i.parentId) {
            if (i.parentId === i.id) throw failed('A category cannot be its own parent');
            const parent = usable(await context.transaction.get(context.doc(`libraryCategories/${i.parentId}`)), 'Parent category', before?.parentId === i.parentId);
            if (parent.parentId) throw failed('Only one level of subcategories is supported');
          }
          return { name: i.name, description: i.description ?? null, parentId: i.parentId ?? null };
        },
      }),
  }),
  categorySetStatus: defineSetStatus('library.category.setStatus', 'library.catalogue.manage', 'libraryCategories', 'libraryCategory'),

  catalogueUpsert: defineCallable({
    name: 'library.catalogue.upsert',
    permission: 'library.catalogue.manage',
    input: z.object({
      id: id.optional(),
      title: text(200),
      subtitle: text(200).nullish(),
      authors: z.array(text(100)).min(1).max(10),
      isbn10: z.string().trim().max(20).nullish(),
      isbn13: z.string().trim().max(20).nullish(),
      publisher: text(120).nullish(),
      edition: text(50).nullish(),
      year: z.number().int().min(1000).max(2200).nullish(),
      language: text(50).nullish(),
      categoryId: id,
      description: z.string().trim().max(2000).nullish(),
      pages: z.number().int().min(1).max(100000).nullish(),
      classificationNumber: text(50).nullish(),
      keywords: z.array(text(50)).max(20).default([]),
    }),
    handler: async (context, i) => {
      const i10 = i.isbn10 ? cleanIsbn(i.isbn10) : null;
      const i13 = i.isbn13 ? cleanIsbn(i.isbn13) : null;
      if (i10 && !isIsbn10(i10)) throw failed('Invalid ISBN-10');
      if (i13 && !isIsbn13(i13)) throw failed('Invalid ISBN-13');
      if (i10 && i13 && toIsbn13(i10) !== i13) throw failed('ISBN-10 and ISBN-13 are different books');
      const isbn13 = i13 ?? (i10 ? toIsbn13(i10) : null);
      const key = identityKey({ ...i, isbn13 });

      const now = serverTimestamp();
      const before = i.id ? (await context.transaction.get(context.doc(`libraryCatalogue/${i.id}`))).data() : undefined;
      if (i.id && !before) throw missing('libraryCatalogue');
      const ref = i.id ? context.doc(`libraryCatalogue/${i.id}`) : context.newDoc('libraryCatalogue');
      usable(await context.transaction.get(context.doc(`libraryCategories/${i.categoryId}`)), 'Category', before?.categoryId === i.categoryId);
      if (!before || before.identityKey !== key) {
        await claimUniqueKey(context, 'libraryTitle', key, ref.path);
        if (before) context.delete(uniqueKeyRef(context, 'libraryTitle', before.identityKey));
      }

      const after = {
        title: i.title,
        subtitle: i.subtitle ?? null,
        authors: i.authors,
        isbn10: i10,
        isbn13: i13,
        publisher: i.publisher ?? null,
        edition: i.edition ?? null,
        year: i.year ?? null,
        language: i.language ?? null,
        categoryId: i.categoryId,
        description: i.description ?? null,
        pages: i.pages ?? null,
        classificationNumber: i.classificationNumber ?? null,
        keywords: i.keywords,
        identityKey: key,
      };
      if (before) {
        context.update(ref, { ...after, updatedAt: now });
        context.audit({ action: 'libraryCatalogue.update', documentPath: ref.path, before, after });
      } else {
        // Known limit: `coverPath` stays null until the upload path (`files-getUploadPath`) exists.
        context.set(ref, { ...after, coverPath: null, status: 'active', createdAt: now, createdBy: context.uid, updatedAt: now });
        context.audit({ action: 'libraryCatalogue.create', documentPath: ref.path, after });
      }
      return { id: ref.id };
    },
  }),
  catalogueSetStatus: defineSetStatus('library.catalogue.setStatus', 'library.catalogue.manage', 'libraryCatalogue', 'libraryCatalogue'),

  /** Adds the FRS default book categories that do not exist yet. Safe to repeat. */
  seedDefaults: defineCallable({
    name: 'library.seedDefaults',
    permission: 'library.catalogue.manage',
    input: z.object({}),
    handler: async (context) => {
      const now = serverTimestamp();
      const keys = DEFAULT_CATEGORIES.map((category) => uniqueKeyRef(context, 'libraryCategory', category.code));
      const snapshots = await context.transaction.getAll(...keys);
      let categories = 0;
      DEFAULT_CATEGORIES.forEach((category, index) => {
        if (snapshots[index].exists) return;
        const ref = context.newDoc('libraryCategories');
        context.set(keys[index], { keyType: 'libraryCategory', value: category.code.toLowerCase(), documentPath: ref.path });
        context.set(ref, {
          code: category.code, name: category.name, description: null, parentId: null,
          status: 'active', createdAt: now, createdBy: context.uid, updatedAt: now,
        });
        categories++;
      });
      context.audit({ action: 'library.seedDefaults', documentPath: `schools/${context.schoolId}`, after: { categories } });
      return { categories };
    },
  }),
};
