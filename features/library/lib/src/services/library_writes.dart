import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/services/write_support.dart';

/// Starter borrowing rule for everyone in a library; add `libraryId`.
const defaultPolicy = <String, Object?>{
  'memberType': 'all',
  'name': 'Default policy',
  'maxBooks': 3,
  'loanDays': 14,
  'maxRenewals': 1,
  'fineType': 'per_day',
  'fineAmount': 1,
  'graceDays': 1,
  'maxFine': 100,
  'categoryIds': <String>[],
};

/// Library writes that need no Cloud Function: title create / edit / status, copy edit / move,
/// manual member block and borrowing policy create / edit / status. `firestore.rules` checks the shape; each write stamps `lastWrite` and the audit
/// triggers in `firebase/functions/src/library/audit.ts` log it. No retry idempotency.
@lazySingleton
class LibraryWrites {
  static const _conditions = ['good', 'fair', 'poor'];
  static const _fineTypes = ['none', 'per_day', 'flat'];
  static const _policyMemberTypes = ['STUDENT', 'EMPLOYEE', 'all'];

  String _words(Object? value) => ('${value ?? ''}'.toLowerCase())
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((word) => word.isNotEmpty)
      .join(' ');

  /// Identity of a title: its bibliographic details.
  String _identityKey(Map<String, Object?> book) {
    final authors = book['authors']! as List<Object?>;
    final parts = [
      book['title'],
      authors.first,
      book['edition'],
      book['publisher'],
    ].map(_words).join('|');
    return 'bib:$parts|${book['year'] ?? ''}';
  }

  /// `uniqueKeys` document ID of a title key.
  String _titleKeyId(String key) =>
      'libraryTitle_${Uri.encodeComponent(key.trim().toLowerCase())}';

  /// ID of the title that already has these bibliographic details, if any.
  Future<String?> findTitleId(Map<String, Object?> book) async {
    final authors = book['authors'] as List<Object?>?;
    if (authors == null || authors.isEmpty) return null;
    final document = await (await branchCollection('uniqueKeys'))
        .doc(_titleKeyId(_identityKey(book)))
        .get();
    return (document.data()?['documentPath'] as String?)?.split('/').last;
  }

