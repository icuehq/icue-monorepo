import { getFirestore, DocumentReference, FieldValue, Timestamp, Transaction } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { z } from 'zod';
import type { Permission } from './permissions';

export type Claims = { sid?: unknown; pt?: unknown; [k: string]: unknown };
export type Access = { perms: string[]; cmp: number[]; all: boolean; eid?: number };

/** Per-call context. Read through `tx`; write only through `set`/`update` so all
 * writes run after all reads (Firestore transactions require it). */
export class Ctx {
  private readonly writes: Array<(tx: Transaction) => void> = [];

  constructor(
    readonly tx: Transaction,
    readonly sid: string,
    readonly uid: string,
    readonly access: Access,
  ) {}

  /** `schools/{sid}/<path>` */
  doc(path: string): DocumentReference {
    return getFirestore().doc(`schools/${this.sid}/${path}`);
  }

  /** Auto-ID doc in `schools/{sid}/<collection>`. */
  newDoc(collection: string): DocumentReference {
    return getFirestore().collection(`schools/${this.sid}/${collection}`).doc();
  }

  set(ref: DocumentReference, data: Record<string, unknown>): void {
    this.writes.push((tx) => tx.set(ref, data));
  }

  update(ref: DocumentReference, data: Record<string, unknown>): void {
    this.writes.push((tx) => tx.update(ref, data));
  }

  requireCampus(campusId: number): void {
    if (!this.access.all && !this.access.cmp.includes(campusId)) {
      throw new HttpsError('permission-denied', 'Campus not allowed');
    }
  }

  audit(e: { action: string; ref: string; before?: unknown; after?: unknown; reason?: string }): void {
    this.set(this.newDoc('auditLogs'), {
      actor: this.uid,
      action: e.action,
      ref: e.ref,
      before: e.before ?? null,
      after: e.after ?? null,
      reason: e.reason ?? null,
      at: FieldValue.serverTimestamp(),
    });
  }

  /** @internal */
  flush(): void {
    for (const w of this.writes) w(this.tx);
  }
}

export type CallableDef<S extends z.ZodType, R> = {
  name: string;
  perm: Permission;
  input: S;
  handler: (ctx: Ctx, input: z.infer<S>) => Promise<R>;
};

const REQUEST_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const requestIdSchema = z.string().regex(/^[A-Za-z0-9_-]{8,64}$/);

/**
 * The shared callable pipeline (architecture §5): auth → access → validation →
 * idempotent replay → one transaction (state, audit, outbox, request record).
 */
export async function runCallable<S extends z.ZodType, R>(
  def: CallableDef<S, R>,
  auth: { uid: string; token: Claims } | undefined,
  data: unknown,
): Promise<R> {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  if (auth.token.pt === 'parent') throw new HttpsError('permission-denied', 'Read-only user');
  if (auth.token.sid == null) throw new HttpsError('permission-denied', 'No school');
  const sid = String(auth.token.sid);
  const uid = auth.uid;

  const raw = (data ?? {}) as Record<string, unknown>;
  const requestId = requestIdSchema.safeParse(raw.requestId);
  if (!requestId.success) throw new HttpsError('invalid-argument', 'requestId required');
  const parsed = def.input.safeParse(raw);
  if (!parsed.success) throw new HttpsError('invalid-argument', z.prettifyError(parsed.error));
  const input = parsed.data as z.infer<S>;

  const db = getFirestore();
  return db.runTransaction(async (tx) => {
    const reqRef = db.doc(`schools/${sid}/requests/${requestId.data}`);
    const accessRef = db.doc(`schools/${sid}/userAccess/${uid}`);
    const [reqSnap, accessSnap] = await tx.getAll(reqRef, accessRef);

    if (reqSnap.exists) {
      const prev = reqSnap.data()!;
      if (prev.uid !== uid || prev.fn !== def.name) {
        throw new HttpsError('already-exists', 'requestId already used');
      }
      return prev.result as R;
    }
    if (!accessSnap.exists) throw new HttpsError('failed-precondition', 'Session not synced');
    const access = accessSnap.data() as Access;
    if (!access.perms?.includes(def.perm)) throw new HttpsError('permission-denied', 'Not allowed');

    const ctx = new Ctx(tx, sid, uid, access);
    const campusId = (input as { campusId?: unknown })?.campusId;
    if (typeof campusId === 'number') ctx.requireCampus(campusId);

    const result = await def.handler(ctx, input);
    ctx.set(reqRef, {
      uid,
      fn: def.name,
      result: result ?? null,
      at: FieldValue.serverTimestamp(),
      expireAt: Timestamp.fromMillis(Date.now() + REQUEST_TTL_MS),
    });
    ctx.flush();
    return result;
  });
}

/** Exposes [def] as an `asia-south1` callable (region set globally in index.ts). */
export function callable<S extends z.ZodType, R>(def: CallableDef<S, R>) {
  return onCall((req) =>
    runCallable(def, req.auth ? { uid: req.auth.uid, token: req.auth.token as Claims } : undefined, req.data),
  );
}
