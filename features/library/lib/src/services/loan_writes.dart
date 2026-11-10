import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/models/library_loans.dart';
import 'package:school_library/src/services/write_support.dart';

typedef _Json = Map<String, dynamic>;
typedef _Ref = DocumentReference<_Json>;

/// Circulation without Cloud Functions: issue, return, renew, mark lost, reserve and cancel a reservation. `firestore.rules` checks who,
/// the campus and the shape; business checks live here. Each loan write stamps `lastWrite` (audited by
/// `auditLibraryLoans`) and `firebase/functions/src/library/notices.ts` sends the member's notices.
///
/// ponytail: queries (policy, borrowing limit, reservation queue) run just before the transaction, which
/// client transactions cannot do; two desks acting in the same instant could exceed a limit or renew past
/// a waiting member. Retries are not idempotent and numbers (`LIS`, `LRT`, `FIN`, `INC`, `RSV`) may skip.
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
  static const _defaultHoldDays = 3;

  String _addDays(String day, int days) =>
      DateTime.parse('${day}T00:00:00Z').add(Duration(days: days)).toApiDate();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<_Ref> _loanReference(String id) => schoolDocument('libraryLoans', id);

  Future<_Ref> _memberReference(int personErpId) =>
      schoolDocument('libraryMembers', '$personErpId');

  /// Next `TYPE/2026-27/000123`, from a counter document updated in a transaction of its own.
  Future<String> _nextNumber(String type) async {
    final financialYear = DateTime.now().toIndianTime().financialYear;
    final counter = await schoolDocument('counters', '${type}_$financialYear');
    final next = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      final value =
          (((await transaction.get(counter)).data()?['next'] as num?) ?? 0)
              .toInt() +
          1;
      transaction.set(counter, {
        'next': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return value;
    });
    return '$type/$financialYear/${next.toString().padLeft(6, '0')}';
  }

  /// The active policy of a person type in a library that covers a book of [categoryId]: one naming the
  /// category, else its parent, else the catch-all; the person type's policies win over 'all'.
  Future<({String id, _Json data})?> _applicablePolicy(
    String libraryId,
    String memberType,
    String categoryId,
  ) async {
    final policies =
        (await (await schoolCollection('libraryBorrowingPolicies'))
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
      for (final policy in [
        ...own.where((policy) => covers(policy, categoryId)),
        ...own.where((policy) => covers(policy, parentId)),
        ...own.where((policy) => (policy['categoryIds'] as List).isEmpty),
      ]) {
        return (id: policy.id, data: policy.data());
      }
    }
    return null;
  }

  /// The first waiting reservation of a title in a library whose member can still borrow.
  Future<_Ref?> _nextWaiting(String catalogueId, String libraryId) async {
    final waiting = await (await schoolCollection('libraryReservations'))
        .where('status', isEqualTo: 'waiting')
        .where('catalogueId', isEqualTo: catalogueId)
        .where('libraryId', isEqualTo: libraryId)
        .orderBy('createdAt')
        .limit(11)
        .get();
    for (final reservation in waiting.docs) {
      final member = (await (await _memberReference(
        (reservation['personErpId'] as num).toInt(),
      )).get()).data();
      if (member != null && member['blocked'] != true) {
        return reservation.reference;
      }
    }
    return null;
  }

  Future<int> _holdDays() async {
    final days =
        (await (await schoolDocument(
              'config',
              'librarySettings',
            )).get()).data()?['holdDays']
            as num?;
    return days != null && days >= 1 ? days.toInt() : _defaultHoldDays;
  }

  /// A copy came free: [waiting] gets it when still waiting, otherwise it goes back on the shelf.
  /// [waiting] must be read before any write of the transaction.
  void _release(
    Transaction transaction,
    _Ref copyReference,
    ({_Ref reference, _Json? data})? waiting,
    int holdDays,
  ) {
    if (waiting != null && waiting.data?['status'] == 'waiting') {
      transaction
        ..update(waiting.reference, {
          'status': 'ready',
          'heldBarcode': copyReference.id,
          'holdUntil': dayTimestamp(_addDays(todayIST(), holdDays)),
          'readyAt': FieldValue.serverTimestamp(),
        })
        ..update(copyReference, {
          'status': 'reserved',
          'heldReservationId': waiting.reference.id,
          'activeLoanId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    } else {
      transaction.update(copyReference, {
        'status': 'available',
        'heldReservationId': null,
        'activeLoanId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Map<String, Object?> _fineBlock(_Json member) => {
    'blocked': true,
    'blockedBy': member['blocked'] == true && member['blockedBy'] == 'manual'
        ? 'manual'
        : 'fine',
  };

  Map<String, Object?> _newFine({
    required String number,
    required String type,
    required double amount,
    required _Json member,
    required _Json loan,
    required String? loanId,
    String? incidentId,
    required Map<String, Object?> calculation,
  }) => {
    'fineNumber': number,
    'incidentId': ?incidentId,
    'loanId': loanId,
    'memberType': member['memberType'],
    'personErpId': member['personErpId'],
    'memberName': member['name'],
    'barcode': loan['barcode'],
    'catalogueId': loan['catalogueId'],
    'libraryId': loan['libraryId'],
    'campusId': loan['campusId'],
    'type': type,
    'amount': amount,
    'waived': 0,
    'paid': 0,
    'outstanding': amount,
    'status': 'outstanding',
    'fineCalculation': calculation,
    'waivers': <Object?>[],
    'payments': <Object?>[],
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': _uid,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, Object?> _newIncident({
    required String number,
    required String type,
    required _Json copy,
    required String barcode,
    required _Json? member,
    required String? loanId,
    required String? severity,
    required String? description,
    required double charge,
    required String? repairStatus,
    Map<String, Object?> extra = const {},
  }) => {
    ...extra,
    'incidentNumber': number,
    'type': type,
    'barcode': barcode,
    'catalogueId': copy['catalogueId'],
    'libraryId': copy['libraryId'],
    'campusId': copy['campusId'],
    'memberType': member?['memberType'],
    'personErpId': member?['personErpId'],
    'memberName': member?['name'],
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

  Map<String, Object?> _memberAfterLoan(_Json member, {required bool fined}) =>
      {
        'activeLoans': ((member['activeLoans'] as num? ?? 0).toInt() - 1).clamp(
          0,
          1 << 30,
        ),
        if (fined) ..._fineBlock(member),
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
    final underPolicy = await (await schoolCollection('libraryLoans'))
        .where('personErpId', isEqualTo: personErpId)
        .where('status', isEqualTo: 'active')
        .where('policySnapshot.policyId', isEqualTo: found.id)
        .count()
        .get();
    if ((underPolicy.count ?? 0) >= maxBooks) {
      writeFail('Borrowing limit of $maxBooks reached');
    }
    final number = await _nextNumber('LIS');
    final loanReference = (await schoolCollection('libraryLoans')).doc();
    final memberReference = await _memberReference(personErpId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final member = (await transaction.get(memberReference)).data();
      final copy = (await transaction.get(copyReference)).data();
      if (copy == null) writeFail('Copy not found', 'not-found');
      if (member?['blocked'] == true) writeFail('Member is blocked');
      _Ref? held;
      if (copy['status'] == 'reserved') {
        held = await schoolDocument(
          'libraryReservations',
          copy['heldReservationId'] as String,
        );
        final reservation = (await transaction.get(held)).data();
        if (reservation == null ||
            reservation['personErpId'] != personErpId ||
            reservation['status'] != 'ready') {
          writeFail('Copy is held for another member');
        }
        final holdUntil = readDayOrNull(reservation['holdUntil']);
        if (holdUntil == null || holdUntil.compareTo(today) < 0) {
          writeFail('The hold on this copy has expired');
        }
      } else if (copy['status'] != 'available' ||
          copy['activeLoanId'] != null) {
        writeFail('Copy is ${copy['status']}');
      }
      transaction
        ..set(loanReference, {
          'number': number,
          'memberType': memberType,
          'personErpId': personErpId,
          'memberName': person['name'],
          'barcode': barcode,
          'catalogueId': copy['catalogueId'],
          'libraryId': copy['libraryId'],
          'campusId': copy['campusId'],
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
          'status': 'active',
          'issuedBy': _uid,
          'lastWrite': writeStamp('libraryLoan.issue'),
        })
        ..update(copyReference, {
          'status': 'issued',
          'activeLoanId': loanReference.id,
          'heldReservationId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      if (held != null) {
        transaction.update(held, {
          'status': 'fulfilled',
          'fulfilledLoanId': loanReference.id,
          'fulfilledBarcode': barcode,
          'fulfilledAt': FieldValue.serverTimestamp(),
        });
      }
      final shown = {
        'name': person['name'],
        'classId': memberType == 'student' ? person['classId'] : null,
      };
      if (member == null) {
        transaction.set(memberReference, {
          'memberType': memberType,
          'personErpId': personErpId,
          ...shown,
          'campusIds': [copy['campusId']],
          'activeLoans': 1,
          'blocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(memberReference, {
          ...shown,
          'campusIds': FieldValue.arrayUnion([copy['campusId']]),
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
    final returnNumber = await _nextNumber('LRT');
    final fineNumber = fineAmount > 0 ? await _nextNumber('FIN') : null;
    final incidentNumber = condition == 'damaged'
        ? await _nextNumber('INC')
        : null;
    final waitingReference = condition == 'good'
        ? await _nextWaiting(earlierLoan.catalogueId, earlierLoan.libraryId)
        : null;
    final holdDays = waitingReference == null ? 0 : await _holdDays();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final read = await _readActive(transaction, loanReference);
      final waiting = waitingReference == null
          ? null
          : (
              reference: waitingReference,
              data: (await transaction.get(waitingReference)).data(),
            );
      final loan = read.loan;
      final member = read.member;
      final copyReference = await schoolDocument(
        'libraryCopies',
        loan['barcode'] as String,
      );
      final overdueDays = earlierLoan.overdueOn(today);
      final fined = fineAmount > 0 && member != null;
      transaction.update(loanReference, {
        'status': 'returned',
        'returnNumber': returnNumber,
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
            number: fineNumber!,
            type: 'overdue',
            amount: fineAmount,
            member: member,
            loan: loan,
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
            'status': 'damaged',
            'activeLoanId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(
            (await schoolCollection('libraryIncidents')).doc(),
            _newIncident(
              number: incidentNumber!,
              type: 'damaged',
              copy: read.copy,
              barcode: copyReference.id,
              member: member,
              loanId: id,
              severity: 'moderate',
              description: remarks ?? 'Returned in damaged condition',
              charge: 0,
              repairStatus: 'none',
            ),
          );
      } else {
        _release(transaction, copyReference, waiting, holdDays);
      }
      if (member != null) {
        transaction.update(
          await _memberReference((loan['personErpId'] as num).toInt()),
          _memberAfterLoan(member, fined: fined),
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
    final incidentNumber = await _nextNumber('INC');
    final fineNumber = await _nextNumber('FIN');
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
          'status': 'lost',
          'lostDate': dayTimestamp(todayIST()),
          'lostRemarks': reason,
          'charge': replacement,
          'receivedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastWrite': writeStamp('libraryLoan.markLost', reason),
        })
        ..update(copyReference, {
          'status': 'lost',
          'activeLoanId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      if (member != null) {
        transaction.update(
          await _memberReference((loan['personErpId'] as num).toInt()),
          _memberAfterLoan(member, fined: replacement > 0),
        );
        if (replacement > 0) {
          transaction.set(
            await schoolDocument('libraryFines', '${id}__lost'),
            _newFine(
              number: fineNumber,
              type: 'lost',
              amount: replacement,
              member: member,
              loan: loan,
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
        (await schoolCollection('libraryIncidents')).doc(),
        _newIncident(
          number: incidentNumber,
          type: 'lost',
          copy: read.copy,
          barcode: copyReference.id,
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

  /// Extends the due date by the loan's own `loanDays`, counted from the later of due date and today.
  Future<void> renew(String id) async {
    final loanReference = await _loanReference(id);
    final earlier = (await loanReference.get()).data();
    if (earlier == null) writeFail('Loan not found', 'not-found');
    final waiting = await (await schoolCollection('libraryReservations'))
        .where('status', isEqualTo: 'waiting')
        .where('catalogueId', isEqualTo: earlier['catalogueId'])
        .where('libraryId', isEqualTo: earlier['libraryId'])
        .limit(1)
        .get();
    if (waiting.docs.isNotEmpty) {
      writeFail('Another member is waiting for this title');
    }
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

  /// Joins the waiting list of a title in a library, only when no copy is on the shelf and the member
  /// is eligible, has a policy for the book and holds no live reservation or loan of the title.
  Future<void> reserve({
    required Map<String, Object?> person,
    required String catalogueId,
    required String libraryId,
  }) async {
    final personErpId = (person['personErpId']! as num).toInt();
    final memberType = person['memberType']! as String;
    final library = (await (await schoolDocument(
      'libraries',
      libraryId,
    )).get()).data();
    if (library == null) writeFail('Library not found', 'not-found');
    if (library['status'] != 'active') writeFail('Library is inactive');
    final title = (await (await schoolDocument(
      'libraryCatalogue',
      catalogueId,
    )).get()).data();
    if (title == null) writeFail('Title not found', 'not-found');
    if (title['status'] != 'active') writeFail('Title is inactive');
    final memberReference = await _memberReference(personErpId);
    if ((await memberReference.get()).data()?['blocked'] == true) {
      writeFail('Member is blocked');
    }
    if (await _applicablePolicy(
          libraryId,
          memberType,
          title['categoryId'] as String,
        ) ==
        null) {
      writeFail('No active borrowing policy for this member and book category');
    }
    final live = await (await schoolCollection('libraryReservations'))
        .where('personErpId', isEqualTo: personErpId)
        .where('catalogueId', isEqualTo: catalogueId)
        .where('status', whereIn: ['waiting', 'ready'])
        .limit(1)
        .get();
    if (live.docs.isNotEmpty) {
      writeFail('Member already has a reservation for this title');
    }
    final onLoan = await (await schoolCollection('libraryLoans'))
        .where('personErpId', isEqualTo: personErpId)
        .where('catalogueId', isEqualTo: catalogueId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (onLoan.docs.isNotEmpty) {
      writeFail('Member already has this title on loan');
    }
    final shelf = await (await schoolCollection('libraryCopies'))
        .where('catalogueId', isEqualTo: catalogueId)
        .where('libraryId', isEqualTo: libraryId)
        .where('status', isEqualTo: 'available')
        .limit(1)
        .get();
    if (shelf.docs.isNotEmpty) {
      writeFail('A copy is available; issue it instead');
    }
    final number = await _nextNumber('RSV');
    final reservationReference = (await schoolCollection('libraryReservations'))
        .doc();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final member = (await transaction.get(memberReference)).data();
      if (member?['blocked'] == true) writeFail('Member is blocked');
      final shown = {
        'name': person['name'],
        'classId': memberType == 'student' ? person['classId'] : null,
      };
      transaction.set(reservationReference, {
        'number': number,
        'memberType': memberType,
        'personErpId': personErpId,
        'memberName': person['name'],
        'catalogueId': catalogueId,
        'title': title['title'],
        'libraryId': libraryId,
        'campusId': library['campusId'],
        'status': 'waiting',
        'heldBarcode': null,
        'holdUntil': null,
        'fulfilledLoanId': null,
        'fulfilledBarcode': null,
        'createdBy': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('libraryReservation.create'),
      });
      if (member == null) {
        transaction.set(memberReference, {
          'memberType': memberType,
          'personErpId': personErpId,
          ...shown,
          'campusIds': [library['campusId']],
          'activeLoans': 0,
          'blocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(memberReference, {
          ...shown,
          'campusIds': FieldValue.arrayUnion([library['campusId']]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Cancels a waiting or ready reservation; a held copy moves on to the next waiting member.
  Future<void> cancelReservation(String id) async {
    final reservationReference = await schoolDocument(
      'libraryReservations',
      id,
    );
    final earlier = (await reservationReference.get()).data();
    if (earlier == null) writeFail('Reservation not found', 'not-found');
    final waitingReference = earlier['status'] == 'ready'
        ? await _nextWaiting(
            earlier['catalogueId'] as String,
            earlier['libraryId'] as String,
          )
        : null;
    final holdDays = waitingReference == null ? 0 : await _holdDays();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final reservation = (await transaction.get(reservationReference)).data();
      if (reservation == null) writeFail('Reservation not found', 'not-found');
      final status = reservation['status'];
      if (status != 'waiting' && status != 'ready') {
        writeFail('Reservation is $status');
      }
      if (status == 'ready') {
        final copyReference = await schoolDocument(
          'libraryCopies',
          reservation['heldBarcode'] as String,
        );
        final copy = (await transaction.get(copyReference)).data();
        final waiting = waitingReference == null
            ? null
            : (
                reference: waitingReference,
                data: (await transaction.get(waitingReference)).data(),
              );
        // Unless the copy has meanwhile been taken by something else.
        if (copy?['heldReservationId'] == id) {
          _release(transaction, copyReference, waiting, holdDays);
        }
      }
      transaction.update(reservationReference, {
        'status': 'cancelled',
        'cancelledBy': _uid,
        'cancelledAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('libraryReservation.cancel'),
      });
    });
  }

  double _rounded(double value) => (value * 100).round() / 100;

  /// A fine's amounts and status after [waivedNow] and [paidNow] (money in cents, so no float drift).
  ({double waived, double paid, double outstanding, String status}) _settle(
    _Json fine, {
    double waivedNow = 0,
    double paidNow = 0,
  }) {
    final waived = _rounded((fine['waived'] as num? ?? 0) + waivedNow);
    final paid = _rounded((fine['paid'] as num? ?? 0) + paidNow);
    final outstanding = _rounded(
      (fine['outstanding'] as num) - waivedNow - paidNow,
    );
    final status = outstanding > 0
        ? (paid > 0 ? 'partially_paid' : 'outstanding')
        : (paid > 0 ? 'paid' : 'waived');
    return (
      waived: waived,
      paid: paid,
      outstanding: outstanding,
      status: status,
    );
  }

  /// Settles [fineId] with a waiver or payment [entry] and lifts the member's fine block once no other
  /// fine of theirs is open. A hand-set block is never lifted.
  Future<void> _settleFine(
    String fineId,
    String action, {
    required double amount,
    required bool waive,
    required Map<String, Object?> entry,
    required String over,
  }) async {
    final fineReference = await schoolDocument('libraryFines', fineId);
    final earlier = (await fineReference.get()).data();
    if (earlier == null) writeFail('Fine not found', 'not-found');
    final personErpId = (earlier['personErpId'] as num?)?.toInt();
    final otherOpen = personErpId == null
        ? <QueryDocumentSnapshot<_Json>>[]
        : (await (await schoolCollection('libraryFines'))
                  .where('personErpId', isEqualTo: personErpId)
                  .where('status', whereIn: ['outstanding', 'partially_paid'])
                  .limit(2)
                  .get())
              .docs
              .where((other) => other.id != fineId)
              .toList();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final fine = (await transaction.get(fineReference)).data();
      if (fine == null) writeFail('Fine not found', 'not-found');
      final outstanding = (fine['outstanding'] as num? ?? 0).toDouble();
      if (fine['status'] == 'paid' ||
          fine['status'] == 'waived' ||
          outstanding <= 0) {
        writeFail('Fine is already ${fine['status']}');
      }
      if (amount > outstanding) {
        writeFail('$over cannot exceed outstanding balance');
      }
      final settled = waive
          ? _settle(fine, waivedNow: amount)
          : _settle(fine, paidNow: amount);
      final member = personErpId == null || settled.outstanding > 0
          ? null
          : (await transaction.get(await _memberReference(personErpId))).data();
      transaction.update(fineReference, {
        'waived': settled.waived,
        'paid': settled.paid,
        'outstanding': settled.outstanding,
        'status': settled.status,
        waive ? 'waivers' : 'payments': [
          ...((fine[waive ? 'waivers' : 'payments'] as List?) ?? const []),
          entry,
        ],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp(
          action,
          waive ? entry['reason'] as String? : null,
        ),
      });
      if (member != null &&
          otherOpen.isEmpty &&
          member['blocked'] == true &&
          member['blockedBy'] != 'manual') {
        transaction.update(await _memberReference(personErpId!), {
          'blocked': false,
          'blockedBy': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Waives part or all of an outstanding fine.
  Future<void> waiveFine({
    required String id,
    required double amount,
    required String reason,
  }) async {
    if (amount < 0.01) writeFail('Enter an amount');
    if (reason.trim().isEmpty) {
      writeFail('A reason is required to waive a fine');
    }
    await _settleFine(
      id,
      'libraryFine.waive',
      amount: amount,
      waive: true,
      over: 'Waived amount',
      entry: {
        'amount': amount,
        'reason': reason.trim(),
        'performedBy': _uid,
        'performedAt': Timestamp.now(),
      },
    );
  }

  /// Records a payment against a fine (Finance reference only).
  Future<void> recordFinePayment({
    required String id,
    required double amount,
    String? reference,
  }) async {
    if (amount < 0.01) writeFail('Enter an amount');
    await _settleFine(
      id,
      'libraryFine.setPayment',
      amount: amount,
      waive: false,
      over: 'Payment amount',
      entry: {
        'amount': amount,
        'reference': reference,
        'date': dayTimestamp(todayIST()),
        'performedBy': _uid,
      },
    );
  }

  /// Reports a lost or damaged copy that is on the shelf (not on loan or held). A member held responsible
  /// ([personErpId]) with a [charge] is fined and blocked. The copy leaves circulation.
  Future<void> reportIncident({
    required String barcode,
    required String type,
    int? personErpId,
    String severity = 'moderate',
    String? description,
    double charge = 0,
  }) async {
    if (type != 'lost' && type != 'damaged') writeFail('Invalid incident type');
    if (!const ['minor', 'moderate', 'severe'].contains(severity)) {
      writeFail('Invalid severity');
    }
    if (charge < 0) writeFail('Charge cannot be negative');
    final copyReference = await schoolDocument('libraryCopies', barcode);
    final open = await (await schoolCollection('libraryIncidents'))
        .where('barcode', isEqualTo: barcode)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
    if (open.docs.isNotEmpty) writeFail('Copy already has an open incident');
    final memberReference = personErpId == null
        ? null
        : await _memberReference(personErpId);
    final incidentNumber = await _nextNumber('INC');
    final fined = personErpId != null && charge > 0;
    final fineNumber = fined ? await _nextNumber('FIN') : null;
    final incidentReference = (await schoolCollection('libraryIncidents'))
        .doc();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final copy = (await transaction.get(copyReference)).data();
      if (copy == null) writeFail('Copy not found', 'not-found');
      if (copy['status'] == 'lost' || copy['status'] == 'withdrawn') {
        writeFail('Copy is already ${copy['status']}');
      }
      if (copy['activeLoanId'] != null || copy['heldReservationId'] != null) {
        writeFail(
          'Copy is on loan or held; use Mark lost / return as damaged, or release the hold first',
        );
      }
      final member = memberReference == null
          ? null
          : (await transaction.get(memberReference)).data();
      if (memberReference != null && member == null) {
        writeFail('Member not found', 'not-found');
      }
      transaction
        ..set(
          incidentReference,
          _newIncident(
            number: incidentNumber,
            type: type,
            copy: copy,
            barcode: barcode,
            member: member,
            loanId: null,
            severity: type == 'damaged' ? severity : null,
            description: description,
            charge: charge,
            repairStatus: type == 'damaged' ? 'none' : null,
            extra: {'lastWrite': writeStamp('libraryIncident.report')},
          ),
        )
        ..update(copyReference, {
          'status': type == 'lost' ? 'lost' : 'damaged',
          'activeLoanId': null,
          'heldReservationId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      if (fined && member != null) {
        transaction
          ..set(
            await schoolDocument(
              'libraryFines',
              'inc_${incidentReference.id}__$type',
            ),
            _newFine(
              number: fineNumber!,
              type: type,
              amount: charge,
              member: member,
              loan: copy,
              loanId: null,
              incidentId: incidentReference.id,
              calculation: {
                'incidentNumber': incidentNumber,
                'type': type,
                'severity': severity,
                'charge': charge,
              },
            ),
          )
          ..update(memberReference!, {
            ..._fineBlock(member),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      }
    });
  }

  /// Resolves an open incident. Repaired or dismissed copies go back to the shelf (or the next waiting
  /// member); written-off, replaced and paid-for lost copies are withdrawn. A higher [charge] fines the
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
    final earlierCharge = (earlier['charge'] as num? ?? 0).toDouble();
    final newCharge = charge ?? earlierCharge;
    if (newCharge < earlierCharge) {
      writeFail('Charge cannot be lowered on resolve; waive the fine instead');
    }
    final difference = newCharge - earlierCharge;
    final personErpId = (earlier['personErpId'] as num?)?.toInt();
    final fineNumber = difference > 0 && personErpId != null
        ? await _nextNumber('FIN')
        : null;
    final copyReference = await schoolDocument(
      'libraryCopies',
      earlier['barcode'] as String,
    );
    final earlierCopy = (await copyReference.get()).data();
    if (earlierCopy == null) writeFail('Copy not found', 'not-found');
    final freed =
        (resolution == 'repaired' || resolution == 'dismissed') &&
        (earlierCopy['status'] == 'damaged' || earlierCopy['status'] == 'lost');
    final waitingReference = freed
        ? await _nextWaiting(
            earlierCopy['catalogueId'] as String,
            earlierCopy['libraryId'] as String,
          )
        : null;
    final holdDays = waitingReference == null ? 0 : await _holdDays();
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
      final waiting = waitingReference == null
          ? null
          : (
              reference: waitingReference,
              data: (await transaction.get(waitingReference)).data(),
            );
      final memberReference = difference > 0 && personErpId != null
          ? await _memberReference(personErpId)
          : null;
      final member = memberReference == null
          ? null
          : (await transaction.get(memberReference)).data();
      var repairStatus = incident['repairStatus'];
      if (resolution == 'repaired' || resolution == 'dismissed') {
        if (resolution == 'repaired') repairStatus = 'repaired';
        if (copy['status'] == 'damaged' || copy['status'] == 'lost') {
          _release(transaction, copyReference, waiting, holdDays);
        }
      } else if (resolution == 'written_off') {
        repairStatus = 'writeoff';
        transaction.update(copyReference, {
          'status': 'withdrawn',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (resolution == 'replaced' ||
          (resolution == 'charged' && copy['status'] == 'lost')) {
        // A replaced or paid-for lost copy is gone for good; a replacement comes in as a new book entry.
        transaction.update(copyReference, {
          'status': 'withdrawn',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (member != null) {
        transaction
          ..set(
            await schoolDocument('libraryFines', 'inc_${id}__penalty'),
            _newFine(
              number: fineNumber!,
              type: incident['type'] as String,
              amount: difference,
              member: member,
              loan: incident,
              loanId: incident['loanId'] as String?,
              incidentId: id,
              calculation: {
                'incidentNumber': incident['incidentNumber'],
                'resolution': resolution,
                'charge': difference,
              },
            ),
          )
          ..update(memberReference!, {
            ..._fineBlock(member),
            'updatedAt': FieldValue.serverTimestamp(),
          });
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
  }
}
