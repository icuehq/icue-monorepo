import type { DocumentData, DocumentReference } from 'firebase-admin/firestore';
import type { CallableContext } from '../shared/callable';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber } from '../shared/keys';

/** Where a fine or incident happened: the copy's title, library and campus (a loan or copy document has all four). */
export const copyFields = (source: DocumentData) => ({
  catalogueId: source.catalogueId,
  libraryId: source.libraryId,
  campusId: source.campusId,
});

/** Block fields for a fine; a hand-set block keeps its own origin so paying fines never lifts it. */
export const fineBlock = (member: DocumentData) => ({
  blocked: true,
  blockedBy: member.blocked && member.blockedBy === 'manual' ? 'manual' : 'fine',
});

/** Queues an outstanding fine against a member. Callers block the member and notify. */
export async function raiseFine(
  context: CallableContext,
  fine: {
    id: string;
    type: string;
    amount: number;
    member: DocumentData;
    source: DocumentData;
    barcode: string;
    calculation: Record<string, unknown>;
    loanId?: string | null;
    incidentId?: string;
  },
): Promise<DocumentReference> {
  const ref = context.doc(`libraryFines/${fine.id}`);
  context.set(ref, {
    fineNumber: await nextNumber(context, 'FIN'),
    ...(fine.incidentId ? { incidentId: fine.incidentId } : {}),
    loanId: fine.loanId ?? null,
    memberType: fine.member.memberType,
    personErpId: fine.member.personErpId,
    memberName: fine.member.name ?? null,
    barcode: fine.barcode,
    ...copyFields(fine.source),
    type: fine.type,
    amount: fine.amount,
    waived: 0,
    paid: 0,
    outstanding: fine.amount,
    status: 'outstanding',
    fineCalculation: fine.calculation,
    waivers: [],
    payments: [],
    createdAt: serverTimestamp(),
    createdBy: context.uid,
    updatedAt: serverTimestamp(),
  });
  return ref;
}
