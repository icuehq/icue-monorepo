import '../region';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { getMessaging, type BatchResponse, type TokenMessage } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions/v2';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import type { CallableContext } from './callable';
import { serverTimestamp } from './firestore';

export type Recipients = {
  uids?: string[];
  permission?: string;
  campusId?: number; // with `permission`: only users who can access this campus
  personErpIds?: number[];
  wardStudentIds?: number[];
};

export type OutboxEvent = {
  to: Recipients;
  category: string; // mute key, e.g. `inventory.lowStock`
  title: string;
  body: string;
  data?: Record<string, string>;
};

/**
 * Queues `outbox/{key}` in the caller's transaction. An existing key is skipped
 * (not `create`d), so a repeated event never aborts the business transaction.
 */
export async function enqueue(context: CallableContext, key: string, event: OutboxEvent): Promise<void> {
  const ref = context.doc(`outbox/${key}`);
  if ((await context.transaction.get(ref)).exists) return;
  context.set(ref, { ...event, status: 'pending', createdAt: serverTimestamp() });
}

/** Outbox post outside a business transaction (scheduled jobs): an existing key is left alone. */
export async function post(db: Firestore, schoolId: string, key: string, outboxEvent: OutboxEvent): Promise<void> {
  try {
    await db.doc(`schools/${schoolId}/outbox/${key}`).create({ ...outboxEvent, status: 'pending', createdAt: serverTimestamp() });
  } catch (err) {
    if ((err as { code?: number }).code !== 6) throw err; // 6 = ALREADY_EXISTS
  }
}

const IN_LIMIT = 30;
const chunks = <T>(items: T[], size: number) => Array.from({ length: Math.ceil(items.length / size) }, (_, i) => items.slice(i * size, i * size + size));

export async function resolveRecipients(db: Firestore, schoolId: string, recipients: Recipients): Promise<string[]> {
  const access = db.collection(`schools/${schoolId}/userAccess`);
  const uids = new Set(recipients.uids ?? []);
  if (recipients.permission) {
    const holders = await access.where('permissions', 'array-contains', recipients.permission).get();
    for (const holder of holders.docs) {
      const userAccess = holder.data();
      if (recipients.campusId == null || userAccess.hasAllCampuses === true || (userAccess.campusIds as number[] | undefined)?.includes(recipients.campusId)) uids.add(holder.id);
    }
  }
  for (const part of chunks(recipients.personErpIds ?? [], IN_LIMIT)) {
    for (const snapshot of (await access.where('personErpId', 'in', part).get()).docs) uids.add(snapshot.id);
  }
  for (const part of chunks(recipients.wardStudentIds ?? [], IN_LIMIT)) {
    for (const snapshot of (await access.where('wardStudentIds', 'array-contains-any', part).get()).docs) uids.add(snapshot.id);
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
const sendFcm = async (messages: TokenMessage[]): Promise<BatchResponse> => {
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    // The emulator runs as the real dev project with real credentials; never push from it.
    logger.info('emulator: skipping FCM send', { count: messages.length });
    return { responses: messages.map(() => ({ success: true })), successCount: messages.length, failureCount: 0 } as BatchResponse;
  }
  return getMessaging().sendEach(messages);
};

export async function deliver(
  db: Firestore,
  schoolId: string,
  key: string,
  send: (tokenMessages: TokenMessage[]) => Promise<BatchResponse> = sendFcm,
): Promise<void> {
  const outboxRef = db.doc(`schools/${schoolId}/outbox/${key}`);
  const outboxEvent = (await outboxRef.get()).data() as (OutboxEvent & { status: string; createdAt?: FirebaseFirestore.Timestamp }) | undefined;
  if (!outboxEvent || outboxEvent.status !== 'pending') return;
  if (outboxEvent.createdAt && Date.now() - outboxEvent.createdAt.toMillis() > MAX_AGE_MS) {
    await outboxRef.update({ status: 'expired' });
    return;
  }

  const messages: TokenMessage[] = [];
  const tokenRefs: FirebaseFirestore.DocumentReference[] = [];
  const recipients = await resolveRecipients(db, schoolId, outboxEvent.to);
  for (const uid of recipients) {
    try {
      await db.doc(`schools/${schoolId}/notifications/${key}__${uid}`).create({
        uid,
        category: outboxEvent.category,
        title: outboxEvent.title,
        body: outboxEvent.body,
        data: outboxEvent.data ?? {},
        read: false,
        createdAt: serverTimestamp(),
      });
    } catch (error) {
      if ((error as { code?: number }).code === 6) continue; // ALREADY_EXISTS: handled by an earlier attempt
      throw error;
    }
    const device = await db.doc(`devices/${uid}`).get();
    if (device.data()?.mute?.[outboxEvent.category] === true) continue; // not get('mute.x'): categories contain dots
    for (const snapshot of (await db.collection(`devices/${uid}/tokens`).get()).docs) {
      messages.push({ token: snapshot.get('token') as string, notification: { title: outboxEvent.title, body: outboxEvent.body }, data: outboxEvent.data });
      tokenRefs.push(snapshot.ref);
    }
  }

  let sent = 0;
  for (let i = 0; i < messages.length; i += 500) {
    const response = await send(messages.slice(i, i + 500));
    sent += response.successCount;
    await Promise.all(
      response.responses.map((response, j) => (!response.success && DEAD_TOKEN.has(response.error?.code ?? '') ? tokenRefs[i + j].delete() : null)),
    );
  }
  await outboxRef.update({ status: 'sent', sentAt: serverTimestamp(), recipients: recipients.length, sent });
}

export const outboxSend = onDocumentCreated({ document: 'schools/{schoolId}/outbox/{key}', retry: true }, async (event) => {
  await deliver(getFirestore(), event.params.schoolId, event.params.key);
  logger.info('outbox delivered', { schoolId: event.params.schoolId, key: event.params.key });
});
