import { getFirestore } from 'firebase-admin/firestore';

/** Runs a scheduled [job] once for every school. */
export async function forEachSchool(job: (schoolId: string) => Promise<void>): Promise<void> {
  for (const school of await getFirestore().collection('schools').listDocuments())
    await job(school.id);
}
