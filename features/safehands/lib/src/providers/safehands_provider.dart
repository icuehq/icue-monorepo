import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:safehands/src/models/safehands_pin.dart';
import 'package:safehands/src/services/safehands_service.dart';

@lazySingleton
class SafeHandsProvider extends ChangeNotifier {
  SafeHandsProvider(this._service, this._auth) {
    _studentIdSeen = _auth.selectedStudent?.id;
    _auth.addListener(_onAuthChanged);
  }

  final SafeHandsService _service;
  final ParentAuthProvider _auth;

  SafeHandsPin? pin;
  bool loading = false;
  int? _studentIdSeen;

  void _onAuthChanged() {
    final id = _auth.selectedStudent?.id;
    if (id == _studentIdSeen) return;
    _studentIdSeen = id;
    pin = null;
    notifyListeners();
  }

  Future<void> _run(
    Future<SafeHandsPin?> Function(ParentStudent s) load,
  ) async {
    final student = _auth.selectedStudent;
    if (student == null) return;
    loading = true;
    notifyListeners();
    try {
      pin = await load(student);
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> load() => _run((s) => _service.getPin(s.id));

  Future<void> generate() => _run(
    (s) => _service.createPin(
      studentId: s.id,
      studentName: s.name,
      admissionNumber: s.admissionNumber,
    ),
  );

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
