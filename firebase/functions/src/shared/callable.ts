import {
  getFirestore,
  type DocumentReference,
  Timestamp,
  type Transaction,
} from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { serverTimestamp } from './firestore';
import type { Permission } from './permissions';

export interface TokenClaims {
  schoolId?: unknown;
  personType?: unknown;
  [key: string]: unknown;
}
export interface UserAccess {
  permissions: string[];
  campusIds: number[];
  hasAllCampuses: boolean;
  personErpId?: number;
}

/** Per-call context. Read through `tx`; write only through `set`/`update` so all
 * writes run after all reads (Firestore transactions require it). */
export class CallableContext {
  private readonly writes: ((transaction: Transaction) => void)[] = [];

  constructor(
    readonly transaction: Transaction,
    readonly schoolId: string,
    readonly uid: string,
    readonly access: UserAccess,
  ) {}

  /** `schools/{schoolId}/<path>` */
  doc(path: string): DocumentReference {
    return getFirestore().doc(`schools/${this.schoolId}/${path}`);
  }

  /** `schools/{schoolId}/<path>` collection, for queries. */
  coll(path: string) {
    return getFirestore().collection(`schools/${this.schoolId}/${path}`);
  }

  /** Auto-ID doc in `schools/{schoolId}/<collection>`. */
  newDoc(collection: string): DocumentReference {
    return getFirestore().collection(`schools/${this.schoolId}/${collection}`).doc();
  }

  set(ref: DocumentReference, data: Record<string, unknown>): void {
    this.writes.push((transaction) => transaction.set(ref, data));
  }

  update(ref: DocumentReference, data: Record<string, unknown>): void {
    this.writes.push((transaction) => transaction.update(ref, data));
  }

  delete(ref: DocumentReference): void {
    this.writes.push((transaction) => transaction.delete(ref));
  }

  requireCampus(campusId: number): void {
    if (!this.access.hasAllCampuses && !this.access.campusIds.includes(campusId)) {
      throw new HttpsError('permission-denied', 'Campus not allowed');
    }
  }

  audit(entry: {
    action: string;
    documentPath: string;
    before?: unknown;
    after?: unknown;
    reason?: string;
  }): void {
    this.set(this.newDoc('auditLogs'), {
      actor: this.uid,
      action: entry.action,
      documentPath: entry.documentPath,
      before: entry.before ?? null,
      after: entry.after ?? null,
      reason: entry.reason ?? null,
      performedAt: serverTimestamp(),
    });
  }

  /** @internal */
  flush(): void {
    for (const transaction of this.writes) transaction(this.transaction);
  }
}

export interface CallableDef<S extends z.ZodType, R> {
  name: string;
  permission: Permission;
  input: S;
  handler: (context: CallableContext, input: z.infer<S>) => Promise<R>;
}

const REQUEST_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const requestIdSchema = z.string().regex(/^[A-Za-z0-9_-]{8,64}$/);

/**
 * The shared callable pipeline (architecture §5): auth → access → validation →
 * idempotent replay → one transaction (state, audit, outbox, request record).
 */
export async function runCallable<S extends z.ZodType, R>(
  def: CallableDef<S, R>,
  auth: { uid: string; token: TokenClaims } | undefined,
  data: unknown,
): Promise<R> {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  if (auth.token.personType === 'parent')
    throw new HttpsError('permission-denied', 'Read-only user');
  if (auth.token.schoolId == null) throw new HttpsError('permission-denied', 'No school');
  const schoolId = String(auth.token.schoolId);
  const uid = auth.uid;

  const raw = (data ?? {}) as Record<string, unknown>;
  const requestId = requestIdSchema.safeParse(raw.requestId);
  if (!requestId.success) throw new HttpsError('invalid-argument', 'requestId required');
  const parsed = def.input.safeParse(raw);
  if (!parsed.success) throw new HttpsError('invalid-argument', z.prettifyError(parsed.error));
  const input = parsed.data;

  const db = getFirestore();
  return db.runTransaction(async (transaction) => {
    const reqRef = db.doc(`schools/${schoolId}/requests/${requestId.data}`);
    const accessRef = db.doc(`schools/${schoolId}/userAccess/${uid}`);
    const [reqSnap, accessSnap] = await transaction.getAll(reqRef, accessRef);

    if (reqSnap.exists) {
      const previous = reqSnap.data()!;
      if (previous.uid !== uid || previous.fn !== def.name) {
        throw new HttpsError('already-exists', 'requestId already used');
      }
      return previous.result as R;
    }
    if (!accessSnap.exists) throw new HttpsError('failed-precondition', 'Session not synced');
    const access = accessSnap.data() as UserAccess;
    if (!access.permissions?.includes(def.permission))
      throw new HttpsError('permission-denied', 'Not allowed');

    const context = new CallableContext(transaction, schoolId, uid, access);
    const campusId = (input as { campusId?: unknown })?.campusId;
    if (typeof campusId === 'number') context.requireCampus(campusId);

    const result = await def.handler(context, input);
    context.set(reqRef, {
      uid,
      fn: def.name,
      result: result ?? null,
      performedAt: serverTimestamp(),
      expireAt: Timestamp.fromMillis(Date.now() + REQUEST_TTL_MS),
    });
    context.flush();
    return result;
  });
}

/** Exposes [def] as an `asia-south1` callable (region set globally in index.ts). */
export function callable<S extends z.ZodType, R>(def: CallableDef<S, R>) {
  return onCall((request) =>
    runCallable(
      def,
      request.auth ? { uid: request.auth.uid, token: request.auth.token } : undefined,
      request.data,
    ),
  );
}

export interface QueryDef<S extends z.ZodType, R> {
  permission: Permission;
  input: S;
  handler: (schoolId: string, input: z.infer<S>) => Promise<R>;
}

/** Read-only callable pipeline: auth → permission → validation. No transaction, no request record. */
export async function runQuery<S extends z.ZodType, R>(
  def: QueryDef<S, R>,
  auth: { uid: string; token: TokenClaims } | undefined,
  data: unknown,
): Promise<R> {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  if (auth.token.personType === 'parent')
    throw new HttpsError('permission-denied', 'Read-only user');
  if (auth.token.schoolId == null) throw new HttpsError('permission-denied', 'No school');
  const schoolId = String(auth.token.schoolId);
  const access = (
    await getFirestore().doc(`schools/${schoolId}/userAccess/${auth.uid}`).get()
  ).data() as UserAccess | undefined;
  if (!access) throw new HttpsError('failed-precondition', 'Session not synced');
  if (!access.permissions?.includes(def.permission))
    throw new HttpsError('permission-denied', 'Not allowed');
  const parsed = def.input.safeParse(data ?? {});
  if (!parsed.success) throw new HttpsError('invalid-argument', z.prettifyError(parsed.error));
  return def.handler(schoolId, parsed.data);
}

export function queryCallable<S extends z.ZodType, R>(def: QueryDef<S, R>) {
  return onCall((request) =>
    runQuery(
      def,
      request.auth ? { uid: request.auth.uid, token: request.auth.token } : undefined,
      request.data,
    ),
  );
}
