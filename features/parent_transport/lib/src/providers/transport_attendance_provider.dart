import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:parent_transport/src/models/transport_record.dart';
import 'package:parent_transport/src/services/parent_transport_service.dart';

@lazySingleton
class TransportAttendanceProvider extends ChangeNotifier {
  TransportAttendanceProvider(this._service, this._auth);

  final ParentTransportService _service;
  final ParentAuthProvider _auth;

  List<TransportRecord> records = <TransportRecord>[];
  bool loading = false;

  Future<void> load({DateTime? from, DateTime? to}) async {
    final id = _auth.selectedStudent?.id;
    if (id == null) return;
    loading = true;
    notifyListeners();
    try {
      records = await _service.getTransportRecords(
        studentId: id,
        from: from,
        to: to,
      );
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
