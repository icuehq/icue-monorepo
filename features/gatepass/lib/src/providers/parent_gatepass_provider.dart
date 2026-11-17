import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:gatepass/src/models/gatepass_type.dart';
import 'package:gatepass/src/models/parent_gatepass_request.dart';
import 'package:gatepass/src/services/parent_gatepass_service.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ParentGatePassProvider extends ChangeNotifier {
  ParentGatePassProvider(this._service, this._auth) {
    _studentIdSeen = _auth.selectedStudent?.id;
    _auth.addListener(_onAuthChanged);
  }

  final ParentGatePassService _service;
  final ParentAuthProvider _auth;

  List<GatePassType> types = <GatePassType>[];
  List<ParentGatePassRequest> requests = <ParentGatePassRequest>[];
  bool loading = false;
  bool requesting = false;

  int? _studentIdSeen;

  /// Types and requests belong to one student: drop them when it changes.
  void _onAuthChanged() {
    final id = _auth.selectedStudent?.id;
    if (id == _studentIdSeen) return;
    _studentIdSeen = id;
    reset();
  }

  int? get _studentId => _auth.selectedStudent?.id;

  Future<void> loadTypes() async {
    final id = _studentId;
    if (id == null || types.isNotEmpty) return;
    loading = true;
    notifyListeners();
    try {
      types = await _service.getTypes(id);
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadRequests({DateTime? from, DateTime? to}) async {
    final id = _studentId;
    if (id == null) return;
    loading = true;
    notifyListeners();
    try {
      requests = await _service.getRequests(studentId: id, from: from, to: to);
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Requests a pass for today. `ok` is false when the server refused (with
  /// its message) or the request failed (no message; ApiClient showed one).
  Future<({bool ok, String? message})> requestPass(String category) async {
    final id = _studentId;
    if (id == null) return (ok: false, message: null);
    requesting = true;
    notifyListeners();
    try {
      return await _service.request(
        studentId: id,
        category: category,
        today: DateTime.now().toIndianTime(),
      );
    } on ApiException {
      return (ok: false, message: null);
    } finally {
      requesting = false;
      notifyListeners();
    }
  }

  /// Drops cached data when the student changes.
  void reset() {
    types = <GatePassType>[];
    requests = <ParentGatePassRequest>[];
    notifyListeners();
  }
}
