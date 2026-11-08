import { getFirestore, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { addDays, dayTimestamp, todayIST } from '../shared/dates';
import { financialYearOf, uniqueKeyId } from '../shared/keys';
import { identityKey } from './masters';

/**
 * Development-only sample data for the Library (every screen and every state), written straight to
 * Firestore because overdue, late-returned and lost records cannot be made through the normal callables
 * (they always stamp "today"). Refuses to run outside the Functions emulator. Every document has a fixed
 * ID, so running it again overwrites the same records instead of adding more.
 */

type Doc = Record<string, unknown>;
type Id = string;

const MEMBER_BASE = { student: 900_000, teacher: 910_000 };

const LIBRARIES = [
  {
    id: 'mock-main',
    name: 'Main Library',
    location: 'Block A, Ground floor',
    hours: 'Mon–Sat, 8:00 AM – 4:00 PM',
  },
  {
    id: 'mock-junior',
    name: 'Junior Library',
    location: 'Primary wing',
    hours: 'Mon–Fri, 9:00 AM – 3:00 PM',
  },
] as const;

/** Parent → children, names as in `DEFAULT_CATEGORIES` so running the default seed too adds no duplicates. */
const CATEGORIES: Record<string, string[]> = {
  Fiction: ['Short Stories', 'Novels'],
  Science: ['Physics', 'Biology', 'Astronomy & Space'],
  Mathematics: [],
  'Social Studies': ['History', 'Geography'],
  Languages: ['English'],
  Reference: ['Encyclopedias', 'Dictionaries', 'Atlases & Maps'],
  Biographies: ['Autobiographies'],
  'General Knowledge': ['Current Affairs'],
};

interface BookSpec {
  title: string;
  subtitle?: string;
  authors: string[];
  category: [string, string?];
  publisher: string;
  edition: string;
  year: number;
  language: string;
  pages: number;
  keywords: string[];
  description: string;
  classIds?: number[];
  price: number;
  /** Copies per library, in library order (main, junior). */
  copies: [number, number];
}

const BOOKS: BookSpec[] = [
  {
    title: 'Wings of Fire',
    subtitle: 'An Autobiography',
    authors: ['A.P.J. Abdul Kalam', 'Arun Tiwari'],
    category: ['Biographies', 'Autobiographies'],
    publisher: 'Universities Press',
    edition: '1st',
    year: 1999,
    language: 'English',
    pages: 180,
    keywords: ['autobiography', 'scientist', 'india'],
    description: 'The life story of the missile scientist and former President of India.',
    price: 250,
    copies: [3, 0],
  },
  {
    title: 'The Discovery of India',
    authors: ['Jawaharlal Nehru'],
    category: ['Social Studies', 'History'],
    publisher: 'Penguin',
    edition: 'Reprint',
    year: 2004,
    language: 'English',
    pages: 640,
    keywords: ['history', 'india', 'freedom struggle'],
    description: 'A survey of Indian history, culture and philosophy.',
    price: 399,
    copies: [2, 0],
  },
  {
    title: 'A Brief History of Time',
    authors: ['Stephen Hawking'],
    category: ['Science', 'Astronomy & Space'],
    publisher: 'Bantam',
    edition: '10th anniversary',
    year: 1998,
    language: 'English',
    pages: 212,
    keywords: ['cosmology', 'physics', 'universe'],
    description: 'An accessible introduction to cosmology, black holes and the nature of time.',
    classIds: [10],
    price: 350,
    copies: [1, 0],
  },
  {
    title: 'Concepts of Physics',
    subtitle: 'Volume 1',
    authors: ['H.C. Verma'],
    category: ['Science', 'Physics'],
    publisher: 'Bharati Bhawan',
    edition: '2nd',
    year: 2018,
    language: 'English',
    pages: 464,
    keywords: ['physics', 'mechanics', 'textbook'],
    description: 'Mechanics, waves and heat for senior secondary students.',
    classIds: [9, 10],
    price: 300,
    copies: [3, 0],
  },
  {
    title: 'Mathematics for Class 10',
    authors: ['R.D. Sharma'],
    category: ['Mathematics'],
    publisher: 'Dhanpat Rai',
    edition: 'Revised',
    year: 2022,
    language: 'English',
    pages: 720,
    keywords: ['mathematics', 'class 10', 'exercises'],
    description: 'Chapter-wise theory and exercises aligned to the CBSE syllabus.',
    classIds: [10],
    price: 550,
    copies: [2, 0],
  },
  {
    title: 'The Jungle Book',
    authors: ['Rudyard Kipling'],
    category: ['Fiction', 'Short Stories'],
    publisher: 'Macmillan',
    edition: 'Illustrated',
    year: 2015,
    language: 'English',
    pages: 240,
    keywords: ['jungle', 'mowgli', 'classic'],
    description: 'Tales of Mowgli and the animals of the Indian jungle.',
    classIds: [6, 7],
    price: 199,
    copies: [0, 3],
  },
  {
    title: 'Malgudi Days',
    authors: ['R.K. Narayan'],
    category: ['Fiction', 'Short Stories'],
    publisher: 'Indian Thought',
    edition: 'Reprint',
    year: 2006,
    language: 'English',
    pages: 256,
    keywords: ['short stories', 'india', 'malgudi'],
    description: 'Short stories set in the fictional South Indian town of Malgudi.',
    price: 220,
    copies: [2, 1],
  },
  {
    title: 'Godaan',
    authors: ['Munshi Premchand'],
    category: ['Fiction', 'Novels'],
    publisher: 'Hind Pocket Books',
    edition: 'Reprint',
    year: 2012,
    language: 'Hindi',
    pages: 376,
    keywords: ['novel', 'rural india', 'hindi'],
    description: 'A classic Hindi novel about a poor farmer and his family.',
    price: 180,
    copies: [1, 0],
  },
  {
    title: "Oxford Advanced Learner's Dictionary",
    authors: ['Sally Wehmeier'],
    category: ['Reference', 'Dictionaries'],
    publisher: 'Oxford University Press',
    edition: '8th',
    year: 2010,
    language: 'English',
    pages: 1796,
    keywords: ['dictionary', 'english', 'reference'],
    description: 'A dictionary of current English for learners.',
    price: 450,
    copies: [2, 0],
  },
  {
    title: 'Britannica Student Encyclopaedia',
    authors: ['Encyclopaedia Britannica'],
    category: ['Reference', 'Encyclopedias'],
    publisher: 'Britannica India',
    edition: 'Updated',
    year: 2020,
    language: 'English',
    pages: 1200,
    keywords: ['encyclopedia', 'students', 'reference'],
    description: 'A multi-subject reference for school learners.',
    price: 1200,
    copies: [1, 0],
  },
  {
    title: 'Atlas of the World',
    authors: ['National Geographic'],
    category: ['Reference', 'Atlases & Maps'],
    publisher: 'National Geographic',
    edition: '11th',
    year: 2019,
    language: 'English',
    pages: 304,
    keywords: ['atlas', 'maps', 'world'],
    description: 'Political and physical maps of every region of the world.',
    price: 899,
    copies: [1, 0],
  },
  {
    title: 'Wren & Martin High School Grammar',
    authors: ['P.C. Wren', 'H. Martin'],
    category: ['Languages', 'English'],
    publisher: 'S. Chand',
    edition: 'Revised',
    year: 2017,
    language: 'English',
    pages: 536,
    keywords: ['grammar', 'english', 'composition'],
    description: 'English grammar and composition for school students.',
    classIds: [8, 9, 10],
    price: 320,
    copies: [2, 0],
  },
  {
    title: 'Science Textbook for Class 8',
    authors: ['NCERT'],
    category: ['Science', 'Biology'],
    publisher: 'NCERT',
    edition: '1st',
    year: 2021,
    language: 'English',
    pages: 208,
    keywords: ['ncert', 'class 8', 'science'],
    description: 'The prescribed science textbook for Class 8.',
    classIds: [8],
    price: 120,
    copies: [3, 1],
  },
  {
    title: 'Manorama Year Book',
    authors: ['Mammen Mathew'],
    category: ['General Knowledge', 'Current Affairs'],
    publisher: 'Malayala Manorama',
    edition: 'Annual',
    year: 2023,
    language: 'English',
    pages: 800,
    keywords: ['general knowledge', 'facts', 'annual'],
    description: 'A yearly compendium of facts, figures and current affairs.',
    price: 260,
    copies: [0, 2],
  },
  {
    title: 'Sapiens',
    subtitle: 'A Brief History of Humankind',
    authors: ['Yuval Noah Harari'],
    category: ['Social Studies', 'History'],
    publisher: 'Vintage',
    edition: '1st',
    year: 2015,
    language: 'English',
    pages: 443,
    keywords: ['anthropology', 'history', 'humankind'],
    description: 'How Homo sapiens came to dominate the planet.',
    classIds: [10],
    price: 499,
    copies: [2, 0],
  },
];

const STUDENTS: [string, number][] = [
  ['Aarav Sharma', 8],
  ['Ananya Reddy', 8],
  ['Vihaan Patel', 9],
  ['Diya Nair', 9],
  ['Rohan Iyer', 10],
  ['Isha Gupta', 10],
  ['Kabir Singh', 7],
  ['Meera Joshi', 7],
  ['Arjun Menon', 6],
  ['Sara Khan', 6],
  ['Aditya Rao', 10],
  ['Tara Das', 9],
];
const TEACHERS = ['Lakshmi Venkat', 'Suresh Kumar', 'Priya Desai'];

type PolicyKey =
  'mainStudent' | 'mainReference' | 'mainTeacher' | 'juniorStudent' | 'juniorTeacher';
interface PolicySpec {
  library: Id;
  memberType: 'student' | 'teacher';
  name: string;
  maxBooks: number;
  loanDays: number;
  maxRenewals: number;
  fineType: 'none' | 'per_day' | 'flat';
  fineAmount: number;
  graceDays: number;
  maxFine: number | null;
  /** Parent category names; empty covers every other category. */
  categories: string[];
}
const POLICIES: Record<PolicyKey, PolicySpec> = {
  mainStudent: {
    library: 'mock-main',
    memberType: 'student',
    name: 'Student – general',
    maxBooks: 3,
    loanDays: 14,
    maxRenewals: 1,
    fineType: 'per_day',
    fineAmount: 2,
    graceDays: 2,
    maxFine: 100,
    categories: [],
  },
  mainReference: {
    library: 'mock-main',
    memberType: 'student',
    name: 'Student – reference books',
    maxBooks: 1,
    loanDays: 7,
    maxRenewals: 0,
    fineType: 'flat',
    fineAmount: 50,
    graceDays: 0,
    maxFine: 50,
    categories: ['Reference'],
  },
  mainTeacher: {
    library: 'mock-main',
    memberType: 'teacher',
    name: 'Teacher – all books',
    maxBooks: 5,
    loanDays: 30,
    maxRenewals: 2,
    fineType: 'none',
    fineAmount: 0,
    graceDays: 0,
    maxFine: null,
    categories: [],
  },
  juniorStudent: {
    library: 'mock-junior',
    memberType: 'student',
    name: 'Junior student – all books',
    maxBooks: 2,
    loanDays: 7,
    maxRenewals: 1,
    fineType: 'flat',
    fineAmount: 20,
    graceDays: 1,
    maxFine: 20,
    categories: [],
  },
  juniorTeacher: {
    library: 'mock-junior',
    memberType: 'teacher',
    name: 'Teacher – all books',
    maxBooks: 3,
    loanDays: 15,
    maxRenewals: 1,
    fineType: 'none',
    fineAmount: 0,
    graceDays: 0,
    maxFine: null,
    categories: [],
  },
};

const roundMoney = (value: number) => Math.round(value * 100) / 100;

/** Same rule as the loan-return callable. */
function overdueFine(policy: PolicySpec, overdueDays: number): number {
  if (overdueDays <= policy.graceDays) return 0;
  let amount = 0;
  if (policy.fineType === 'per_day') amount = (overdueDays - policy.graceDays) * policy.fineAmount;
  else if (policy.fineType === 'flat') amount = policy.fineAmount;
  if (policy.maxFine && amount > policy.maxFine) amount = policy.maxFine;
  return roundMoney(amount);
}

export interface MockDataResult {
  titles: number;
  copies: number;
  members: number;
  loans: number;
  reservations: number;
  fines: number;
  incidents: number;
}

export async function fillMockData(
  db: Firestore,
  schoolId: string,
  uid: string,
  campusId: number,
): Promise<MockDataResult> {
  const today = todayIST();
  const dayAt = (offset: number) => dayTimestamp(addDays(today, offset));
  /** A moment [days] ago, so queues keep their order. */
  const ago = (days: number) => Timestamp.fromMillis(Date.now() - days * 86_400_000);
  const base = `schools/${schoolId}`;
  const out = new Map<string, Doc>();
  const put = (path: string, data: Doc) => out.set(`${base}/${path}`, data);
  const stamps = (days: number) => ({ createdAt: ago(days), createdBy: uid, updatedAt: ago(days) });

  // ---- numbering continues the school's own counters ----
  const fy = financialYearOf(new Date());
  const counters = new Map<string, number>();
  for (const type of ['ACQ', 'LIS', 'LRT', 'RSV', 'FIN', 'INC']) {
    const snapshot = await db.doc(`${base}/counters/${type}_${fy}`).get();
    counters.set(type, (snapshot.data()?.next as number | undefined) ?? 0);
  }
  const number = (type: string) => {
    const next = counters.get(type)! + 1;
    counters.set(type, next);
    return `${type}/${fy}/${String(next).padStart(6, '0')}`;
  };

  // ---- libraries ----
  for (const library of LIBRARIES) {
    put(`libraries/${library.id}`, {
      name: library.name,
      campusId,
      location: library.location,
      hours: library.hours,
      code: library.id.toUpperCase(),
      status: 'active',
      ...stamps(120),
    });
  }

  // ---- categories (existing ones are reused) ----
  const existing = new Map(
    (await db.collection(`${base}/libraryCategories`).get()).docs.map((snapshot) => [
      `${snapshot.data().parentId ?? ''}|${String(snapshot.data().name).trim().toLowerCase()}`,
      snapshot.id,
    ]),
  );
  const slug = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const ensureCategory = (parentId: Id | null, name: string): Id => {
    const found = existing.get(`${parentId ?? ''}|${name.toLowerCase()}`);
    if (found) return found;
    const categoryId = `mock-cat-${slug(parentId ?? '')}${slug(name)}`;
    put(`libraryCategories/${categoryId}`, {
      name,
      description: null,
      parentId,
      status: 'active',
      ...stamps(120),
    });
    existing.set(`${parentId ?? ''}|${name.toLowerCase()}`, categoryId);
    return categoryId;
  };
  const parentIds = new Map<string, Id>();
  const childIds = new Map<string, Id>();
  for (const [parent, children] of Object.entries(CATEGORIES)) {
    const parentId = ensureCategory(null, parent);
    parentIds.set(parent, parentId);
    for (const child of children) childIds.set(child, ensureCategory(parentId, child));
  }

  // ---- policies ----
  const policyIds = {} as Record<PolicyKey, Id>;
  for (const [key, policy] of Object.entries(POLICIES) as [PolicyKey, PolicySpec][]) {
    const policyId = `mock-policy-${slug(key)}`;
    policyIds[key] = policyId;
    put(`libraryBorrowingPolicies/${policyId}`, {
      name: policy.name,
      libraryId: policy.library,
      campusId,
      memberType: policy.memberType,
      maxBooks: policy.maxBooks,
      loanDays: policy.loanDays,
      maxRenewals: policy.maxRenewals,
      fineType: policy.fineType,
      fineAmount: policy.fineAmount,
      graceDays: policy.graceDays,
      maxFine: policy.maxFine,
      categoryIds: policy.categories.map((name) => parentIds.get(name)!),
      status: 'active',
      ...stamps(100),
    });
  }

  // ---- titles, acquisitions, copies ----
  const copyDocs = new Map<string, Doc>();
  const titleIds: Id[] = [];
  const titleNames: string[] = [];
  const barcode = (book: number, copy: number) => `MB-${String(book).padStart(2, '0')}-${copy}`;
  /** A copy whose current state a scenario changes; one scenario per copy keeps the data consistent. */
  const claimed = new Set<string>();
  const claim = (code: string) => {
    if (claimed.has(code)) throw new Error(`Mock copy ${code} used by two scenarios`);
    claimed.add(code);
    return copyDocs.get(code)!;
  };
  BOOKS.forEach((book, index) => {
    const number1 = index + 1;
    const titleId = `mock-title-${String(number1).padStart(2, '0')}`;
    titleIds.push(titleId);
    titleNames.push(book.title);
    const [parent, child] = book.category;
    const key = identityKey(book);
    put(`libraryCatalogue/${titleId}`, {
      title: book.title,
      subtitle: book.subtitle ?? null,
      authors: book.authors,
      publisher: book.publisher,
      edition: book.edition,
      year: book.year,
      language: book.language,
      categoryId: child ? childIds.get(child)! : parentIds.get(parent)!,
      classIds: book.classIds ?? [],
      description: book.description,
      pages: book.pages,
      shelf: null,
      keywords: book.keywords,
      identityKey: key,
      coverPath: null,
      status: 'active',
      ...stamps(90),
    });
    put(`uniqueKeys/${uniqueKeyId('libraryTitle', key)}`, {
      keyType: 'libraryTitle',
      value: key.toLowerCase(),
      documentPath: `${base}/libraryCatalogue/${titleId}`,
    });
    let copyNumber = 0;
    LIBRARIES.forEach((library, libraryIndex) => {
      const quantity = book.copies[libraryIndex];
      if (!quantity) return;
      const codes = Array.from({ length: quantity }, () => barcode(number1, ++copyNumber));
      const acquisitionId = `mock-acq-${String(number1).padStart(2, '0')}-${libraryIndex + 1}`;
      put(`libraryAcquisitions/${acquisitionId}`, {
        number: number('ACQ'),
        catalogueId: titleId,
        libraryId: library.id,
        campusId,
        quantity,
        date: dayAt(-90),
        price: book.price,
        reference: `INV-${2000 + number1}`,
        remarks: null,
        barcodes: codes,
        createdAt: ago(90),
        createdBy: uid,
      });
      codes.forEach((code, position) => {
        copyDocs.set(code, {
          catalogueId: titleId,
          libraryId: library.id,
          campusId,
          shelf: `${'ABC'[libraryIndex]}-${(index % 6) + 1}`,
          barcode: code,
          acquisitionId,
          acquiredDate: dayAt(-90),
          price: book.price,
          condition: position === 0 ? 'good' : 'fair',
          status: 'available',
          remarks: null,
          activeLoanId: null,
          heldReservationId: null,
          ...stamps(90),
        });
      });
    });
  });

  // ---- members ----
  interface Member {
    type: 'student' | 'teacher';
    id: number;
    name: string;
    classId: number | null;
    doc: Doc;
  }
  const members: Member[] = [
    ...STUDENTS.map(([name, classId], position): Member => ({
      type: 'student',
      id: MEMBER_BASE.student + position + 1,
      name,
      classId,
      doc: {},
    })),
    ...TEACHERS.map((name, position): Member => ({
      type: 'teacher',
      id: MEMBER_BASE.teacher + position + 1,
      name,
      classId: null,
      doc: {},
    })),
  ];
  const student = (position: number) => members[position - 1];
  const teacher = (position: number) => members[STUDENTS.length + position - 1];
  for (const member of members) {
    member.doc = {
      memberType: member.type,
      personErpId: member.id,
      name: member.name,
      classId: member.classId,
      campusIds: [campusId],
      activeLoans: 0,
      blocked: false,
      blockedBy: null,
      blockReason: null,
      ...stamps(80),
    };
  }

  // ---- fines ----
  const fines: Doc[] = [];
  function raiseFine(
    fineId: Id,
    o: {
      type: 'overdue' | 'lost' | 'damaged';
      amount: number;
      member: Member;
      code: string;
      loanId?: Id;
      incidentId?: Id;
      calculation: Doc;
      on: number;
    },
  ) {
    const copy = copyDocs.get(o.code)!;
    const fine: Doc = {
      fineNumber: number('FIN'),
      incidentId: o.incidentId ?? null,
      loanId: o.loanId ?? null,
      memberType: o.member.type,
      personErpId: o.member.id,
      memberName: o.member.name,
      barcode: o.code,
      catalogueId: copy.catalogueId,
      libraryId: copy.libraryId,
      campusId,
      type: o.type,
      amount: o.amount,
      waived: 0,
      paid: 0,
      outstanding: o.amount,
      status: 'outstanding',
      fineCalculation: o.calculation,
      waivers: [],
      payments: [],
      ...stamps(-o.on),
    };
    fines.push(fine);
    put(`libraryFines/${fineId}`, fine);
    return fine;
  }
  const settle = (fine: Doc) => {
    const outstanding = roundMoney(
      (fine.amount as number) - (fine.paid as number) - (fine.waived as number),
    );
    fine.outstanding = outstanding;
    fine.status =
      outstanding > 0
        ? (fine.paid as number) > 0
          ? 'partially_paid'
          : 'outstanding'
        : (fine.paid as number) > 0
          ? 'paid'
          : 'waived';
  };
  const pay = (fine: Doc, amount: number, reference: string, on: number) => {
    fine.paid = roundMoney((fine.paid as number) + amount);
    (fine.payments as Doc[]).push({ amount, reference, date: dayAt(on), performedBy: uid });
    settle(fine);
  };
  const waive = (fine: Doc, amount: number, reason: string, on: number) => {
    fine.waived = roundMoney((fine.waived as number) + amount);
    (fine.waivers as Doc[]).push({ amount, reason, performedBy: uid, performedAt: ago(-on) });
    settle(fine);
  };

  // ---- incidents ----
  const incidents: Doc[] = [];
  function openIncident(
    incidentId: Id,
    o: {
      type: 'lost' | 'damaged';
      code: string;
      member?: Member;
      loanId?: Id;
      severity: string | null;
      description: string;
      charge: number;
      repairStatus: string | null;
      on: number;
    },
  ) {
    const copy = copyDocs.get(o.code)!;
    const incident: Doc = {
      incidentNumber: number('INC'),
      type: o.type,
      barcode: o.code,
      catalogueId: copy.catalogueId,
      libraryId: copy.libraryId,
      campusId,
      memberType: o.member?.type ?? null,
      personErpId: o.member?.id ?? null,
      memberName: o.member?.name ?? null,
      ...(o.loanId ? { loanId: o.loanId } : {}),
      severity: o.severity,
      description: o.description,
      photos: [],
      charge: o.charge,
      repairStatus: o.repairStatus,
      status: 'open',
      resolution: null,
      resolvedAt: null,
      reportedDate: dayAt(o.on),
      reportedBy: uid,
      ...stamps(-o.on),
    };
    incidents.push(incident);
    put(`libraryIncidents/${incidentId}`, incident);
    return incident;
  }
  const resolveIncident = (
    incident: Doc,
    resolution: string,
    remarks: string,
    on: number,
    repairCost: number | null = null,
  ) => {
    Object.assign(incident, {
      status: 'resolved',
      resolution,
      resolutionRemarks: remarks,
      repairCost,
      resolvedBy: uid,
      resolvedAt: ago(-on),
      updatedAt: ago(-on),
    });
  };

  // ---- loans ----
  const loans: Doc[] = [];
  type End =
    | { kind: 'returned'; on: number; condition?: 'good' | 'damaged'; remarks?: string }
    | { kind: 'lost'; on: number; charge: number; remarks: string };
  function addLoan(
    loanKey: string,
    o: {
      member: Member;
      code: string;
      policy: PolicyKey;
      issued: number;
      renewedOn?: number[];
      end?: End;
      /** True when the scenario leaves the copy out (an active loan) or changes its state. */
      holds?: boolean;
    },
  ) {
    const loanId = `mock-loan-${loanKey}`;
    const policy = POLICIES[o.policy];
    const copy = o.holds === false ? copyDocs.get(o.code)! : claim(o.code);
    let due = o.issued + policy.loanDays;
    const renewals = (o.renewedOn ?? []).map((renewedOn) => {
      due += policy.loanDays;
      return { renewedDate: dayAt(renewedOn), newDueDate: dayAt(due), performedBy: uid };
    });
    const loan: Doc = {
      number: number('LIS'),
      memberType: o.member.type,
      personErpId: o.member.id,
      memberName: o.member.name,
      barcode: o.code,
      catalogueId: copy.catalogueId,
      libraryId: copy.libraryId,
      campusId,
      issuedDate: dayAt(o.issued),
      dueDate: dayAt(due),
      remarks: null,
      renewals,
      policySnapshot: {
        policyId: policyIds[o.policy],
        loanDays: policy.loanDays,
        maxRenewals: policy.maxRenewals,
        fineType: policy.fineType,
        fineAmount: policy.fineAmount,
        graceDays: policy.graceDays,
        maxFine: policy.maxFine,
      },
      status: 'active',
      issuedBy: uid,
      ...stamps(-o.issued),
    };
    const end = o.end;
    if (!end) {
      copy.status = 'issued';
      copy.activeLoanId = loanId;
      o.member.doc.activeLoans = (o.member.doc.activeLoans as number) + 1;
    } else if (end.kind === 'returned') {
      const overdueDays = Math.max(0, end.on - due);
      Object.assign(loan, {
        status: 'returned',
        returnNumber: number('LRT'),
        returnedDate: dayAt(end.on),
        condition: end.condition ?? 'good',
        overdueDays,
        returnRemarks: end.remarks ?? null,
        receivedBy: uid,
        updatedAt: ago(-end.on),
      });
      const amount = overdueFine(policy, overdueDays);
      if (amount > 0) {
        raiseFine(`${loanId}__overdue`, {
          type: 'overdue',
          amount,
          member: o.member,
          code: o.code,
          loanId,
          on: end.on,
          calculation: {
            overdueDays,
            graceDays: policy.graceDays,
            fineType: policy.fineType,
            fineAmount: policy.fineAmount,
            maxFine: policy.maxFine,
          },
        });
      }
    } else {
      Object.assign(loan, {
        status: 'lost',
        lostDate: dayAt(end.on),
        lostRemarks: end.remarks,
        charge: end.charge,
        receivedBy: uid,
        updatedAt: ago(-end.on),
      });
      copy.status = 'lost';
      raiseFine(`${loanId}__lost`, {
        type: 'lost',
        amount: end.charge,
        member: o.member,
        code: o.code,
        loanId,
        on: end.on,
        calculation: { copyPrice: copy.price, charge: end.charge },
      });
    }
    loans.push(loan);
    put(`libraryLoans/${loanId}`, loan);
    return { loanId, loan };
  }

  // Active, by due date: on time, due today, due soon, then overdue by 1 (inside grace), 5, 20 days.
  addLoan('a01', { member: student(1), code: barcode(1, 1), policy: 'mainStudent', issued: -3 });
  addLoan('a02', { member: student(2), code: barcode(2, 1), policy: 'mainStudent', issued: -14 });
  addLoan('a03', { member: student(3), code: barcode(4, 1), policy: 'mainStudent', issued: -12 });
  addLoan('a04', { member: student(4), code: barcode(5, 1), policy: 'mainStudent', issued: -15 });
  addLoan('a05', { member: student(5), code: barcode(1, 2), policy: 'mainStudent', issued: -19 });
  addLoan('a06', { member: student(6), code: barcode(13, 1), policy: 'mainStudent', issued: -34 });
  // Renewed once (due moved from day -6 to day +8).
  addLoan('a07', {
    member: student(7),
    code: barcode(7, 1),
    policy: 'mainStudent',
    issued: -20,
    renewedOn: [-7],
  });
  // Teachers (30 / 15 day loans); the single copies below get waiting lists.
  addLoan('a08', { member: teacher(1), code: barcode(3, 1), policy: 'mainTeacher', issued: -10 });
  addLoan('a09', { member: teacher(2), code: barcode(2, 2), policy: 'mainTeacher', issued: -29 });
  addLoan('a10', { member: teacher(3), code: barcode(8, 1), policy: 'mainTeacher', issued: -5 });
  // A student at the borrowing limit (3 of 3).
  addLoan('a11', { member: student(8), code: barcode(12, 1), policy: 'mainStudent', issued: -2 });
  addLoan('a12', { member: student(8), code: barcode(12, 2), policy: 'mainStudent', issued: -3 });
  addLoan('a13', { member: student(8), code: barcode(13, 2), policy: 'mainStudent', issued: -4 });
  // Junior library: one on time, one overdue.
  addLoan('a14', { member: student(9), code: barcode(6, 1), policy: 'juniorStudent', issued: -3 });
  addLoan('a15', {
    member: student(10),
    code: barcode(6, 2),
    policy: 'juniorStudent',
    issued: -12,
  });

  // Returned, with every fine outcome (copies stay as they are; history does not change their state).
  const noState = { holds: false } as const;
  addLoan('r01', {
    member: student(11),
    code: barcode(1, 3),
    policy: 'mainStudent',
    issued: -30,
    end: { kind: 'returned', on: -20 },
    ...noState,
  });
  // 6 days late: ₹8, unpaid → blocks the member.
  addLoan('r02', {
    member: student(12),
    code: barcode(5, 2),
    policy: 'mainStudent',
    issued: -40,
    end: { kind: 'returned', on: -20 },
    ...noState,
  });
  // 11 days late: ₹18, paid in full.
  const paid = addLoan('r03', {
    member: student(3),
    code: barcode(4, 2),
    policy: 'mainStudent',
    issued: -35,
    end: { kind: 'returned', on: -10 },
    ...noState,
  });
  // Reference book 10 days late: ₹50, part paid.
  const partial = addLoan('r04', {
    member: student(2),
    code: barcode(9, 1),
    policy: 'mainReference',
    issued: -30,
    end: { kind: 'returned', on: -13 },
    ...noState,
  });
  // Reference book 3 days late: ₹50, waived.
  const waived = addLoan('r05', {
    member: student(4),
    code: barcode(11, 1),
    policy: 'mainReference',
    issued: -25,
    end: { kind: 'returned', on: -15 },
    ...noState,
  });
  // ₹16 part waived, rest paid.
  const mixed = addLoan('r06', {
    member: student(6),
    code: barcode(5, 2),
    policy: 'mainStudent',
    issued: -50,
    end: { kind: 'returned', on: -26 },
    ...noState,
  });
  const fineOf = (loanId: Id) => fines.find((fine) => fine.loanId === loanId)!;
  pay(fineOf(paid.loanId), 18, 'RCPT-1042', -9);
  pay(fineOf(partial.loanId), 20, 'RCPT-1051', -5);
  waive(fineOf(waived.loanId), 50, 'School holiday delayed the return', -14);
  waive(fineOf(mixed.loanId), 6, 'Parent request', -25);
  pay(fineOf(mixed.loanId), 10, 'RCPT-1008', -24);

  // Returned damaged: an open incident, the copy is out of circulation.
  const damagedReturn = addLoan('r07', {
    member: student(6),
    code: barcode(15, 1),
    policy: 'mainStudent',
    issued: -8,
    end: { kind: 'returned', on: -2, condition: 'damaged', remarks: 'Cover torn and pages loose' },
  });
  openIncident('mock-incident-damaged-return', {
    type: 'damaged',
    code: barcode(15, 1),
    member: student(6),
    loanId: damagedReturn.loanId,
    severity: 'moderate',
    description: 'Cover torn and pages loose',
    charge: 0,
    repairStatus: 'none',
    on: -2,
  });
  copyDocs.get(barcode(15, 1))!.status = 'damaged';

  // Lost during a loan: replacement fine, open incident.
  addLoan('l01', {
    member: student(12),
    code: barcode(9, 2),
    policy: 'mainStudent',
    issued: -45,
    end: { kind: 'lost', on: -30, charge: 450, remarks: 'Reported lost by the parent' },
  });
  openIncident('mock-incident-lost-open', {
    type: 'lost',
    code: barcode(9, 2),
    member: student(12),
    loanId: 'mock-loan-l01',
    severity: null,
    description: 'Reported lost by the parent',
    charge: 450,
    repairStatus: null,
    on: -30,
  });
  // Lost and settled: charged, fine paid, copy withdrawn.
  addLoan('l02', {
    member: student(5),
    code: barcode(4, 3),
    policy: 'mainStudent',
    issued: -60,
    end: { kind: 'lost', on: -50, charge: 300, remarks: 'Left on a school trip' },
  });
  const lostDone = openIncident('mock-incident-lost-resolved', {
    type: 'lost',
    code: barcode(4, 3),
    member: student(5),
    loanId: 'mock-loan-l02',
    severity: null,
    description: 'Left on a school trip',
    charge: 300,
    repairStatus: null,
    on: -50,
  });
  resolveIncident(lostDone, 'charged', 'Replacement cost collected', -40);
  pay(fineOf('mock-loan-l02'), 300, 'RCPT-0977', -40);
  copyDocs.get(barcode(4, 3))!.status = 'withdrawn';

  // Reported at the desk with no loan: damaged with a charge (fine + blocked member), and a repaired one.
  claim(barcode(11, 1));
  openIncident('mock-incident-damaged-desk', {
    type: 'damaged',
    code: barcode(11, 1),
    member: student(6),
    severity: 'severe',
    description: 'Water damage to the first 40 pages',
    charge: 100,
    repairStatus: 'none',
    on: -3,
  });
  copyDocs.get(barcode(11, 1))!.status = 'damaged';
  raiseFine('mock-fine-damaged-desk', {
    type: 'damaged',
    amount: 100,
    member: student(6),
    code: barcode(11, 1),
    incidentId: 'mock-incident-damaged-desk',
    on: -3,
    calculation: { type: 'damaged', severity: 'severe', charge: 100 },
  });
  claim(barcode(7, 2));
  const repaired = openIncident('mock-incident-repaired', {
    type: 'damaged',
    code: barcode(7, 2),
    severity: 'minor',
    description: 'Loose binding',
    charge: 0,
    repairStatus: 'none',
    on: -25,
  });
  resolveIncident(repaired, 'repaired', 'Rebound in-house', -20, 80);
  repaired.repairStatus = 'repaired';

  // Other copy states.
  claim(barcode(10, 1));
  Object.assign(copyDocs.get(barcode(10, 1))!, {
    status: 'under_maintenance',
    remarks: 'Spine being rebound',
  });
  claim(barcode(15, 2));
  Object.assign(copyDocs.get(barcode(15, 2))!, {
    status: 'withdrawn',
    remarks: 'Pages missing; written off',
  });

  // ---- reservations ----
  const reservations: Doc[] = [];
  function reserve(
    key: string,
    o: {
      member: Member;
      book: number;
      library?: Id;
      status: 'waiting' | 'ready' | 'fulfilled' | 'cancelled' | 'expired';
      createdAgo: number;
      heldCode?: string;
      holdUntil?: number;
      fulfilledLoan?: Id;
      fulfilledCode?: string;
    },
  ) {
    const reservation: Doc = {
      number: number('RSV'),
      memberType: o.member.type,
      personErpId: o.member.id,
      memberName: o.member.name,
      catalogueId: titleIds[o.book - 1],
      title: titleNames[o.book - 1],
      libraryId: o.library ?? 'mock-main',
      campusId,
      status: o.status,
      heldBarcode: o.heldCode ?? null,
      holdUntil: o.holdUntil === undefined ? null : dayAt(o.holdUntil),
      fulfilledLoanId: o.fulfilledLoan ?? null,
      fulfilledBarcode: o.fulfilledCode ?? null,
      createdBy: uid,
      createdAt: ago(o.createdAgo),
    };
    if (o.status === 'ready') reservation.readyAt = ago(1);
    if (o.status === 'cancelled')
      Object.assign(reservation, { cancelledBy: uid, cancelledAt: ago(o.createdAgo - 1) });
    if (o.status === 'expired') Object.assign(reservation, { expiredAt: ago(2) });
    if (o.status === 'fulfilled') reservation.fulfilledAt = ago(o.createdAgo - 1);
    reservations.push(reservation);
    put(`libraryReservations/mock-reservation-${key}`, reservation);
    if (o.status === 'ready') {
      Object.assign(copyDocs.get(o.heldCode!)!, {
        status: 'reserved',
        heldReservationId: `mock-reservation-${key}`,
      });
    }
    return reservation;
  }
  // Waiting list of three on the one copy that is out (queue order = oldest first).
  reserve('w1', { member: student(4), book: 3, status: 'waiting', createdAgo: 5 });
  reserve('w2', { member: student(6), book: 3, status: 'waiting', createdAgo: 3 });
  reserve('w3', { member: student(11), book: 3, status: 'waiting', createdAgo: 1 });
  reserve('w4', { member: student(1), book: 8, status: 'waiting', createdAgo: 2 });
  // A copy being held for a member (collect within 2 days).
  claim(barcode(14, 1));
  reserve('ready', {
    member: student(3),
    book: 14,
    library: 'mock-junior',
    status: 'ready',
    createdAgo: 4,
    heldCode: barcode(14, 1),
    holdUntil: 2,
  });
  reserve('fulfilled', {
    member: student(11),
    book: 1,
    status: 'fulfilled',
    createdAgo: 33,
    fulfilledLoan: 'mock-loan-r01',
    fulfilledCode: barcode(1, 3),
  });
  reserve('cancelled', { member: student(9), book: 3, status: 'cancelled', createdAgo: 8 });
  reserve('expired', {
    member: student(2),
    book: 8,
    status: 'expired',
    createdAgo: 9,
    heldCode: barcode(8, 1),
    holdUntil: -3,
  });

  // ---- members: blocks follow the fines; one is blocked by hand ----
  for (const member of members) {
    if (
      fines.some(
        (fine) =>
          fine.personErpId === member.id &&
          ['outstanding', 'partially_paid'].includes(fine.status as string),
      )
    ) {
      Object.assign(member.doc, { blocked: true, blockedBy: 'fine' });
    }
  }
  Object.assign(student(9).doc, {
    blocked: true,
    blockedBy: 'manual',
    blockReason: 'Library card suspended after repeated late returns',
  });
  for (const member of members) put(`libraryMembers/${member.id}`, member.doc);
  for (const [code, copy] of copyDocs) put(`libraryCopies/${code}`, copy);

  // ---- counters, then write in batches ----
  for (const [type, next] of counters)
    put(`counters/${type}_${fy}`, { next, updatedAt: Timestamp.now() });
  const entries = [...out];
  for (let start = 0; start < entries.length; start += 400) {
    const batch = db.batch();
    for (const [path, data] of entries.slice(start, start + 400)) batch.set(db.doc(path), data);
    await batch.commit();
  }
  return {
    titles: BOOKS.length,
    copies: copyDocs.size,
    members: members.length,
    loans: loans.length,
    reservations: reservations.length,
    fines: fines.length,
    incidents: incidents.length,
  };
}

/** `library-mockData-fill`: emulator only; needs library settings, catalogue and circulation rights. */
export const mockDataFill = onCall(async (request) => {
  if (process.env.FUNCTIONS_EMULATOR !== 'true')
    throw new HttpsError('failed-precondition', 'Mock data is only available on the emulator');
  const { auth } = request;
  if (!auth || auth.token.schoolId == null)
    throw new HttpsError('unauthenticated', 'Sign in required');
  const schoolId = String(auth.token.schoolId);
  const db = getFirestore();
  const access = (await db.doc(`schools/${schoolId}/userAccess/${auth.uid}`).get()).data();
  const needed = ['library.settings', 'library.catalogue', 'library.circulation.operate'];
  if (!access || !needed.every((permission) => access.permissions?.includes(permission)))
    throw new HttpsError('permission-denied', 'Not allowed');
  return fillMockData(db, schoolId, auth.uid, (access.campusIds as number[] | undefined)?.[0] ?? 1);
});
