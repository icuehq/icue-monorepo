import '../region';
import { Pipelines } from '@google-cloud/firestore';
import { DocumentData, Firestore, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import type { QueryDef } from '../shared/callable';

/**
 * Item search lives in a second, Enterprise-edition database (`search`) that only
 * Functions touch: `(default)` stays the source of truth, `syncItemSearch` mirrors a
 * small projection into it, `searchItems` queries it (architecture §10).
 */
export const SEARCH_DB = 'search';
export const searchDb = () => getFirestore(SEARCH_DB);

const FIELDS = ['code', 'name', 'categoryId', 'status', 'stockUnit', 'tracking'] as const;

/** The list-row fields mirrored into the search database. */
export const projectItem = (d: DocumentData) => Object.fromEntries(FIELDS.map((f) => [f, d[f] ?? null]));

/** Mirrors one item change; a delivery older than what is stored is ignored. */
export async function applyItemChange(
  sid: string,
  id: string,
  after: DocumentData | undefined,
  at: Timestamp = Timestamp.now(),
  db: Firestore = searchDb(),
): Promise<void> {
  const ref = db.doc(`schools/${sid}/invItems/${id}`);
  if (!after) {
    await ref.delete();
    return;
  }
  await db.runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data()?.srcUpdatedAt as Timestamp | undefined;
    if (cur && cur.toMillis() > at.toMillis()) return;
    tx.set(ref, { ...projectItem(after), srcUpdatedAt: at });
  });
}

export const syncItemSearch = onDocumentWritten('schools/{sid}/invItems/{id}', (e) =>
  applyItemChange(e.params.sid, e.params.id, e.data?.after.data(), e.data?.after.updateTime),
);

const words = (s: string) => s.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean);

/** Emulator stand-in for text search: every query word equals a word of name or code. */
export const matchesAll = (terms: string[], d: DocumentData) => {
  const have = new Set(words(`${d.name ?? ''} ${d.code ?? ''}`));
  return terms.every((t) => have.has(t));
};

const input = z.object({
  q: z.string().max(100),
  categoryId: z.string().min(1).max(100).optional(),
  offset: z.number().int().min(0).max(5000).default(0),
  limit: z.number().int().min(1).max(50).default(25),
});

export async function searchItems(sid: string, i: z.infer<typeof input>, db: Firestore = searchDb()) {
  // Punctuation is dropped so users cannot inject search-DSL operators (quotes, -, *, OR).
  const terms = words(i.q);
  if (!terms.length) throw new HttpsError('invalid-argument', 'Enter a word to search for');
  const path = `schools/${sid}/invItems`;
  let rows: Array<{ id: string; data: DocumentData }>;
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    // ponytail: the emulator has no text search (`document_matches`); whole-word scan of
    // one school's mirror instead. Real search is covered by the dev spike, not by tests.
    const all = (await db.collection(path).get()).docs
      .filter((d) => matchesAll(terms, d.data()) && (!i.categoryId || d.data().categoryId === i.categoryId))
      .sort((a, b) => String(a.data().name).localeCompare(String(b.data().name)));
    rows = all.slice(i.offset, i.offset + i.limit + 1).map((d) => ({ id: d.id, data: d.data() }));
  } else {
    const { documentMatches, field } = Pipelines;
    let p = db.pipeline().collection(path).search({ query: documentMatches(terms.join(' ')) });
    if (i.categoryId) p = p.where(field('categoryId').equal(i.categoryId));
    const res = await p.sort(field('name').ascending()).offset(i.offset).limit(i.limit + 1).execute();
    rows = res.results.map((r) => ({ id: r.id!, data: r.data() }));
  }
  return {
    items: rows.slice(0, i.limit).map((r) => ({ id: r.id, ...projectItem(r.data) })),
    hasMore: rows.length > i.limit,
  };
}

export const itemSearch: QueryDef<typeof input, Awaited<ReturnType<typeof searchItems>>> = {
  perm: 'inv.items.view',
  input,
  handler: searchItems,
};
