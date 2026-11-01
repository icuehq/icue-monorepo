import type { Recipients } from '../shared/outbox';

/** The member as a notification recipient: a student's parents (wardStudentIds) or the teacher (ERP ID). */
export const memberTo = (memberType: string, personErpId: number): Recipients =>
  memberType === 'student' ? { wardStudentIds: [personErpId] } : { personErpIds: [personErpId] };

/** Same, plus the librarians who can act on it (FRS 11.17 lost/damaged). */
export const memberAndLibrarians = (memberType: string, personErpId: number | null, campusId: number): Recipients => ({
  ...(personErpId == null ? {} : memberTo(memberType, personErpId)),
  permission: 'library.circulation.operate',
  campusId,
});
