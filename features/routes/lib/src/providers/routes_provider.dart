import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:routes/src/models/route_change_requests.dart';
import 'package:routes/src/models/routes.dart';
import 'package:routes/src/models/standards.dart';
import 'package:routes/src/models/student.dart';
import 'package:routes/src/services/route_service.dart';

@lazySingleton
class RoutesProvider extends ChangeNotifier {
  RoutesProvider(this._routeService);

  final RouteService _routeService;

  List<Routee> _routes = <Routee>[];
  List<Standards> _standards = <Standards>[];
  final List<StudentData> _students = <StudentData>[];
  Metadatum? _metadata;
  bool _hasNextPage = true;
  bool _isLoading = false;
  bool _studentsLoading = false;
  String? _errorMessage;

  List<Routee> get routes => List.unmodifiable(_routes);
  List<Standards> get standards => List.unmodifiable(_standards);
  List<StudentData> get students => List.unmodifiable(_students);
  bool get hasNextPage => _hasNextPage;
  bool get isLoading => _isLoading;
  bool get studentsLoading => _studentsLoading;
  String? get errorMessage => _errorMessage;

  /// Fetches routes and associated pickup/drop points.
  Future<void> fetchRoutes(RouteMode? mode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _routes = await _routeService.getRoutesAndPoints(mode);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches academic standards and sections.
  Future<void> fetchStandards() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _standards = await _routeService.getStandards();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches students for the given class and sections with pagination.
  Future<void> fetchStudents(
    int classId,
    List<String> sections, {
    int pageNo = 1,
  }) async {
    if (pageNo == 1) {
      _students.clear();
      _hasNextPage = true;
    }
    _studentsLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _routeService.getStudents(
        classId: classId,
        sections: sections,
        pageNo: pageNo,
      );
      _students.addAll(response.data);
      if (response.metadata.isNotEmpty) {
        _metadata = response.metadata.first;
        _hasNextPage = (_metadata?.total ?? 0) > _students.length;
      } else {
        _hasNextPage = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _studentsLoading = false;
      notifyListeners();
    }
  }

  /// Searches students by text query.
  Future<void> searchStudent(
    String query, {
    int? classId,
    List<String>? sections,
  }) async {
    if (query.trim().isEmpty) {
      _students.clear();
      notifyListeners();
      return;
    }

    _studentsLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _routeService.searchStudent(
        search: query.trim(),
        classId: classId,
        sections: sections,
      );
      _students.clear();
      _students.addAll(results);
      _hasNextPage = false;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _studentsLoading = false;
      notifyListeners();
    }
  }

  /// Updates single route for a student.
  Future<bool> changeRoute(ChangeRouteRequest request) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _routeService.changeStudentRoute(request);
      if (success) {
        await fetchStudents(request.classId, request.sections);
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates both pickup and drop routes for a student.
  Future<bool> changeBothRoutes(ChangeBothRoutesRequest request) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _routeService.changeBothRoutes(request);
      if (success) {
        await fetchStudents(request.classId, request.sections);
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates start time for routes.
  Future<bool> updateRouteTime(UpdateRouteTimeRequest request) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _routeService.updateStartTimeForRoutes(request);
      if (success) {
        await fetchRoutes(request.mode);
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears in-memory route selections.
  void clearData() {
    _routes = [];
    notifyListeners();
  }

  /// Clears student search/list results.
  void clearStudents() {
    _students.clear();
    _hasNextPage = true;
    notifyListeners();
  }
}
