import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { claimUniqueKey, uniqueKeyRef } from '../shared/keys';
import { code, def, failed, id, missing, name, note, saveMaster, setStatusDef, usable } from '../shared/masters';
import { DEFAULT_CATEGORIES } from './defaults';
import { cleanIsbn, isIsbn10, isIsbn13, toIsbn13 } from './isbn';

const text = (max: number) => z.string().trim().min(1).max(max);
const norm = (s: string | null | undefined) => (s ?? '').toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean).join(' ');

/** Identity of a title: the ISBN-13 when there is one, else the bibliographic details. */
export function dupKey(c: { isbn13: string | null; title: string; authors: string[]; edition?: string | null; publisher?: string | null; year?: number | null }) {
  return c.isbn13
    ? `isbn:${c.isbn13}`
    : `bib:${[c.title, c.authors[0], c.edition, c.publisher].map(norm).join('|')}|${c.year ?? ''}`;
}

export const masters = {
  libraryUpsert: def({
    name: 'lib.library.upsert',
    perm: 'lib.settings',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      campusId: z.number().int(),
      description: note,
      location: note,
      staffIds: z.array(z.number().int()).max(20).default([]),
      contact: note,
      hours: note,
    }),
    handler: (ctx, i) =>
      saveMaster(ctx, {
        coll: 'libLibraries',
        kind: 'libLibrary',
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
  librarySetStatus: setStatusDef('lib.library.setStatus', 'lib.settings', 'libLibraries', 'libLibrary'),

  categoryUpsert: def({
    name: 'lib.category.upsert',
    perm: 'lib.catalogue.manage',
    input: z.object({ id: id.optional(), code: code.optional(), name, description: note, parentId: id.nullish() }),
    handler: (ctx, i) =>
      saveMaster(ctx, {
        coll: 'libCategories',
        kind: 'libCategory',
        id: i.id,
        code: i.code,
        build: async (before) => {
          if (i.parentId) {
            if (i.parentId === i.id) throw failed('A category cannot be its own parent');
            const parent = usable(await ctx.tx.get(ctx.doc(`libCategories/${i.parentId}`)), 'Parent category', before?.parentId === i.parentId);
            if (parent.parentId) throw failed('Only one level of subcategories is supported');
          }
          return { name: i.name, description: i.description ?? null, parentId: i.parentId ?? null };
        },
      }),
  }),
  categorySetStatus: setStatusDef('lib.category.setStatus', 'lib.catalogue.manage', 'libCategories', 'libCategory'),

  catalogueUpsert: def({
    name: 'lib.catalogue.upsert',
    perm: 'lib.catalogue.manage',
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
      classNo: text(50).nullish(),
      keywords: z.array(text(50)).max(20).default([]),
    }),
    handler: async (ctx, i) => {
      const i10 = i.isbn10 ? cleanIsbn(i.isbn10) : null;
      const i13 = i.isbn13 ? cleanIsbn(i.isbn13) : null;
      if (i10 && !isIsbn10(i10)) throw failed('Invalid ISBN-10');
      if (i13 && !isIsbn13(i13)) throw failed('Invalid ISBN-13');
      if (i10 && i13 && toIsbn13(i10) !== i13) throw failed('ISBN-10 and ISBN-13 are different books');
      const isbn13 = i13 ?? (i10 ? toIsbn13(i10) : null);
      const key = dupKey({ ...i, isbn13 });

      const now = FieldValue.serverTimestamp();
      const before = i.id ? (await ctx.tx.get(ctx.doc(`libCatalogue/${i.id}`))).data() : undefined;
      if (i.id && !before) throw missing('libCatalogue');
      const ref = i.id ? ctx.doc(`libCatalogue/${i.id}`) : ctx.newDoc('libCatalogue');
      usable(await ctx.tx.get(ctx.doc(`libCategories/${i.categoryId}`)), 'Category', before?.categoryId === i.categoryId);
      if (!before || before.dupKey !== key) {
        await claimUniqueKey(ctx, 'libTitle', key, ref.path);
        if (before) ctx.delete(uniqueKeyRef(ctx, 'libTitle', before.dupKey));
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
        classNo: i.classNo ?? null,
        keywords: i.keywords,
        dupKey: key,
      };
      if (before) {
        ctx.update(ref, { ...after, updatedAt: now });
        ctx.audit({ action: 'libCatalogue.update', ref: ref.path, before, after });
      } else {
        // ponytail: `coverPath` stays null until the upload path (`files-getUploadPath`) exists.
        ctx.set(ref, { ...after, coverPath: null, status: 'active', createdAt: now, createdBy: ctx.uid, updatedAt: now });
        ctx.audit({ action: 'libCatalogue.create', ref: ref.path, after });
      }
      return { id: ref.id };
    },
  }),
  catalogueSetStatus: setStatusDef('lib.catalogue.setStatus', 'lib.catalogue.manage', 'libCatalogue', 'libCatalogue'),

  /** Adds the FRS default book categories that do not exist yet. Safe to repeat. */
  seedDefaults: def({
    name: 'lib.seedDefaults',
    perm: 'lib.catalogue.manage',
    input: z.object({}),
    handler: async (ctx) => {
      const now = FieldValue.serverTimestamp();
      const keys = DEFAULT_CATEGORIES.map((c) => uniqueKeyRef(ctx, 'libCategory', c.code));
      const snaps = await ctx.tx.getAll(...keys);
      let categories = 0;
      DEFAULT_CATEGORIES.forEach((c, n) => {
        if (snaps[n].exists) return;
        const ref = ctx.newDoc('libCategories');
        ctx.set(keys[n], { kind: 'libCategory', value: c.code.toLowerCase(), ref: ref.path });
        ctx.set(ref, {
          code: c.code, name: c.name, description: null, parentId: null,
          status: 'active', createdAt: now, createdBy: ctx.uid, updatedAt: now,
        });
        categories++;
      });
      ctx.audit({ action: 'lib.seedDefaults', ref: `schools/${ctx.sid}`, after: { categories } });
      return { categories };
    },
  }),
};
