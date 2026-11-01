import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { todayIST } from '../inventory/stock';
import type { Ctx } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { def, failed, id, missing, note } from '../shared/masters';
import { release } from './reservations';

const UP = () => FieldValue.serverTimestamp();
const KINDS = ['lost', 'damaged'] as const;
const SEVERITIES = ['minor', 'moderate', 'severe'] as const;
const RESOLUTIONS = ['repaired', 'replaced', 'written_off', 'charged', 'dismissed'] as const;

async function loadIncident(ctx: Ctx, incidentId: string) {
  const ref = ctx.doc(`libIncidents/${incidentId}`);
  const snap = await ctx.tx.get(ref);
  if (!snap.exists) throw missing('libIncident');
  const d = snap.data()!;
  ctx.requireCampus(d.campusId);
  return { ref, d };
}

export const incidents = {
  /**
   * Reports a lost or damaged book copy (FRS 11.14).
   * Updates the physical copy status; if a member is held responsible and charge > 0,
   * creates a fine and blocks the member.
   */
  incidentReport: def({
    name: 'lib.incident.report',
    perm: 'lib.circulation.operate',
    input: z.object({
      copyId: id,
      memberId: id.nullish(),
      kind: z.enum(KINDS),
      severity: z.enum(SEVERITIES).default('moderate'),
      description: note,
      charge: z.number().min(0).max(10_000_000).default(0),
    }),
    handler: async (ctx, i) => {
      const cRef = ctx.doc(`libCopies/${i.copyId}`);
      const cSnap = await ctx.tx.get(cRef);
      if (!cSnap.exists) throw missing('libCopy');
      const copy = cSnap.data()!;
      ctx.requireCampus(copy.campusId);
      if (copy.status === 'lost' || copy.status === 'withdrawn') {
        throw failed(`Copy is already ${copy.status}`);
      }
      if (copy.activeLoanId || copy.heldReservationId) {
        throw failed('Copy is on loan or held; use Mark lost / return as damaged, or release the hold first');
      }
      const open = await ctx.tx.get(ctx.coll('libIncidents').where('copyId', '==', i.copyId).where('status', '==', 'open').limit(1));
      if (!open.empty) throw failed('Copy already has an open incident');

      let member: Record<string, unknown> | null = null;
      let mRef = null;
      if (i.memberId) {
        mRef = ctx.doc(`libMembers/${i.memberId}`);
        const mSnap = await ctx.tx.get(mRef);
        if (!mSnap.exists) throw missing('libMember');
        member = mSnap.data()!;
      }

      const incRef = ctx.newDoc('libIncidents');
      const incidentNumber = await nextNumber(ctx, 'INC');
      const today = todayIST();

      const after = {
        incidentNumber,
        kind: i.kind,
        copyId: cRef.id,
        accessionNo: copy.accessionNo,
        catalogueId: copy.catalogueId,
        libraryId: copy.libraryId,
        campusId: copy.campusId,
        memberId: member ? i.memberId : null,
        memberType: member ? member.memberType : null,
        personErpId: member ? member.erpId : null,
        severity: i.kind === 'damaged' ? i.severity : null,
        description: i.description ?? null,
        photos: [],
        charge: i.charge,
        repairStatus: i.kind === 'damaged' ? 'none' : null,
        status: 'open',
        resolution: null,
        resolvedAt: null,
        reportedDate: today,
        reportedBy: ctx.uid,
      };

      ctx.set(incRef, { ...after, createdAt: UP(), createdBy: ctx.uid, updatedAt: UP() });

      // Update copy status: lost or damaged copies are taken off circulation
      const newCopyStatus = i.kind === 'lost' ? 'lost' : 'damaged';
      ctx.update(cRef, { status: newCopyStatus, activeLoanId: null, heldReservationId: null, updatedAt: UP() });

      // If a member is responsible and charge > 0, raise a fine and block the member
      if (member && mRef && i.charge > 0) {
        const fineNumber = await nextNumber(ctx, 'FIN');
        const fRef = ctx.doc(`libFines/inc_${incRef.id}__${i.kind}`);
        ctx.set(fRef, {
          fineNumber,
          incidentId: incRef.id,
          loanId: null,
          memberId: i.memberId,
          memberType: member.memberType,
          personErpId: member.erpId,
          catalogueId: copy.catalogueId,
          accessionNo: copy.accessionNo,
          libraryId: copy.libraryId,
          campusId: copy.campusId,
          type: i.kind,
          amount: i.charge,
          waived: 0,
          paid: 0,
          outstanding: i.charge,
          status: 'outstanding',
          calc: { incidentNumber, kind: i.kind, severity: i.severity, charge: i.charge },
          waivals: [],
          payments: [],
          createdAt: UP(),
          createdBy: ctx.uid,
          updatedAt: UP(),
        });
        ctx.update(mRef, { blocked: true, updatedAt: UP() });
      }

      ctx.audit({ action: 'libIncident.report', ref: incRef.path, after });
      return { id: incRef.id, number: incidentNumber };
    },
  }),

  /**
   * Resolves a lost or damaged book incident (FRS 11.14).
   * Repaired copies are returned to shelf or reservation queue; written-off copies are withdrawn.
   */
  resolve: def({
    name: 'lib.incident.resolve',
    perm: 'lib.circulation.operate',
    input: z.object({
      id,
      resolution: z.enum(RESOLUTIONS),
      repairCost: z.number().min(0).max(10_000_000).nullish(),
      charge: z.number().min(0).max(10_000_000).nullish(),
      remarks: note,
    }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadIncident(ctx, i.id);
      if (d.status !== 'open') throw failed(`Incident is already ${d.status}`);

      const cRef = ctx.doc(`libCopies/${d.copyId}`);
      const cSnap = await ctx.tx.get(cRef);
      if (!cSnap.exists) throw missing('libCopy');
      const copy = cSnap.data()!;

      if (i.resolution === 'repaired' && d.kind !== 'damaged') throw failed('Only a damaged copy can be repaired');
      const charge = i.charge ?? d.charge ?? 0;
      if (charge < (d.charge ?? 0)) throw failed('Charge cannot be lowered on resolve; waive the fine instead');

      let repairStatus = d.repairStatus;
      if (i.resolution === 'repaired' || i.resolution === 'dismissed') {
        // dismissed = no fault found (or the lost book turned up): back to shelf unless already withdrawn
        if (i.resolution === 'repaired') repairStatus = 'repaired';
        if (copy.status === 'damaged' || copy.status === 'lost') await release(ctx, cRef, copy);
      } else if (i.resolution === 'written_off') {
        repairStatus = 'writeoff';
        ctx.update(cRef, { status: 'withdrawn', updatedAt: UP() });
      }

      // If additional charge is levied and member is on incident and not already charged
      if (charge > (d.charge ?? 0) && d.memberId) {
        const diff = charge - (d.charge ?? 0);
        const mRef = ctx.doc(`libMembers/${d.memberId}`);
        const mSnap = await ctx.tx.get(mRef);
        if (mSnap.exists) {
          const fineNumber = await nextNumber(ctx, 'FIN');
          const fRef = ctx.doc(`libFines/inc_${ref.id}__penalty`);
          ctx.set(fRef, {
            fineNumber,
            incidentId: ref.id,
            loanId: d.loanId ?? null,
            memberId: d.memberId,
            memberType: d.memberType,
            personErpId: d.personErpId,
            catalogueId: d.catalogueId,
            accessionNo: d.accessionNo,
            libraryId: d.libraryId,
            campusId: d.campusId,
            type: d.kind,
            amount: diff,
            waived: 0,
            paid: 0,
            outstanding: diff,
            status: 'outstanding',
            calc: { incidentNumber: d.incidentNumber, resolution: i.resolution, charge: diff },
            waivals: [],
            payments: [],
            createdAt: UP(),
            createdBy: ctx.uid,
            updatedAt: UP(),
          });
          ctx.update(mRef, { blocked: true, updatedAt: UP() });
        }
      }

      const updateData = {
        status: 'resolved',
        resolution: i.resolution,
        resolutionRemarks: i.remarks ?? null,
        repairCost: i.repairCost ?? null,
        charge,
        repairStatus: repairStatus ?? null,
        resolvedBy: ctx.uid,
        resolvedAt: UP(),
        updatedAt: UP(),
      };
      ctx.update(ref, updateData);
      ctx.audit({ action: 'libIncident.resolve', ref: ref.path, before: { status: 'open' }, after: updateData });
      return { id: ref.id };
    },
  }),
};
