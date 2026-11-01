import type { Recipients } from '../shared/outbox';

/** The member as a notification recipient: a student's parents (wards) or the teacher (ERP ID). */
export const memberTo = (memberType: string, erpId: number): Recipients =>
  memberType === 'student' ? { wards: [erpId] } : { eids: [erpId] };

/** Same, plus the librarians who can act on it (FRS 11.17 lost/damaged). */
export const memberAndLibrarians = (memberType: string, erpId: number | null, campusId: number): Recipients => ({
  ...(erpId == null ? {} : memberTo(memberType, erpId)),
  perm: 'lib.circulation.operate',
  campusId,
});
