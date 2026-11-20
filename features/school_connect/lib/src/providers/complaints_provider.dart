import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:school_connect/src/models/complaint.dart';
import 'package:school_connect/src/services/school_connect_service.dart';

@lazySingleton
class ComplaintsProvider extends ChangeNotifier {
  ComplaintsProvider(this._service, this._auth);

  final SchoolConnectService _service;
  final ParentAuthProvider _auth;

  List<ComplaintType> types = <ComplaintType>[];
  List<Complaint> complaints = <Complaint>[];
  bool loading = false;

  Future<void> loadTypes() async {
    final student = _auth.selectedStudent;
    if (student == null) return;
    loading = true;
    notifyListeners();
    try {
      types = await _service.getComplaintTypes(student.id);
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadComplaints() async {
    final student = _auth.selectedStudent;
    if (student == null) return;
    loading = true;
    notifyListeners();
    try {
      complaints = await _service.getComplaints(
        studentId: student.id,
        primaryContact: student.primaryContact,
      );
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Description of [type] for the history list; empty when unknown.
  String describe(int type) =>
      types.where((t) => t.type == type).firstOrNull?.description ?? '';

  /// Returns true when the server accepted the complaint.
  Future<bool> post({required int type, required String query}) async {
    final student = _auth.selectedStudent;
    if (student == null) return false;
    loading = true;
    notifyListeners();
    try {
      await _service.postComplaint(
        studentId: student.id,
        primaryContact: student.primaryContact,
        query: query,
        type: type,
        typeDescription: describe(type),
      );
      return true;
    } on ApiException {
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
