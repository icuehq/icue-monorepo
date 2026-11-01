import '../region';
import { Pipelines } from '@google-cloud/firestore';
import { DocumentData, Firestore, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { applyChange, matchesAll, searchDb, words } from '../inventory/search';
import type { QueryDef } from '../shared/callable';
import { cleanIsbn, isIsbn10, isIsbn13, toIsbn13 } from './isbn';

/** Catalogue search (FRS 11.4): same mirror pattern as inventory items (architecture §10). */
const COLL = 'libCatalogue';
const ROW = ['title', 'subtitle', 'authors', 'publisher', 'isbn10', 'isbn13', 'year', 'language', 'categoryId', 'status'] as const;
/** Fields the text index covers (see `firebase/scripts/create-search-index.sh`). */
const TEXT = ['title', 'subtitle', 'authorsText', 'publisher', 'keywordsText'];

const row = (d: DocumentData) => Object.fromEntries(ROW.map((f) => [f, d[f] ?? null]));

/** The list-row fields plus flat text copies of the array fields, which the text index needs. */
export const projectCatalogue = (d: DocumentData) => ({
  ...row(d),
  authorsText: (d.authors ?? []).join(' '),
  keywordsText: (d.keywords ?? []).join(' '),
});

export const applyCatalogueChange = (sid: string, id: string, after: DocumentData | undefined, at?: Timestamp, db?: Firestore) =>
  applyChange(COLL, projectCatalogue, sid, id, after, at, db);

export const syncCatalogueSearch = onDocumentWritten(`schools/{sid}/${COLL}/{id}`, (e) =>
  applyCatalogueChange(e.params.sid, e.params.id, e.data?.after.data(), e.data?.after.updateTime),
);

const input = z.object({
  q: z.string().max(100),
  categoryId: z.string().min(1).max(100).optional(),
  offset: z.number().int().min(0).max(5000).default(0),
  limit: z.number().int().min(1).max(50).default(25),
});

/** ISBN-13 of [q] when the whole query is a valid ISBN (hyphens allowed). */
const isbnOf = (q: string) => {
  const s = cleanIsbn(q);
  return isIsbn13(s) ? s : isIsbn10(s) ? toIsbn13(s) : null;
};

export async function searchCatalogue(sid: string, i: z.infer<typeof input>, db: Firestore = searchDb()) {
  const path = `schools/${sid}/${COLL}`;
  const isbn = isbnOf(i.q);
  let rows: Array<{ id: string; data: DocumentData }>;
  if (isbn) {
    // Exact lookups are plain queries on the source of truth, not text search.
    const snap = await getFirestore().collection(path).where('dupKey', '==', `isbn:${isbn}`).get();
    rows = snap.docs
      .filter((d) => !i.categoryId || d.data().categoryId === i.categoryId)
      .slice(i.offset, i.offset + i.limit + 1)
      .map((d) => ({ id: d.id, data: d.data() }));
  } else {
    // Punctuation is dropped so users cannot inject search-DSL operators (quotes, -, *, OR).
    const terms = words(i.q);
    if (!terms.length) throw new HttpsError('invalid-argument', 'Enter a word or an ISBN to search for');
    if (process.env.FIRESTORE_EMULATOR_HOST) {
      // ponytail: the emulator has no text search; whole-word scan of one school's mirror instead.
      const all = (await db.collection(path).get()).docs
        .filter((d) => matchesAll(terms, d.data(), TEXT) && (!i.categoryId || d.data().categoryId === i.categoryId))
        .sort((a, b) => String(a.data().title).localeCompare(String(b.data().title)));
      rows = all.slice(i.offset, i.offset + i.limit + 1).map((d) => ({ id: d.id, data: d.data() }));
    } else {
      const { documentMatches, field } = Pipelines;
      let p = db.pipeline().collection(path).search({ query: documentMatches(terms.join(' ')) });
      if (i.categoryId) p = p.where(field('categoryId').equal(i.categoryId));
      const res = await p.sort(field('title').ascending()).offset(i.offset).limit(i.limit + 1).execute();
      rows = res.results.map((r) => ({ id: r.id!, data: r.data() }));
    }
  }
  return {
    items: rows.slice(0, i.limit).map((r) => ({ id: r.id, ...row(r.data) })),
    hasMore: rows.length > i.limit,
  };
}

export const catalogueSearch: QueryDef<typeof input, Awaited<ReturnType<typeof searchCatalogue>>> = {
  perm: 'lib.catalogue.view',
  input,
  handler: searchCatalogue,
};
