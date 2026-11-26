import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:parent_transport/src/models/student_vehicle.dart';
import 'package:parent_transport/src/services/parent_transport_service.dart';

/// Private vehicles a parent registered for the selected student.
@lazySingleton
class ParentVehiclesProvider extends ChangeNotifier {
  ParentVehiclesProvider(this._service, this._auth);

  final ParentTransportService _service;
  final ParentAuthProvider _auth;

  List<StudentVehicle> vehicles = <StudentVehicle>[];
  bool loading = false;

  StudentScope? get _scope {
    final s = _auth.selectedStudent;
    return s == null
        ? null
        : StudentScope(
            studentId: s.id,
            organizationId: s.organizationId,
            zoneId: s.zoneId,
            branchId: s.branchId,
          );
  }

  Future<void> load() async {
    final scope = _scope;
    if (scope == null) {
      vehicles = <StudentVehicle>[];
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      vehicles = await _service.getStudentVehicles(scope);
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Returns true when saved; the list is reloaded.
  Future<bool> add(String vehicleNumber) async {
    final scope = _scope;
    final student = _auth.selectedStudent;
    if (scope == null || student == null) return false;
    loading = true;
    notifyListeners();
    try {
      await _service.saveStudentVehicle(scope, vehicleNumber, <String>[
        ?student.primaryContact,
        ?student.secondaryContact,
      ]);
    } on ApiException {
      loading = false;
      notifyListeners();
      return false;
    }
    await load();
    return true;
  }

  Future<bool> remove(int vehicleId) async {
    final studentId = _auth.selectedStudent?.id;
    if (studentId == null) return false;
    loading = true;
    notifyListeners();
    try {
      await _service.deleteStudentVehicle(studentId, vehicleId);
    } on ApiException {
      loading = false;
      notifyListeners();
      return false;
    }
    await load();
    return true;
  }
}
