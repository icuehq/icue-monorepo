import type { Recipients } from '../shared/outbox';

/** The member as a notification recipient: a student's parents (wardStudentIds) or the employee (ERP ID). */
export const memberTo = (memberType: string, personErpId: number): Recipients =>
  memberType === 'STUDENT' ? { wardStudentIds: [personErpId] } : { personErpIds: [personErpId] };
