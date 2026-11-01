import '../region';
import { FieldValue, Firestore, getFirestore } from 'firebase-admin/firestore';
import { getMessaging, type BatchResponse, type TokenMessage } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions/v2';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import type { Ctx } from './callable';

export type Recipients = {
  uids?: string[];
  perm?: string;
  campusId?: number; // with `perm`: only users who can access this campus
  eids?: number[];
  wards?: number[];
};

export type OutboxEvent = {
  to: Recipients;
  category: string; // mute key, e.g. `inv.lowStock`
  title: string;
  body: string;
  data?: Record<string, string>;
};

/**
 * Queues `outbox/{key}` in the caller's transaction. An existing key is skipped
 * (not `create`d), so a repeated event never aborts the business transaction.
 */
export async function enqueue(ctx: Ctx, key: string, event: OutboxEvent): Promise<void> {
  const ref = ctx.doc(`outbox/${key}`);
  if ((await ctx.tx.get(ref)).exists) return;
  ctx.set(ref, { ...event, status: 'pending', createdAt: FieldValue.serverTimestamp() });
}

/** Outbox post outside a business transaction (scheduled jobs): an existing key is left alone. */
export async function post(db: Firestore, sid: string, key: string, e: OutboxEvent): Promise<void> {
  try {
    await db.doc(`schools/${sid}/outbox/${key}`).create({ ...e, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  } catch (err) {
    if ((err as { code?: number }).code !== 6) throw err; // 6 = ALREADY_EXISTS
  }
}

const IN_LIMIT = 30;
const chunks = <T>(a: T[], n: number) => Array.from({ length: Math.ceil(a.length / n) }, (_, i) => a.slice(i * n, i * n + n));

export async function resolveRecipients(db: Firestore, sid: string, to: Recipients): Promise<string[]> {
  const access = db.collection(`schools/${sid}/userAccess`);
  const uids = new Set(to.uids ?? []);
  if (to.perm) {
    const snap = await access.where('perms', 'array-contains', to.perm).get();
    for (const d of snap.docs) {
      const a = d.data();
      if (to.campusId == null || a.all === true || (a.cmp as number[] | undefined)?.includes(to.campusId)) uids.add(d.id);
    }
  }
  for (const part of chunks(to.eids ?? [], IN_LIMIT)) {
    for (const d of (await access.where('eid', 'in', part).get()).docs) uids.add(d.id);
  }
  for (const part of chunks(to.wards ?? [], IN_LIMIT)) {
    for (const d of (await access.where('wards', 'array-contains-any', part).get()).docs) uids.add(d.id);
  }
  return [...uids];
}

const DEAD_TOKEN = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-argument']);
const MAX_AGE_MS = 60 * 60 * 1000;

/**
 * Delivers one outbox event: inbox copy per recipient (`notifications/{key__uid}`,
 * created once, so retries skip recipients already handled), then FCM to their
 * tokens unless muted. Dead tokens are deleted.
 */
const sendFcm = async (m: TokenMessage[]): Promise<BatchResponse> => {
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    // The emulator runs as the real dev project with real credentials; never push from it.
    logger.info('emulator: skipping FCM send', { count: m.length });
    return { responses: m.map(() => ({ success: true })), successCount: m.length, failureCount: 0 } as BatchResponse;
  }
  return getMessaging().sendEach(m);
};

export async function deliver(
  db: Firestore,
  sid: string,
  key: string,
  send: (m: TokenMessage[]) => Promise<BatchResponse> = sendFcm,
): Promise<void> {
  const outboxRef = db.doc(`schools/${sid}/outbox/${key}`);
  const ev = (await outboxRef.get()).data() as (OutboxEvent & { status: string; createdAt?: FirebaseFirestore.Timestamp }) | undefined;
  if (!ev || ev.status !== 'pending') return;
  if (ev.createdAt && Date.now() - ev.createdAt.toMillis() > MAX_AGE_MS) {
    await outboxRef.update({ status: 'expired' });
    return;
  }

  const messages: TokenMessage[] = [];
  const tokenRefs: FirebaseFirestore.DocumentReference[] = [];
  const recipients = await resolveRecipients(db, sid, ev.to);
  for (const uid of recipients) {
    try {
      await db.doc(`schools/${sid}/notifications/${key}__${uid}`).create({
        uid,
        category: ev.category,
        title: ev.title,
        body: ev.body,
        data: ev.data ?? {},
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if ((e as { code?: number }).code === 6) continue; // ALREADY_EXISTS: handled by an earlier attempt
      throw e;
    }
    const device = await db.doc(`devices/${uid}`).get();
    if (device.data()?.mute?.[ev.category] === true) continue; // not get('mute.x'): categories contain dots
    for (const t of (await db.collection(`devices/${uid}/tokens`).get()).docs) {
      messages.push({ token: t.get('token') as string, notification: { title: ev.title, body: ev.body }, data: ev.data });
      tokenRefs.push(t.ref);
    }
  }

  let sent = 0;
  for (let i = 0; i < messages.length; i += 500) {
    const res = await send(messages.slice(i, i + 500));
    sent += res.successCount;
    await Promise.all(
      res.responses.map((r, j) => (!r.success && DEAD_TOKEN.has(r.error?.code ?? '') ? tokenRefs[i + j].delete() : null)),
    );
  }
  await outboxRef.update({ status: 'sent', sentAt: FieldValue.serverTimestamp(), recipients: recipients.length, sent });
}

export const outboxSend = onDocumentCreated({ document: 'schools/{sid}/outbox/{key}', retry: true }, async (event) => {
  await deliver(getFirestore(), event.params.sid, event.params.key);
  logger.info('outbox delivered', { sid: event.params.sid, key: event.params.key });
});