  /// Creates a title, or edits it when `data['id']` names an existing one. A caller-chosen new `id`
  /// creates it, so retrying after a later step failed edits it instead of hitting the duplicate check.
  /// Returns the title's ID.
  Future<String> saveBook(Map<String, Object?> data) async {
    final fields = {...data};
    final id = fields.remove('id') as String?;
    final title = '${fields['title'] ?? ''}'.trim();
    if (title.isEmpty || title.length > 200) {
      writeFail('Title must be 1 to 200 characters');
    }
    final authors = fields['authors'] as List?;
    if (authors == null || authors.isEmpty || authors.length > 10) {
      writeFail('Enter 1 to 10 authors');
    }
    final key = _identityKey(fields);
    final catalogue = await branchCollection('libraryCatalogue');
    final reference = catalogue.doc(id);
    final keys = await branchCollection('uniqueKeys');
    final classIds = {...(fields['classIds']! as List).cast<int>()}.toList()
      ..sort();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final before = id == null
          ? null
          : (await transaction.get(reference)).data();
      final category = (await transaction.get(
        await schoolDocument(
          'libraryCategories',
          fields['categoryId']! as String,
        ),
      )).data();
      if (category == null) writeFail('Category not found');
      if (category['status'] != 'active' &&
          before?['categoryId'] != fields['categoryId']) {
        writeFail('Category is inactive');
      }
      if (before == null || before['identityKey'] != key) {
        final keyReference = keys.doc(_titleKeyId(key));
        if ((await transaction.get(keyReference)).exists) {
          writeFail(
            'This book already exists in the catalogue',
            'already-exists',
          );
        }
        transaction.set(keyReference, {
          'keyType': 'libraryTitle',
          'value': key.trim().toLowerCase(),
          'documentPath': reference.path.split('/').skip(2).join('/'),
        });
        if (before != null) {
          transaction.delete(
            keys.doc(_titleKeyId(before['identityKey'] as String)),
          );
        }
      }
      final book = {
        ...fields,
        'classIds': classIds,
        'identityKey': key,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (before == null) {
        transaction.set(reference, {
          ...book,
          'coverPath': null,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser!.uid,
          'lastWrite': writeStamp('libraryCatalogue.create'),
        });
      } else {
        transaction.update(reference, {
          ...book,
          'lastWrite': writeStamp('libraryCatalogue.update'),
        });
      }
    });
    return reference.id;
  }

  Future<void> setBookActive(String id, {required bool active}) async {
    await (await schoolDocument('libraryCatalogue', id)).update({
      'status': active ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWrite': writeStamp('libraryCatalogue.status'),
    });
  }

  /// Shelf, condition and remarks of copy `data['id']`.
  Future<void> updateCopy(Map<String, Object?> data) async {
    if (!_conditions.contains(data['condition'])) {
      writeFail('Invalid condition');
    }
    await (await schoolDocument('libraryCopies', data['id']! as String)).update(
      {
        'shelf': data['shelf'],
        'condition': data['condition'],
        'remarks': data['remarks'],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': writeStamp('libraryCopy.update'),
      },
    );
  }

  /// Hand-set block (or lift); never lifted by paying fines.
  Future<void> setMemberBlocked(
    String id, {
    required bool blocked,
    String? reason,
  }) async {
    if (blocked && (reason == null || reason.trim().isEmpty)) {
      writeFail('A reason is required to block a member');
    }
    await (await schoolDocument('libraryMembers', id)).update({
      'blocked': blocked,
      'blockedBy': blocked ? 'manual' : null,
      'blockReason': blocked ? reason!.trim() : null,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWrite': writeStamp('libraryMember.block', reason),
    });
  }

  /// Refuses [categoryIds] (empty: the catch-all) when another active policy of the library and person
  /// type already covers them. ponytail: checked before the write, not atomic (client transactions
  /// cannot query); two librarians saving at the same instant could overlap.
  Future<void> _assertNoOverlap(
    String libraryId,
    String memberType,
    List<String> categoryIds,
    String? selfId,
  ) async {
    final others = await (await branchCollection('libraryBorrowingPolicies'))
        .where('libraryId', isEqualTo: libraryId)
        .where('memberType', isEqualTo: memberType)
        .where('status', isEqualTo: 'active')
        .get();
    for (final other in others.docs) {
      if (other.id == selfId) continue;
      final taken = (other['categoryIds'] as List).cast<String>();
      if (categoryIds.isEmpty && taken.isEmpty) {
        writeFail('"${other['name']}" already covers all other categories');
      }
      if (categoryIds.any(taken.contains)) {
        writeFail('A selected category already belongs to "${other['name']}"');
      }
    }
  }

  /// Creates a borrowing policy, or edits `data['id']`. Returns its ID.
  Future<String> savePolicy(Map<String, Object?> data) async {
    final id = data['id'] as String?;
    final libraryId = data['libraryId']! as String;
    final memberType = data['memberType']! as String;
    final fineType = data['fineType']! as String;
    final fineAmount = (data['fineAmount']! as num).toDouble();
    final maxFine = (data['maxFine'] as num?)?.toDouble();
    final categoryIds = {...(data['categoryIds']! as List).cast<String>()}
        .toList();
    final name = '${data['name'] ?? ''}'.trim();
    if (name.isEmpty || name.length > 200) {
      writeFail('Name must be 1 to 200 characters');
    }
    if (!_policyMemberTypes.contains(memberType)) {
      writeFail('Invalid member type');
    }
    if (!_fineTypes.contains(fineType)) writeFail('Invalid fine type');
    if (fineType != 'none' && fineAmount <= 0) {
      writeFail('A fine needs an amount');
    }
    if (categoryIds.length > 50) writeFail('Choose at most 50 categories');
    final reference = (await branchCollection('libraryBorrowingPolicies'))
        .doc(id);
    final before = id == null ? null : (await reference.get()).data();
    if (id != null && before == null) {
      writeFail('Policy not found', 'not-found');
    }
    if (before != null &&
        (before['libraryId'] != libraryId ||
            before['memberType'] != memberType)) {
      writeFail('The library and member type of a policy cannot change');
    }
    final library = (await (await schoolDocument(
      'libraries',
      libraryId,
    )).get()).data();
    if (library == null) writeFail('Library not found', 'not-found');
    if (before == null && library['status'] != 'active') {
      writeFail('Library is inactive');
    }
    for (final categoryId in categoryIds) {
      if (!(await (await schoolDocument(
        'libraryCategories',
        categoryId,
      )).get()).exists) {
        writeFail('Category not found');
      }
    }
    await _assertNoOverlap(libraryId, memberType, categoryIds, id);
    final policy = {
      'name': name,
      'libraryId': libraryId,
      'memberType': memberType,
      'maxBooks': data['maxBooks'],
      'loanDays': data['loanDays'],
      'maxRenewals': data['maxRenewals'],
      'fineType': fineType,
      'fineAmount': fineType == 'none' ? 0 : fineAmount,
      'graceDays': data['graceDays'],
      'maxFine': fineType == 'none' ? null : maxFine,
      'categoryIds': categoryIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (before == null) {
      await reference.set({
        ...policy,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser!.uid,
        'lastWrite': writeStamp('libraryPolicy.create'),
      });
    } else {
      await reference.update({
        ...policy,
        'lastWrite': writeStamp('libraryPolicy.update'),
      });
    }
    return reference.id;
  }

  Future<void> setPolicyActive(String id, {required bool active}) async {
    final reference = await schoolDocument('libraryBorrowingPolicies', id);
    final policy = (await reference.get()).data();
    if (policy == null) writeFail('Policy not found', 'not-found');
    if (active && policy['status'] != 'active') {
      await _assertNoOverlap(
        policy['libraryId'] as String,
        policy['memberType'] as String,
        (policy['categoryIds'] as List).cast<String>(),
        id,
      );
    }
    await reference.update({
      'status': active ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWrite': writeStamp('libraryPolicy.status'),
    });
  }
}
