import type { DocumentData } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { dayTimestamp, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { copyFields, fineBlock, raiseFine } from './fines';
import { memberAndLibrarians } from './notify';
import { release } from './reservations';

const INCIDENT_TYPES = ['lost', 'damaged'] as const;
const SEVERITIES = ['minor', 'moderate', 'severe'] as const;
const RESOLUTIONS = ['repaired', 'replaced', 'written_off', 'charged', 'dismissed'] as const;

/** Queues an open incident for a copy (and the member held responsible, if any) with its notification. */
export async function openIncident(
  context: CallableContext,
  incident: {
    type: (typeof INCIDENT_TYPES)[number];
    copy: DocumentData;
    barcode: string;
    member?: DocumentData | null;
    loanId?: string | null;
    severity: string | null;
    description: string | null;
    charge: number;
    repairStatus: string | null;
    title: string;
    body: string;
  },
) {
  const ref = context.newDoc('libraryIncidents');
  const incidentNumber = await nextNumber(context, 'INC');
  const member = incident.member ?? null;
  const after = {
    incidentNumber,
    type: incident.type,
    barcode: incident.barcode,
    ...copyFields(incident.copy),
    memberType: member ? member.memberType : null,
    personErpId: member ? member.personErpId : null,
    memberName: member ? (member.name ?? null) : null,
    ...(incident.loanId ? { loanId: incident.loanId } : {}),
    severity: incident.severity,
    description: incident.description,
    photos: [],
    charge: incident.charge,
    repairStatus: incident.repairStatus,
    status: 'open',
    resolution: null,
    resolvedAt: null,
    reportedDate: dayTimestamp(todayIST()),
    reportedBy: context.uid,
  };
  context.set(ref, {
    ...after,
    createdAt: serverTimestamp(),
    createdBy: context.uid,
    updatedAt: serverTimestamp(),
  });
  await enqueue(context, `library-incident__${ref.id}`, {
    to: memberAndLibrarians(
      (member?.memberType as string) ?? '',
      (member?.personErpId as number) ?? null,
      incident.copy.campusId,
    ),
    category: 'library.incident',
    title: incident.title,
    body: incident.body,
    data: { incidentId: ref.id },
  });
  return { ref, incidentNumber, after };
}

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
      barcode: id,
      personErpId: z.number().int().min(1).nullish(),
      type: z.enum(INCIDENT_TYPES),
      severity: z.enum(SEVERITIES).default('moderate'),
      description: optionalText,
      charge: z.number().min(0).max(10_000_000).default(0),
    }),
    handler: async (context, i) => {
      const cRef = context.doc(`libraryCopies/${i.barcode}`);
      const cSnap = await context.transaction.get(cRef);
      if (!cSnap.exists) throw missing('libraryCopy');
      const copy = cSnap.data()!;
      context.requireCampus(copy.campusId);
      if (copy.status === 'lost' || copy.status === 'withdrawn') {
        throw failed(`Copy is already ${copy.status}`);
      }
      if (copy.activeLoanId || copy.heldReservationId) {
        throw failed(
          'Copy is on loan or held; use Mark lost / return as damaged, or release the hold first',
        );
      }
      const open = await context.transaction.get(
        context
          .coll('libraryIncidents')
          .where('barcode', '==', i.barcode)
          .where('status', '==', 'open')
          .limit(1),
      );
      if (!open.empty) throw failed('Copy already has an open incident');

      let member: Record<string, unknown> | null = null;
      let mRef = null;
      if (i.personErpId) {
        mRef = context.doc(`libraryMembers/${i.personErpId}`);
        const mSnap = await context.transaction.get(mRef);
        if (!mSnap.exists) throw missing('libraryMember');
        member = mSnap.data()!;
      }

      const {
        ref: incRef,
        incidentNumber,
        after,
      } = await openIncident(context, {
        type: i.type,
        copy,
        barcode: cRef.id,
        member,
        severity: i.type === 'damaged' ? i.severity : null,
        description: i.description ?? null,
        charge: i.charge,
        repairStatus: i.type === 'damaged' ? 'none' : null,
        title: `${i.type === 'lost' ? 'Lost' : 'Damaged'} book recorded`,
        body: `${cRef.id} was reported ${i.type}.`,
      });

      // Lost or damaged copies are taken off circulation.
      context.update(cRef, {
        status: i.type === 'lost' ? 'lost' : 'damaged',
        activeLoanId: null,
        heldReservationId: null,
        updatedAt: serverTimestamp(),
      });

      if (member && mRef && i.charge > 0) {
        await raiseFine(context, {
          id: `inc_${incRef.id}__${i.type}`,
          type: i.type,
          amount: i.charge,
          member,
          source: copy,
          barcode: cRef.id,
          incidentId: incRef.id,
          calculation: { incidentNumber, type: i.type, severity: i.severity, charge: i.charge },
        });
        context.update(mRef, { ...fineBlock(member), updatedAt: serverTimestamp() });
      }

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

      const cRef = context.doc(`libraryCopies/${incident.barcode}`);
      const cSnap = await context.transaction.get(cRef);
      if (!cSnap.exists) throw missing('libraryCopy');
      const copy = cSnap.data()!;

      if (i.resolution === 'repaired' && incident.type !== 'damaged')
        throw failed('Only a damaged copy can be repaired');
      const charge = i.charge ?? incident.charge ?? 0;
      if (charge < (incident.charge ?? 0))
        throw failed('Charge cannot be lowered on resolve; waive the fine instead');

      let repairStatus = incident.repairStatus;
      if (i.resolution === 'repaired' || i.resolution === 'dismissed') {
        // dismissed = no fault found (or the lost book turned up): back to shelf unless already withdrawn
        if (i.resolution === 'repaired') repairStatus = 'repaired';
        if (copy.status === 'damaged' || copy.status === 'lost') await release(context, cRef, copy);
      } else if (i.resolution === 'written_off') {
        repairStatus = 'writeoff';
        context.update(cRef, { status: 'withdrawn', updatedAt: serverTimestamp() });
      } else if (
        (i.resolution === 'replaced' || i.resolution === 'charged') &&
        (i.resolution === 'replaced' || copy.status === 'lost')
      ) {
        // A replaced or paid-for lost copy is gone for good (a replacement comes in as a new acquisition).
        context.update(cRef, { status: 'withdrawn', updatedAt: serverTimestamp() });
      }

      // If additional charge is levied and member is on incident and not already charged
      if (charge > (incident.charge ?? 0) && incident.personErpId) {
        const difference = charge - (incident.charge ?? 0);
        const mRef = context.doc(`libraryMembers/${incident.personErpId}`);
        const mSnap = await context.transaction.get(mRef);
        if (mSnap.exists) {
          await raiseFine(context, {
            id: `inc_${ref.id}__penalty`,
            type: incident.type,
            amount: difference,
            member: mSnap.data()!,
            source: incident,
            barcode: incident.barcode,
            loanId: incident.loanId ?? null,
            incidentId: ref.id,
            calculation: {
              incidentNumber: incident.incidentNumber,
              resolution: i.resolution,
              charge: difference,
            },
          });
          context.update(mRef, { ...fineBlock(mSnap.data()!), updatedAt: serverTimestamp() });
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
      context.audit({
        action: 'libraryIncident.resolve',
        documentPath: ref.path,
        before: { status: 'open' },
        after: update,
      });
      return { id: ref.id };
    },
  }),
};
