import 'package:icue_firebase/icue_firebase.dart';

/// Shared by the library client writes (`LibraryWrites`, `LoanWrites`).
Never writeFail(String message, [String code = 'failed-precondition']) =>
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: code,
      message: message,
    );

/// The `lastWrite` stamp `firestore.rules` demands and the audit triggers turn into a log entry.
Map<String, Object?> writeStamp(String action, [String? reason]) => {
  'by': FirebaseAuth.instance.currentUser!.uid,
  'action': action,
  'reason': ?reason,
  'at': FieldValue.serverTimestamp(),
};

Future<DocumentReference<Map<String, dynamic>>> schoolDocument(
  String collection,
  String id,
) async => (await schoolCollection(collection)).doc(id);
