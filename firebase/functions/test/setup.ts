import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

export const PROJECT = 'demo-icue';

if (!getApps().length) initializeApp({ projectId: PROJECT });

/** Wipes the Firestore emulator (default and `search` databases). */
export async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) throw new Error('Run through `npm test` (Firestore emulator)');
  for (const database of ['(default)', 'search']) {
    await fetch(`http://${host}/emulator/v1/projects/${PROJECT}/databases/${database}/documents`, {
      method: 'DELETE',
    });
  }
}

export const db = () => getFirestore();
