import '../region';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { memberAndLibrarians } from './notify';
import { release } from './reservations';
import { todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';

const INCIDENT_TYPES = ['lost', 'damaged'] as const;
const SEVERITIES = ['minor', 'moderate', 'severe'] as const;
const RESOLUTIONS = ['repaired', 'replaced', 'written_off', 'charged', 'dismissed'] as const;

async function loadIncident(context: CallableContext, incidentId: string) {
  const ref = context.doc(`libraryIncidents/${incidentId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryIncident');
  const incident = snapshot.data()!;
  context.requireCampus(incident.campusId);
  return { ref, incident };
}

export const incidents = {
  /**
   * Reports a lost or damaged book copy (FRS 11.14).
   * Updates the physical copy status; if a member is held responsible and charge > 0,
   * creates a fine and blocks the member.
   */
  incidentReport: defineCallable({
    name: 'library.incident.report',
    permission: 'library.circulation.operate',
    input: z.object({
      copyId: id,
      memberId: id.nullish(),
      type: z.enum(INCIDENT_TYPES),
      severity: z.enum(SEVERITIES).default('moderate'),
      description: optionalText,
      charge: z.number().min(0).max(10_000_000).default(0),
    }),
    handler: async (context, i) => {
      const cRef = context.doc(`libraryCopies/${i.copyId}`);
      const cSnap = await context.transaction.get(cRef);
      if (!cSnap.exists) throw missing('libraryCopy');
      const copy = cSnap.data()!;
      context.requireCampus(copy.campusId);
      if (copy.status === 'lost' || copy.status === 'withdrawn') {
        throw failed(`Copy is already ${copy.status}`);
      }
      if (copy.activeLoanId || copy.heldReservationId) {
        throw failed('Copy is on loan or held; use Mark lost / return as damaged, or release the hold first');
      }
      const open = await context.transaction.get(context.coll('libraryIncidents').where('copyId', '==', i.copyId).where('status', '==', 'open').limit(1));
      if (!open.empty) throw failed('Copy already has an open incident');

      let member: Record<string, unknown> | null = null;
      let mRef = null;
      if (i.memberId) {
        mRef = context.doc(`libraryMembers/${i.memberId}`);
        const mSnap = await context.transaction.get(mRef);
        if (!mSnap.exists) throw missing('libraryMember');
        member = mSnap.data()!;
      }

      const incRef = context.newDoc('libraryIncidents');
      const incidentNumber = await nextNumber(context, 'INC');
      const today = todayIST();

      const after = {
        incidentNumber,
        type: i.type,
        copyId: cRef.id,
        accessionNumber: copy.accessionNumber,
        catalogueId: copy.catalogueId,
        libraryId: copy.libraryId,
        campusId: copy.campusId,
        memberId: member ? i.memberId : null,
        memberType: member ? member.memberType : null,
        personErpId: member ? member.personErpId : null,
        severity: i.type === 'damaged' ? i.severity : null,
        description: i.description ?? null,
        photos: [],
        charge: i.charge,
        repairStatus: i.type === 'damaged' ? 'none' : null,
        status: 'open',
        resolution: null,
        resolvedAt: null,
        reportedDate: today,
        reportedBy: context.uid,
      };

      context.set(incRef, { ...after, createdAt: serverTimestamp(), createdBy: context.uid, updatedAt: serverTimestamp() });

      // Update copy status: lost or damaged copies are taken off circulation
      const newCopyStatus = i.type === 'lost' ? 'lost' : 'damaged';
      context.update(cRef, { status: newCopyStatus, activeLoanId: null, heldReservationId: null, updatedAt: serverTimestamp() });

      // If a member is responsible and charge > 0, raise a fine and block the member
      if (member && mRef && i.charge > 0) {
        const fineNumber = await nextNumber(context, 'FIN');
        const fRef = context.doc(`libraryFines/inc_${incRef.id}__${i.type}`);
        context.set(fRef, {
          fineNumber,
          incidentId: incRef.id,
          loanId: null,
          memberId: i.memberId,
          memberType: member.memberType,
          personErpId: member.personErpId,
          catalogueId: copy.catalogueId,
          accessionNumber: copy.accessionNumber,
          libraryId: copy.libraryId,
          campusId: copy.campusId,
          type: i.type,
          amount: i.charge,
          waived: 0,
          paid: 0,
          outstanding: i.charge,
          status: 'outstanding',
          fineCalculation: { incidentNumber, type: i.type, severity: i.severity, charge: i.charge },
          waivers: [],
          payments: [],
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        });
        context.update(mRef, { blocked: true, updatedAt: serverTimestamp() });
      }

      await enqueue(context, `library-incident__${incRef.id}`, {
        to: memberAndLibrarians((member?.memberType as string) ?? '', (member?.personErpId as number) ?? null, copy.campusId),
        category: 'library.incident', title: `${i.type === 'lost' ? 'Lost' : 'Damaged'} book recorded`,
        body: `${copy.accessionNumber} was reported ${i.type}.`, data: { incidentId: incRef.id },
      });
      context.audit({ action: 'libraryIncident.report', documentPath: incRef.path, after });
      return { id: incRef.id, number: incidentNumber };
    },
  }),

  /**
   * Resolves a lost or damaged book incident (FRS 11.14).
   * Repaired copies are returned to shelf or reservation queue; written-off copies are withdrawn.
   */
  resolve: defineCallable({
    name: 'library.incident.resolve',
    permission: 'library.circulation.operate',
    input: z.object({
      id,
      resolution: z.enum(RESOLUTIONS),
      repairCost: z.number().min(0).max(10_000_000).nullish(),
      charge: z.number().min(0).max(10_000_000).nullish(),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      const { ref, incident } = await loadIncident(context, i.id);
      if (incident.status !== 'open') throw failed(`Incident is already ${incident.status}`);

      const cRef = context.doc(`libraryCopies/${incident.copyId}`);
      const cSnap = await context.transaction.get(cRef);
      if (!cSnap.exists) throw missing('libraryCopy');
      const copy = cSnap.data()!;

      if (i.resolution === 'repaired' && incident.type !== 'damaged') throw failed('Only a damaged copy can be repaired');
      const charge = i.charge ?? incident.charge ?? 0;
      if (charge < (incident.charge ?? 0)) throw failed('Charge cannot be lowered on resolve; waive the fine instead');

      let repairStatus = incident.repairStatus;
      if (i.resolution === 'repaired' || i.resolution === 'dismissed') {
        // dismissed = no fault found (or the lost book turned up): back to shelf unless already withdrawn
        if (i.resolution === 'repaired') repairStatus = 'repaired';
        if (copy.status === 'damaged' || copy.status === 'lost') await release(context, cRef, copy);
      } else if (i.resolution === 'written_off') {
        repairStatus = 'writeoff';
        context.update(cRef, { status: 'withdrawn', updatedAt: serverTimestamp() });
      }

      // If additional charge is levied and member is on incident and not already charged
      if (charge > (incident.charge ?? 0) && incident.memberId) {
        const difference = charge - (incident.charge ?? 0);
        const mRef = context.doc(`libraryMembers/${incident.memberId}`);
        const mSnap = await context.transaction.get(mRef);
        if (mSnap.exists) {
          const fineNumber = await nextNumber(context, 'FIN');
          const fRef = context.doc(`libraryFines/inc_${ref.id}__penalty`);
          context.set(fRef, {
            fineNumber,
            incidentId: ref.id,
            loanId: incident.loanId ?? null,
            memberId: incident.memberId,
            memberType: incident.memberType,
            personErpId: incident.personErpId,
            catalogueId: incident.catalogueId,
            accessionNumber: incident.accessionNumber,
            libraryId: incident.libraryId,
            campusId: incident.campusId,
            type: incident.type,
            amount: difference,
            waived: 0,
            paid: 0,
            outstanding: difference,
            status: 'outstanding',
            fineCalculation: { incidentNumber: incident.incidentNumber, resolution: i.resolution, charge: difference },
            waivers: [],
            payments: [],
            createdAt: serverTimestamp(),
            createdBy: context.uid,
            updatedAt: serverTimestamp(),
          });
          context.update(mRef, { blocked: true, updatedAt: serverTimestamp() });
        }
      }

      const update = {
        status: 'resolved',
        resolution: i.resolution,
        resolutionRemarks: i.remarks ?? null,
        repairCost: i.repairCost ?? null,
        charge,
        repairStatus: repairStatus ?? null,
        resolvedBy: context.uid,
        resolvedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };
      context.update(ref, update);
      context.audit({ action: 'libraryIncident.resolve', documentPath: ref.path, before: { status: 'open' }, after: update });
      return { id: ref.id };
    },
  }),
};
