import 'dart:math';

import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/models/library_loans.dart';
import 'package:school_library/src/services/write_support.dart';

typedef _Json = Map<String, dynamic>;
typedef _Ref = DocumentReference<_Json>;

/// Circulation without Cloud Functions: issue, return, renew and mark lost. `firestore.rules` checks who,
/// the shape; business checks live here. Each loan write stamps `lastWrite` (audited by
/// `auditLibraryLoans`) and `firebase/functions/src/library/notices.ts` sends the member's notices.
///
/// ponytail: queries (policy, borrowing limit) run just before the transaction, which
/// client transactions cannot do; two desks acting in the same instant could exceed a limit.
/// Retries are not idempotent.
@lazySingleton
class LoanWrites {
  static const _snapshotFields = [
    'loanDays',
    'maxRenewals',
    'fineType',
    'fineAmount',
    'graceDays',
    'maxFine',
  ];

  String _addDays(String day, int days) =>
      DateTime.parse('${day}T00:00:00Z').add(Duration(days: days)).toApiDate();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<_Ref> _loanReference(String id) => schoolDocument('libraryLoans', id);

  Future<_Ref> _memberReference(int personErpId) =>
      schoolDocument('libraryMembers', '$personErpId');

  /// The active policy of a person type in a library that covers a book of [categoryId]: one naming the
  /// category, else its parent, else the catch-all; the person type's policies win over 'all'.
  Future<({String id, _Json data})?> _applicablePolicy(
    String libraryId,
    String memberType,
    String categoryId,
  ) async {
    final policies =
        (await (await branchCollection('libraryBorrowingPolicies'))
                .where('libraryId', isEqualTo: libraryId)
                .where('memberType', whereIn: [memberType, 'all'])
                .where('status', isEqualTo: 'active')
                .get())
            .docs;
    final parentId =
        (await (await schoolDocument(
              'libraryCategories',
              categoryId,
            )).get()).data()?['parentId']
            as String?;
    for (final type in [memberType, 'all']) {
      final own = policies.where((policy) => policy['memberType'] == type);
      bool covers(QueryDocumentSnapshot<_Json> policy, String? category) =>
          category != null &&
          (policy['categoryIds'] as List).contains(category);
      final policy = [
        ...own.where((policy) => covers(policy, categoryId)),
        ...own.where((policy) => covers(policy, parentId)),
        ...own.where((policy) => (policy['categoryIds'] as List).isEmpty),
      ].firstOrNull;
      if (policy != null) return (id: policy.id, data: policy.data());
    }
    return null;
  }

