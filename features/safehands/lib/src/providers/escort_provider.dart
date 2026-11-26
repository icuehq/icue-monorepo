import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:safehands/src/models/escort.dart';
import 'package:safehands/src/services/safehands_service.dart';

@lazySingleton
class EscortProvider extends ChangeNotifier {
  EscortProvider(this._service, this._auth);

  final SafeHandsService _service;
  final ParentAuthProvider _auth;

  List<Escort> escorts = <Escort>[];
  bool loading = false;

  Future<void> load() async {
    final student = _auth.selectedStudent;
    if (student == null) return;
    loading = true;
    notifyListeners();
    try {
      escorts = await _service.getEscorts(student.id);
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// `ok` when saved (the list is reloaded); otherwise the server's reason, if any.
  Future<({bool ok, String? message})> add({
    required String type,
    required String name,
    required String relation,
    required String mobile,
    required IcuePickedFile photo,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final student = _auth.selectedStudent;
    if (student == null) return (ok: false, message: null);
    loading = true;
    notifyListeners();
    try {
      final saved = await _service.saveEscort(
        studentId: student.id,
        studentMobile: student.primaryContact,
        type: type,
        name: name,
        relation: relation,
        escortMobile: mobile,
        photo: photo,
        fromDate: fromDate,
        toDate: toDate,
      );
      if (!saved.ok) {
        loading = false;
        notifyListeners();
        return saved;
      }
    } on ApiException {
      loading = false;
      notifyListeners();
      return (ok: false, message: null);
    }
    await load();
    return (ok: true, message: null);
  }

  Future<void> remove(int escortId) async {
    final student = _auth.selectedStudent;
    if (student == null) return;
    loading = true;
    notifyListeners();
    try {
      await _service.deleteEscort(studentId: student.id, escortId: escortId);
    } on ApiException {
      // Message already shown by ApiClient.
    }
    await load();
  }
}
