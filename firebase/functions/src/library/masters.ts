import { z } from 'zod';
import { serverTimestamp } from '../shared/firestore';
import { defineCallable } from '../shared/masters';
import { DEFAULT_CATEGORIES } from './defaults';

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
  /** Adds the default categories and subcategories that do not exist yet (matched by name within the parent). Safe to repeat. */
  seedDefaults: defineCallable({
    name: 'library.seedDefaults',
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