  /// A copy came free: it goes back on the shelf.
  void _release(Transaction transaction, _Ref copyReference) {
    transaction.update(copyReference, {
      'status': CopyStatus.available,
      'activeLoanId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, Object?> _newFine({
    required String type,
    required double amount,
    required _Json member,
    required _Json loan,
    required String? bookTitle,
    required String? loanId,
    String? incidentId,
    required Map<String, Object?> calculation,
  }) => {
    'incidentId': ?incidentId,
    'loanId': loanId,
    'memberType': member['memberType'],
    'personErpId': member['personErpId'],
    'memberName': member['name'],
    'memberClassId': member['classId'],
    'memberSection': member['section'],
    'admissionNumber': member['admissionNumber'],
    'bookTitle': bookTitle,
    'barcode': loan['barcode'],
    'catalogueId': loan['catalogueId'],
    'libraryId': loan['libraryId'],
    'type': type,
    'amount': amount,
    'waived': 0,
    'paid': 0,
    'outstanding': amount,
    'status': 'outstanding',
    'fineCalculation': calculation,
    'waivers': <Object?>[],
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': _uid,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, Object?> _newIncident({
    required String type,
    required _Json copy,
    required String barcode,
    required String? bookTitle,
    required _Json? member,
    required String? loanId,
    required String? severity,
    required String? description,
    required double charge,
    required String? repairStatus,
    Map<String, Object?> extra = const {},
  }) => {
    ...extra,
    'type': type,
    'barcode': barcode,
    'bookTitle': bookTitle,
    'catalogueId': copy['catalogueId'],
    'libraryId': copy['libraryId'],
    'memberType': member?['memberType'],
    'personErpId': member?['personErpId'],
    'memberName': member?['name'],
    'memberClassId': member?['classId'],
    'memberSection': member?['section'],
    'admissionNumber': member?['admissionNumber'],
    'loanId': ?loanId,
    'severity': severity,
    'description': description,
    'photos': <Object?>[],
    'charge': charge,
    'repairStatus': repairStatus,
    'status': 'open',
    'resolution': null,
    'resolvedAt': null,
    'reportedDate': dayTimestamp(todayIST()),
    'reportedBy': _uid,
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': _uid,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// The active loan [id] and its copy and member, read inside [transaction].
  Future<({_Json loan, _Json copy, _Json? member})> _readActive(
    Transaction transaction,
    _Ref loanReference,
  ) async {
    final loan = (await transaction.get(loanReference)).data();
    if (loan == null) writeFail('Loan not found', 'not-found');
    if (loan['status'] != 'active') writeFail('Loan is ${loan['status']}');
    final copy = (await transaction.get(
      await schoolDocument('libraryCopies', loan['barcode'] as String),
    )).data();
    if (copy == null) writeFail('Copy not found', 'not-found');
    if (copy['activeLoanId'] != loanReference.id) {
      writeFail('Copy is not on this loan');
    }
    final member = (await transaction.get(
      await _memberReference((loan['personErpId'] as num).toInt()),
    )).data();
    return (loan: loan, copy: copy, member: member);
  }

  Map<String, Object?> _memberAfterLoan(_Json member) => {
    'activeLoans': max(0, (member['activeLoans'] as num? ?? 0).toInt() - 1),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Issues one copy to the person [person] (type, ERP ID, name, class) from the desk.
  Future<void> issue({
    required Map<String, Object?> person,
    required String barcode,
    String? remarks,
  }) async {
    final today = todayIST();
    final personErpId = (person['personErpId']! as num).toInt();
    final memberType = person['memberType']! as String;
    final copyReference = await schoolDocument('libraryCopies', barcode);
    final earlierCopy = (await copyReference.get()).data();
    if (earlierCopy == null) writeFail('Copy not found', 'not-found');
    final title = (await (await schoolDocument(
      'libraryCatalogue',
      earlierCopy['catalogueId'] as String,
    )).get()).data();
    if (title == null) writeFail('Book not found', 'not-found');
    final found = await _applicablePolicy(
      earlierCopy['libraryId'] as String,
      memberType,
      title['categoryId'] as String,
    );
    if (found == null) {
      writeFail('No active borrowing policy for this member and book category');
    }
    final policy = found.data;
    final maxBooks = (policy['maxBooks'] as num).toInt();
    final underPolicy = await (await branchCollection('libraryLoans'))
        .where('personErpId', isEqualTo: personErpId)
        .where('status', isEqualTo: 'active')
        .where('policySnapshot.policyId', isEqualTo: found.id)
        .count()
        .get();
    if ((underPolicy.count ?? 0) >= maxBooks) {
      writeFail('Borrowing limit of $maxBooks reached');
    }
    final loanReference = (await branchCollection('libraryLoans')).doc();
    final memberReference = await _memberReference(personErpId);
    // Checked before the transaction: an error thrown inside one reaches the web UI as an opaque "Dart exception".
    if ((await memberReference.get()).data()?['blocked'] == true) {
      writeFail('This member is blocked and cannot borrow books');
    }
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final member = (await transaction.get(memberReference)).data();
      final copy = (await transaction.get(copyReference)).data();
      if (copy == null) writeFail('Copy not found', 'not-found');
      if (member?['blocked'] == true) {
        writeFail('This member is blocked and cannot borrow books');
      }
      if (copy['status'] != CopyStatus.available ||
          copy['activeLoanId'] != null) {
        writeFail('Copy is ${copy['status']}');
      }
      transaction
        ..set(loanReference, {
          'memberType': memberType,
          'personErpId': personErpId,
          'memberName': person['name'],
          'memberClassId': memberType == 'student' ? person['classId'] : null,
          'memberSection': memberType == 'student' ? person['section'] : null,
          'admissionNumber': memberType == 'student'
              ? person['admissionNumber']
              : null,
          'bookTitle': title['title'],
          'barcode': barcode,
          'catalogueId': copy['catalogueId'],
          'libraryId': copy['libraryId'],
          'issuedDate': dayTimestamp(today),
          'dueDate': dayTimestamp(
            _addDays(today, (policy['loanDays'] as num).toInt()),
          ),
          'remarks': remarks,
          'renewals': <Object?>[],
          'policySnapshot': {
            'policyId': found.id,
            for (final field in _snapshotFields) field: policy[field],
          },
          'status': LoanStatus.active,
          'issuedBy': _uid,
          'lastWrite': writeStamp('libraryLoan.issue'),
        })
        ..update(copyReference, {
          'status': CopyStatus.issued,
          'activeLoanId': loanReference.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      final shown = {
        'name': person['name'],
        'classId': memberType == 'student' ? person['classId'] : null,
        'section': memberType == 'student' ? person['section'] : null,
        'admissionNumber': memberType == 'student'
            ? person['admissionNumber']
            : null,
      };
      if (member == null) {
        transaction.set(memberReference, {
          'memberType': memberType,
          'personErpId': personErpId,
          ...shown,
          'activeLoans': 1,
          'blocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(memberReference, {
          ...shown,
          'activeLoans': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Returns a book against its active loan; a damaged copy is never made available. An overdue return
  /// raises the fine `<loanId>__overdue` and blocks the member.
  Future<void> returnLoan({
    required String id,
    required String condition,
    String? remarks,
  }) async {
    if (condition != 'good' && condition != 'damaged') {
      writeFail('Invalid condition');
    }
    final loanReference = await _loanReference(id);
    final earlier = await loanReference.get();
    if (!earlier.exists) writeFail('Loan not found', 'not-found');
    final earlierLoan = LibraryLoan.fromMap(id, earlier.data()!);
    final today = todayIST();
    final fineAmount = earlierLoan.fineOn(today);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final read = await _readActive(transaction, loanReference);
      final loan = read.loan;
      final member = read.member;
      final copyReference = await schoolDocument(
        'libraryCopies',
        loan['barcode'] as String,
      );
      final overdueDays = earlierLoan.overdueOn(today);
      final fined = fineAmount > 0 && member != null;
      transaction.update(loanReference, {
        'status': LoanStatus.returned,
        'returnedDate': dayTimestamp(today),
        'condition': condition,
        'overdueDays': overdueDays,
        'returnRemarks': remarks,
        'receivedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('libraryLoan.return'),
      });
      if (fined) {
        final policy = loan['policySnapshot'] as Map;
        transaction.set(
          await schoolDocument('libraryFines', '${id}__overdue'),
          _newFine(
            type: 'overdue',
            amount: fineAmount,
            member: member,
            loan: loan,
            bookTitle: loan['bookTitle'] as String?,
            loanId: id,
            calculation: {
              'overdueDays': overdueDays,
              'graceDays': policy['graceDays'] ?? 0,
              'fineType': policy['fineType'],
              'fineAmount': policy['fineAmount'],
              'maxFine': policy['maxFine'],
            },
          ),
        );
      }
      if (condition == 'damaged') {
        transaction
          ..update(copyReference, {
            'status': CopyStatus.damaged,
            'activeLoanId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(
            (await branchCollection('libraryIncidents')).doc(),
            _newIncident(
              type: 'damaged',
              copy: read.copy,
              barcode: copyReference.id,
              bookTitle: loan['bookTitle'] as String?,
              member: member,
              loanId: id,
              severity: 'moderate',
              description: remarks ?? 'Returned in damaged condition',
              charge: 0,
              repairStatus: 'none',
            ),
          );
      } else {
        _release(transaction, copyReference);
      }
      if (member != null) {
        transaction.update(
          await _memberReference((loan['personErpId'] as num).toInt()),
          _memberAfterLoan(member),
        );
      }
    });
  }

  /// Marks a book lost during a loan: the replacement [charge] (the copy's price when omitted) is fined
  /// to the member, who is blocked, and a lost-book incident is recorded.
  Future<void> markLost({
    required String id,
    String? reason,
    double? charge,
  }) async {
    final loanReference = await _loanReference(id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final read = await _readActive(transaction, loanReference);
      final loan = read.loan;
      final member = read.member;
      final copyReference = await schoolDocument(
        'libraryCopies',
        loan['barcode'] as String,
      );
      final replacement =
          charge ?? (read.copy['price'] as num? ?? 0).toDouble();
      if (replacement < 0) writeFail('Charge cannot be negative');
      transaction
        ..update(loanReference, {
          'status': LoanStatus.lost,
          'lostDate': dayTimestamp(todayIST()),
          'lostRemarks': reason,
          'charge': replacement,
          'receivedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastWrite': writeStamp('libraryLoan.markLost', reason),
        })
        ..update(copyReference, {
          'status': CopyStatus.lost,
          'activeLoanId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      if (member != null) {
        transaction.update(
          await _memberReference((loan['personErpId'] as num).toInt()),
          _memberAfterLoan(member),
        );
        if (replacement > 0) {
          transaction.set(
            await schoolDocument('libraryFines', '${id}__lost'),
            _newFine(
              type: 'lost',
              amount: replacement,
              member: member,
              loan: loan,
              bookTitle: loan['bookTitle'] as String?,
              loanId: id,
              calculation: {
                'copyPrice': read.copy['price'],
                'charge': replacement,
              },
            ),
          );
        }
      }
      transaction.set(
        (await branchCollection('libraryIncidents')).doc(),
        _newIncident(
          type: 'lost',
          copy: read.copy,
          barcode: copyReference.id,
          bookTitle: loan['bookTitle'] as String?,
          member: member,
          loanId: id,
          severity: null,
          description: reason ?? 'Marked lost during loan',
          charge: replacement,
          repairStatus: null,
        ),
      );
    });
  }

  /// Hand-set status of a copy from book details. Damaged and lost also open an incident (no loan, no
  /// member, no fine) so the copy shows under Lost & Damaged. Lost and withdrawn are final.
  Future<void> setCopyStatus(String id, String status, String? reason) async {
    if (!manualCopyStatuses.contains(status)) writeFail('Invalid status');
    final trimmed = reason?.trim();
    final needsReason =
        status != CopyStatus.available && status != CopyStatus.underMaintenance;
    if (needsReason && (trimmed == null || trimmed.isEmpty)) {
      writeFail('A reason is required');
    }
    final copyReference = await schoolDocument('libraryCopies', id);
    final incidents = await branchCollection('libraryIncidents');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final copy = (await transaction.get(copyReference)).data();
      if (copy == null) writeFail('Copy not found', 'not-found');
      if (!manualCopyStatuses.contains(copy['status'])) {
        writeFail('Copy is ${copy['status']}');
      }
      if (terminalCopyStatuses.contains(copy['status'])) {
        writeFail('Copy is ${copy['status']}');
      }
      if (copy['status'] == status) return;
      final title = (await transaction.get(
        await schoolDocument('libraryCatalogue', copy['catalogueId'] as String),
      )).data();
      transaction.update(copyReference, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('libraryCopy.status', trimmed),
      });
      if (status == CopyStatus.damaged || status == CopyStatus.lost) {
        transaction.set(
          incidents.doc(),
          _newIncident(
            type: status,
            copy: copy,
            barcode: id,
            bookTitle: title?['title'] as String?,
            member: null,
            loanId: null,
            severity: status == CopyStatus.damaged ? 'moderate' : null,
            description: trimmed,
            charge: 0,
            repairStatus: status == CopyStatus.damaged ? 'none' : null,
          ),
        );
      }
    });
  }

  /// Extends the due date by the loan's own `loanDays`, counted from the later of due date and today.
  Future<void> renew(String id) async {
    final loanReference = await _loanReference(id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final loan = (await transaction.get(loanReference)).data();
      if (loan == null) writeFail('Loan not found', 'not-found');
      if (loan['status'] != 'active') writeFail('Loan is ${loan['status']}');
      final member = (await transaction.get(
        await _memberReference((loan['personErpId'] as num).toInt()),
      )).data();
      if (member == null || member['blocked'] == true) {
        writeFail('Member cannot renew');
      }
      final policy = loan['policySnapshot'] as Map;
      final renewals = (loan['renewals'] as List).cast<Object?>();
      final maxRenewals = (policy['maxRenewals'] as num).toInt();
      if (renewals.length >= maxRenewals) {
        writeFail('Renewal limit of $maxRenewals reached');
      }
      final today = todayIST();
      final currentDue = readDay(loan['dueDate']);
      if (currentDue.compareTo(today) < 0) {
        writeFail('Overdue loans cannot be renewed');
      }
      final dueDate = dayTimestamp(
        _addDays(currentDue, (policy['loanDays'] as num).toInt()),
      );
      transaction.update(loanReference, {
        'dueDate': dueDate,
        'renewals': [
          ...renewals,
          {
            'renewedDate': dayTimestamp(today),
            'newDueDate': dueDate,
            'performedBy': _uid,
          },
        ],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('libraryLoan.renew'),
      });
    });
  }

  /// Resolves an open incident. Repaired or dismissed copies go back to the shelf (a dismissed lost copy's fine is waived); written-off, replaced and paid-for lost copies are withdrawn. A higher [charge] fines the
  /// difference.
  Future<void> resolveIncident({
    required String id,
    required String resolution,
    double? repairCost,
    double? charge,
    String? remarks,
  }) async {
    const resolutions = [
      'repaired',
      'replaced',
      'written_off',
      'charged',
      'dismissed',
    ];
    if (!resolutions.contains(resolution)) writeFail('Invalid resolution');
    final incidentReference = await schoolDocument('libraryIncidents', id);
    final earlier = (await incidentReference.get()).data();
    if (earlier == null) writeFail('Incident not found', 'not-found');
    if (earlier['status'] != 'open') {
      writeFail('Incident is already ${earlier['status']}');
    }
    if (resolution == 'repaired' && earlier['type'] != 'damaged') {
      writeFail('Only a damaged copy can be repaired');
    }
    final earlierCharge = (earlier['charge'] as num? ?? 0).toDouble();
    final newCharge = charge ?? earlierCharge;
    if (newCharge < earlierCharge) {
      writeFail('Charge cannot be lowered on resolve; waive the fine instead');
    }
    final difference = newCharge - earlierCharge;
    final personErpId = (earlier['personErpId'] as num?)?.toInt();
    final copyReference = await schoolDocument(
      'libraryCopies',
      earlier['barcode'] as String,
    );
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final incident = (await transaction.get(incidentReference)).data();
      if (incident == null) writeFail('Incident not found', 'not-found');
      if (incident['status'] != 'open') {
        writeFail('Incident is already ${incident['status']}');
      }
      final copy = (await transaction.get(copyReference)).data();
      if (copy == null) writeFail('Copy not found', 'not-found');
      if (resolution == 'repaired' && incident['type'] != 'damaged') {
        writeFail('Only a damaged copy can be repaired');
      }
      final memberReference = difference > 0 && personErpId != null
          ? await _memberReference(personErpId)
          : null;
      final member = memberReference == null
          ? null
          : (await transaction.get(memberReference)).data();
      var repairStatus = incident['repairStatus'];
      if (resolution == 'repaired' || resolution == 'dismissed') {
        if (resolution == 'repaired') repairStatus = 'repaired';
        if (copy['status'] == CopyStatus.damaged ||
            copy['status'] == CopyStatus.lost) {
          _release(transaction, copyReference);
        }
      } else if (resolution == 'written_off') {
        repairStatus = 'writeoff';
        transaction.update(copyReference, {
          'status': CopyStatus.withdrawn,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (resolution == 'replaced' ||
          (resolution == 'charged' && copy['status'] == CopyStatus.lost)) {
        // A replaced or paid-for lost copy is gone for good; a replacement comes in as a new book entry.
        transaction.update(copyReference, {
          'status': CopyStatus.withdrawn,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (member != null) {
        transaction.set(
          await schoolDocument('libraryFines', 'inc_${id}__penalty'),
          _newFine(
            type: incident['type'] as String,
            amount: difference,
            member: member,
            loan: incident,
            bookTitle: incident['bookTitle'] as String?,
            loanId: incident['loanId'] as String?,
            incidentId: id,
            calculation: {'resolution': resolution, 'charge': difference},
          ),
        );
      }
      transaction.update(incidentReference, {
        'status': 'resolved',
        'resolution': resolution,
        'resolutionRemarks': remarks,
        'repairCost': repairCost,
        'charge': newCharge,
        'repairStatus': repairStatus,
        'resolvedBy': _uid,
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('libraryIncident.resolve', remarks),
      });
    });
    if (resolution == 'dismissed' && earlier['type'] == 'lost') {
      await _waiveLostFine(earlier['loanId'] as String?);
    }
  }

  /// A lost copy that turned up was never lost: its replacement fine on loan [loanId] is waived in full.
  Future<void> _waiveLostFine(String? loanId) async {
    if (loanId == null) return;
    final fineReference = await schoolDocument(
      'libraryFines',
      '${loanId}__lost',
    );
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final fine = (await transaction.get(fineReference)).data();
      final outstanding = (fine?['outstanding'] as num? ?? 0).toDouble();
      if (outstanding <= 0) return;
      transaction.update(fineReference, {
        'waived': ((fine!['waived'] as num? ?? 0) + outstanding),
        'outstanding': 0,
        'status': 'waived',
        'waivers': [
          ...((fine['waivers'] as List?) ?? const []),
          {
            'amount': outstanding,
            'reason': 'Lost copy found: incident dismissed',
            'performedBy': _uid,
            'performedAt': Timestamp.now(),
          },
        ],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('libraryFine.waive', 'Lost copy found'),
      });
    });
  }
}
