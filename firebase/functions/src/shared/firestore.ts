import { FieldValue, getFirestore } from 'firebase-admin/firestore';

/** Server-side time, written as the `…At` fields. */
export const serverTimestamp = () => FieldValue.serverTimestamp();

/** A collection of the school the caller belongs to, read outside the transaction. */
export const schoolCollection = (schoolId: string, name: string) =>
  getFirestore().collection(`schools/${schoolId}/${name}`);
