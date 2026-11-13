import 'package:icue_firebase/icue_firebase.dart';

Future<DocumentReference<Map<String, dynamic>>> schoolDocument(
  String collection,
  String id,
) async => (await branchCollection(collection)).doc(id);
