import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:students/src/models/parent_role_action.dart';
import 'package:students/src/models/student_route_details.dart';
import 'package:students/src/services/students_service.dart';

/// Per-student data of the parent app: home menu actions, transport route
/// details and link URLs. The student list and selection live in
/// [ParentAuthProvider].
@lazySingleton
class ParentStudentsProvider extends ChangeNotifier {
  ParentStudentsProvider(this._service, this._auth);

  final StudentsService _service;
  final ParentAuthProvider _auth;

  List<ParentRoleAction> roleActions = <ParentRoleAction>[];
  final Map<int, StudentRouteDetails> routeDetails =
      <int, StudentRouteDetails>{};
  bool actionsLoading = false;
  bool routeLoading = false;

  /// Loads the home menu for [studentId] (default: the selected student).
  /// Returns false when the request failed.
  Future<bool> loadRoleActions([int? studentId]) async {
    final id = studentId ?? _auth.selectedStudent?.id;
    if (id == null) return false;
    actionsLoading = true;
    notifyListeners();
    try {
      roleActions = await _service.getRoleActions(id);
      return true;
    } on ApiException {
      return false;
    } finally {
      actionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRouteDetails(int studentId) async {
    if (routeDetails.containsKey(studentId)) return;
    routeLoading = true;
    notifyListeners();
    try {
      routeDetails[studentId] = await _service.getRouteDetails(studentId);
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      routeLoading = false;
      notifyListeners();
    }
  }

  Future<String?> linkUrl(String linkType) async {
    final id = _auth.selectedStudent?.id;
    if (id == null) return null;
    try {
      return await _service.getLinkUrl(id, linkType);
    } on ApiException {
      return null;
    }
  }

  /// Drops everything cached for the previous student.
  void reset() {
    roleActions = <ParentRoleAction>[];
    routeDetails.clear();
    notifyListeners();
  }
}
