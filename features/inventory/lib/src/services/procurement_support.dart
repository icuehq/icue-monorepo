import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';

/// Helpers shared by the procurement write classes: failures, numbering, history entries,
/// and line checks.
mixin ProcurementSupport {
  Never failWith(String message) => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'failed-precondition',
    message: message,
  );

  String get currentUid => FirebaseAuth.instance.currentUser!.uid;

  String get todayDay => todayIST();

  Map<String, Object?> historyEntry(String action, [String? comment]) => {
    'action': action,
    'performedBy': currentUid,
    'performedAt': Timestamp.now(),
    'comment': comment,
  };

  String? blankToNullText(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<DocumentReference<Map<String, dynamic>>> branchReference(
    String collection,
    String id,
  ) async => (await branchCollection(collection)).doc(id);

  Future<
    ({
      DocumentReference<Map<String, dynamic>> reference,
      Map<String, dynamic> data,
    })
  >
  loadDocument(String collection, String id, String label) async {
    final reference = await branchReference(collection, id);
    final data = (await reference.get()).data();
    if (data == null) failWith('$label not found');
    return (reference: reference, data: data);
  }

  /// Next `TYPE/2026-27/000123`, from a counter document updated in a transaction.
  Future<String> nextNumber(String type) async {
    final financialYear = DateTime.now().toIndianTime().financialYear;
    final counter = await branchReference('counters', '${type}_$financialYear');
    final next = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      final current =
          ((await transaction.get(counter)).data()?['next'] as num?) ?? 0;
      final value = current.toInt() + 1;
      transaction.set(counter, {
        'next': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return value;
    });
    return '$type/$financialYear/${next.toString().padLeft(6, '0')}';
  }

  void requireUniqueLines(List<Map<String, dynamic>> lines) {
    final keys = {for (final line in lines) lineKey(line)};
    if (keys.length != lines.length) {
      failWith('Each item (and variant) may appear once');
    }
  }

  String lineKey(Map<String, dynamic> line) =>
      '${line['itemId']}__${line['variantId'] ?? '-'}';

  List<Map<String, dynamic>> asLines(Object? value) => [
    for (final line in (value! as List)) Map<String, dynamic>.from(line as Map),
  ];
}
