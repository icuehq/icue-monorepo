import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';

/// Library writes that need no Cloud Function: title create / edit / status, copy edit / move and
/// manual member block. `firestore.rules` checks the shape; each write stamps `lastWrite` and the audit
/// triggers in `firebase/functions/src/library/audit.ts` log it. No retry idempotency.
@lazySingleton
class LibraryWrites {
  static const _conditions = ['good', 'fair', 'poor'];

  Never _fail(String message, [String code = 'failed-precondition']) =>
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
        message: message,
      );

  Map<String, Object?> _stamp(String action, [String? reason]) => {
    'by': FirebaseAuth.instance.currentUser!.uid,
    'action': action,
    'reason': ?reason,
    'at': FieldValue.serverTimestamp(),
  };

  Future<DocumentReference<Map<String, dynamic>>> _doc(
    String collection,
    String id,
  ) async => (await schoolCollection(collection)).doc(id);

  String _words(Object? value) => ('${value ?? ''}'.toLowerCase())
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((word) => word.isNotEmpty)
      .join(' ');

  /// Identity of a title: its bibliographic details (same as the old `identityKey` in Cloud Functions).
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

  /// Creates a title, or edits it when `data['id']` is set. Returns the title's ID.
  Future<String> saveBook(Map<String, Object?> data) async {
    final fields = {...data};
    final id = fields.remove('id') as String?;
    final title = '${fields['title'] ?? ''}'.trim();
    if (title.isEmpty || title.length > 200) {
      _fail('Title must be 1 to 200 characters');
    }
    final authors = fields['authors'] as List?;
    if (authors == null || authors.isEmpty || authors.length > 10) {
      _fail('Enter 1 to 10 authors');
    }
    final key = _identityKey(fields);
    final catalogue = await schoolCollection('libraryCatalogue');
    final reference = catalogue.doc(id);
    final keys = await schoolCollection('uniqueKeys');
    final classIds = {...(fields['classIds']! as List).cast<int>()}.toList()
      ..sort();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final before = id == null
          ? null
          : (await transaction.get(reference)).data();
      if (id != null && before == null) _fail('Title not found');
      final category = (await transaction.get(
        await _doc('libraryCategories', fields['categoryId']! as String),
      )).data();
      if (category == null) _fail('Category not found');
      if (category['status'] != 'active' &&
          before?['categoryId'] != fields['categoryId']) {
        _fail('Category is inactive');
      }
      if (before == null || before['identityKey'] != key) {
        final keyReference = keys.doc(_titleKeyId(key));
        if ((await transaction.get(keyReference)).exists) {
          _fail('This book already exists in the catalogue', 'already-exists');
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
          'lastWrite': _stamp('libraryCatalogue.create'),
        });
      } else {
        transaction.update(reference, {
          ...book,
          'lastWrite': _stamp('libraryCatalogue.update'),
        });
      }
    });
    return reference.id;
  }

  Future<void> setBookActive(String id, {required bool active}) async {
    await (await _doc('libraryCatalogue', id)).update({
      'status': active ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWrite': _stamp('libraryCatalogue.status'),
    });
  }

  /// Shelf, condition and remarks of copy `data['id']`.
  Future<void> updateCopy(Map<String, Object?> data) async {
    if (!_conditions.contains(data['condition'])) _fail('Invalid condition');
    await (await _doc('libraryCopies', data['id']! as String)).update({
      'shelf': data['shelf'],
      'condition': data['condition'],
      'remarks': data['remarks'],
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWrite': _stamp('libraryCopy.update'),
    });
  }

  /// Moves an available copy to another library.
  Future<void> moveCopy(String id, String libraryId, String? shelf) async {
    final reference = await _doc('libraryCopies', id);
    final libraryReference = await _doc('libraries', libraryId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final copy = (await transaction.get(reference)).data();
      if (copy == null) _fail('Copy not found');
      if (copy['status'] != 'available') _fail('Copy is ${copy['status']}');
      if (copy['libraryId'] == libraryId) {
        _fail('Copy is already in this library');
      }
      final library = (await transaction.get(libraryReference)).data();
      if (library == null) _fail('Library not found');
      if (library['status'] != 'active') _fail('Library is inactive');
      transaction.update(reference, {
        'libraryId': libraryId,
        'campusId': library['campusId'],
        'shelf': shelf,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastWrite': _stamp('libraryCopy.move'),
      });
    });
  }

  /// Hand-set block (or lift); never lifted by paying fines.
  Future<void> setMemberBlocked(
    String id, {
    required bool blocked,
    String? reason,
  }) async {
    if (blocked && (reason == null || reason.trim().isEmpty)) {
      _fail('A reason is required to block a member');
    }
    await (await _doc('libraryMembers', id)).update({
      'blocked': blocked,
      'blockedBy': blocked ? 'manual' : null,
      'blockReason': blocked ? reason!.trim() : null,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWrite': _stamp('libraryMember.block', reason),
    });
  }
}
