import { z } from 'zod';
import { serverTimestamp } from '../shared/firestore';
import { claimUniqueKey, uniqueKeyRef } from '../shared/keys';
import { defineCallable, defineSetStatus, id, missing, usable } from '../shared/masters';
import { DEFAULT_CATEGORIES } from './defaults';

const text = (max: number) => z.string().trim().min(1).max(max);
const norm = (value: string | null | undefined) =>
  (value ?? '')
    .toLowerCase()
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean)
    .join(' ');

/** Identity of a title: its bibliographic details. */
export function identityKey(title: {
  title: string;
  authors: string[];
  edition?: string | null;
  publisher?: string | null;
  year?: number | null;
}) {
  return `bib:${[title.title, title.authors[0], title.edition, title.publisher].map(norm).join('|')}|${title.year ?? ''}`;
}

export const masters = {
  catalogueUpsert: defineCallable({
    name: 'library.catalogue.upsert',
    permission: 'library.catalogue',
    input: z.object({
      id: id.optional(),
      title: text(200),
      subtitle: text(200).nullish(),
      authors: z.array(text(100)).min(1).max(10),
      publisher: text(120).nullish(),
      edition: text(50).nullish(),
      year: z.number().int().min(1000).max(2200).nullish(),
      language: text(50).nullish(),
      categoryId: id,
      classIds: z.array(z.number().int().positive()).max(15).default([]),
      description: z.string().trim().max(2000).nullish(),
      pages: z.number().int().min(1).max(100000).nullish(),
      shelf: text(50).nullish(),
      keywords: z.array(text(50)).max(20).default([]),
    }),
    handler: async (context, i) => {
      const key = identityKey(i);

      const now = serverTimestamp();
      const before = i.id
        ? (await context.transaction.get(context.doc(`libraryCatalogue/${i.id}`))).data()
        : undefined;
      if (i.id && !before) throw missing('libraryCatalogue');
      const ref = i.id
        ? context.doc(`libraryCatalogue/${i.id}`)
        : context.newDoc('libraryCatalogue');
      usable(
        await context.transaction.get(context.doc(`libraryCategories/${i.categoryId}`)),
        'Category',
        before?.categoryId === i.categoryId,
      );
      if (!before || before.identityKey !== key) {
        await claimUniqueKey(context, 'libraryTitle', key, ref.path);
        if (before) context.delete(uniqueKeyRef(context, 'libraryTitle', before.identityKey));
      }

      const after = {
        title: i.title,
        subtitle: i.subtitle ?? null,
        authors: i.authors,
        publisher: i.publisher ?? null,
        edition: i.edition ?? null,
        year: i.year ?? null,
        language: i.language ?? null,
        categoryId: i.categoryId,
        classIds: [...new Set(i.classIds)].sort((first, second) => first - second),
        description: i.description ?? null,
        pages: i.pages ?? null,
        shelf: i.shelf ?? null,
        keywords: i.keywords,
        identityKey: key,
      };
      if (before) {
        context.update(ref, { ...after, updatedAt: now });
        context.audit({ action: 'libraryCatalogue.update', documentPath: ref.path, before, after });
      } else {
        // Known limit: `coverPath` stays null until the upload path (`files-getUploadPath`) exists.
        context.set(ref, {
          ...after,
          coverPath: null,
          status: 'active',
          createdAt: now,
          createdBy: context.uid,
          updatedAt: now,
        });
        context.audit({ action: 'libraryCatalogue.create', documentPath: ref.path, after });
      }
      return { id: ref.id };
    },
  }),
  catalogueSetStatus: defineSetStatus(
    'library.catalogue.setStatus',
    'library.catalogue',
    'libraryCatalogue',
    'libraryCatalogue',
  ),

  /** Adds the default categories and subcategories that do not exist yet (matched by name within the parent). Safe to repeat. */
  seedDefaults: defineCallable({
    name: 'library.seedDefaults',
    permission: 'library.catalogue',
    input: z.object({}),
    handler: async (context) => {
      const now = serverTimestamp();
      const key = (parentId: string | null, name: string) =>
        `${parentId ?? ''}|${name.trim().toLowerCase()}`;
      const existing = new Map(
        (await context.transaction.get(context.coll('libraryCategories'))).docs.map((category) => [
          key(category.data().parentId ?? null, String(category.data().name)),
          category.id,
        ]),
      );
      let categories = 0;
      const ensure = (parentId: string | null, name: string) => {
        const found = existing.get(key(parentId, name));
        if (found) return found;
        const ref = context.newDoc('libraryCategories');
        context.set(ref, {
          name,
          description: null,
          parentId,
          status: 'active',
          createdAt: now,
          createdBy: context.uid,
          updatedAt: now,
        });
        categories++;
        return ref.id;
      };
      for (const category of DEFAULT_CATEGORIES) {
        const parentId = ensure(null, category.name);
        for (const child of category.children) ensure(parentId, child);
      }
      context.audit({
        action: 'library.seedDefaults',
        documentPath: `schools/${context.schoolId}`,
        after: { categories },
      });
      return { categories };
    },
  }),
};
