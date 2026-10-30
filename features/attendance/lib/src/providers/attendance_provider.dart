import 'dart:convert';
import 'package:attendance/src/models/create_attendance.dart';
import 'package:attendance/src/models/create_attendance_response.dart';
import 'package:attendance/src/services/attendance_service.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:local_storage/local_storage.dart';

@injectable
class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(
    this._attendanceService,
    this._storageService,
  );

  final AttendanceService _attendanceService;
  final StorageService _storageService;

  bool _isLoading = false;
  String? _errorMessage;
  CreateAttendance? _ongoingAttendance;
  String? _ongoingAttendanceKey;
  final Map<int, List<double>> _studentEmbeddings = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CreateAttendance? get ongoingAttendance => _ongoingAttendance;
  String? get ongoingAttendanceKey => _ongoingAttendanceKey;
  Map<int, List<double>> get studentEmbeddings =>
      Map.unmodifiable(_studentEmbeddings);

  String? get effectiveAttendanceKey {
    if (_ongoingAttendanceKey != null &&
        _storageService.containsKey(
          StorageConstants.createAttendanceBox,
          _ongoingAttendanceKey,
        )) {
      return _ongoingAttendanceKey;
    }

    if (_storageService.isBoxOpen(StorageConstants.createAttendanceBox)) {
      final box =
          _storageService.getBox<String>(StorageConstants.createAttendanceBox);
      if (box.keys.isNotEmpty) {
        final key = box.keys.first.toString();
        _ongoingAttendanceKey = key;
        return key;
      }
    }
    return null;
  }

  /// Standardized key format: yyyy-MM-dd-$classId-$section-$period
  String generateAttendanceKey({
    required int classId,
    required String section,
    String? period,
  }) {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final activePeriod = (period == null || period.isEmpty) ? '1' : period;
    return '$dateStr-$classId-$section-$activePeriod';
  }

  /// Restores any previously saved in-progress attendance session from storage.
  Future<CreateAttendance?> getOngoingAttendance() async {
    try {
      if (!_storageService.isBoxOpen(StorageConstants.createAttendanceBox)) {
        await _storageService.openBox<String>(
          StorageConstants.createAttendanceBox,
        );
      }

      final key = effectiveAttendanceKey;
      if (key != null) {
        final raw = _storageService.get<String>(
          StorageConstants.createAttendanceBox,
          key,
        );
        if (raw != null && raw.isNotEmpty) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _ongoingAttendance = CreateAttendance.fromJson(map);
          _ongoingAttendanceKey = key;
          notifyListeners();
          return _ongoingAttendance;
        }
      }

      _ongoingAttendanceKey = null;
      _ongoingAttendance = null;
      return null;
    } catch (e) {
      debugPrint('[AttendanceProvider] getOngoingAttendance error: $e');
      return null;
    } finally {
      notifyListeners();
    }
  }

  /// Deletes and discards the active ongoing attendance session.
  Future<void> deleteOngoingAttendance() async {
    try {
      final key = effectiveAttendanceKey;
      if (key != null) {
        await _storageService.delete(
          StorageConstants.createAttendanceBox,
          key,
        );
      }
      _ongoingAttendanceKey = null;
      _ongoingAttendance = null;
    } catch (e) {
      debugPrint('[AttendanceProvider] deleteOngoingAttendance error: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Saves or updates single student status in local storage.
  Future<void> updateAttendance({
    required int classId,
    required String className,
    required String section,
    required String period,
    required AttendanceStudent student,
  }) async {
    try {
      if (!_storageService.isBoxOpen(StorageConstants.createAttendanceBox)) {
        await _storageService.openBox<String>(
          StorageConstants.createAttendanceBox,
        );
      }

      final key = generateAttendanceKey(
        classId: classId,
        section: section,
        period: period,
      );
      _ongoingAttendanceKey = key;

      final activePeriod = period.isEmpty ? '1' : period;
      final raw = _storageService.get<String>(
        StorageConstants.createAttendanceBox,
        key,
      );

      CreateAttendance attendance;
      if (raw == null || raw.isEmpty) {
        attendance = CreateAttendance(
          source: 'adminapp',
          students: [student],
          classId: classId,
          section: section,
          standard: className,
          attendanceDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
          attendanceTime: DateFormat('hh:mm a').format(DateTime.now()),
          month: DateTime.now().month,
          year: DateTime.now().year,
          period: activePeriod,
          attendanceMode: student.attendanceMode,
        );
      } else {
        final existing =
            CreateAttendance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        final updatedStudents =
            List<AttendanceStudent>.from(existing.students);
        final index = updatedStudents.indexWhere((e) => e.id == student.id);
        if (index != -1) {
          updatedStudents[index] = student;
        } else {
          updatedStudents.add(student);
        }

        attendance = existing.copyWith(
          students: updatedStudents,
          attendanceMode: existing.attendanceMode ?? student.attendanceMode,
        );
      }

      await _storageService.put(
        StorageConstants.createAttendanceBox,
        key,
        jsonEncode(attendance.toJson()),
      );
      _ongoingAttendance = attendance;
    } catch (e) {
      debugPrint('[AttendanceProvider] updateAttendance error: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Saves or updates bulk student roster into local session storage.
  Future<void> updateAttendanceBulk({
    required int classId,
    required String className,
    required String section,
    required String period,
    required List<AttendanceStudent> students,
    String? attendanceMode,
    List<String>? images,
  }) async {
    try {
      if (!_storageService.isBoxOpen(StorageConstants.createAttendanceBox)) {
        await _storageService.openBox<String>(
          StorageConstants.createAttendanceBox,
        );
      }

      final key = generateAttendanceKey(
        classId: classId,
        section: section,
        period: period,
      );
      _ongoingAttendanceKey = key;

      final activePeriod = period.isEmpty ? '1' : period;
      final raw = _storageService.get<String>(
        StorageConstants.createAttendanceBox,
        key,
      );

      CreateAttendance attendance;
      if (raw == null || raw.isEmpty) {
        attendance = CreateAttendance(
          source: 'adminapp',
          students: students,
          classId: classId,
          section: section,
          standard: className,
          attendanceDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
          attendanceTime: DateFormat('hh:mm a').format(DateTime.now()),
          month: DateTime.now().month,
          year: DateTime.now().year,
          period: activePeriod,
          attendanceMode: attendanceMode ??
              (students.isNotEmpty ? students.first.attendanceMode : null),
          images: images,
        );
      } else {
        final existing =
            CreateAttendance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        final studentMap = {for (final s in existing.students) s.id: s};
        for (final s in students) {
          studentMap[s.id] = s;
        }
        final combinedImages = images != null
            ? {...?existing.images, ...images}.toList()
            : existing.images;

        attendance = existing.copyWith(
          students: studentMap.values.toList(),
          attendanceMode: attendanceMode ?? existing.attendanceMode,
          images: combinedImages,
        );
      }

      await _storageService.put(
        StorageConstants.createAttendanceBox,
        key,
        jsonEncode(attendance.toJson()),
      );
      _ongoingAttendance = attendance;
    } catch (e) {
      debugPrint('[AttendanceProvider] updateAttendanceBulk error: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Toggles attendance presence flag for a student in the active session.
  Future<void> toggleStudentAttendance(AttendanceStudent student) async {
    try {
      final key = effectiveAttendanceKey;
      if (key == null) return;

      final raw = _storageService.get<String>(
        StorageConstants.createAttendanceBox,
        key,
      );
      if (raw == null || raw.isEmpty) return;

      final attendance =
          CreateAttendance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final updatedStudents =
          List<AttendanceStudent>.from(attendance.students);
      final index = updatedStudents.indexWhere((e) => e.id == student.id);
      if (index != -1) {
        updatedStudents[index] = student.copyWith(
          isPresent: !student.isPresent,
        );
        final updated = attendance.copyWith(students: updatedStudents);
        await _storageService.put(
          StorageConstants.createAttendanceBox,
          key,
          jsonEncode(updated.toJson()),
        );
        _ongoingAttendance = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AttendanceProvider] toggleStudentAttendance error: $e');
    }
  }

  /// Checks if attendance exists on the backend for a given section.
  Future<bool> checkAttendanceExists({
    required int classId,
    required String section,
    required String date,
    required String period,
  }) async {
    return _attendanceService.checkAttendanceExists(
      classId: classId,
      section: section,
      date: date,
      period: period,
    );
  }

  /// Fetches registered MobileFaceNet embeddings for a list of student IDs.
  Future<void> fetchStudentEmbeddings({
    required int organizationId,
    required int zoneId,
    required int branchId,
    required List<int> studentIds,
  }) async {
    if (studentIds.isEmpty) return;
    try {
      final embeddings = await _attendanceService.getStudentEmbeddings(
        organizationId: organizationId,
        zoneId: zoneId,
        branchId: branchId,
        studentIds: studentIds,
      );
      _studentEmbeddings.addAll(embeddings);
      notifyListeners();
    } catch (e) {
      debugPrint('[AttendanceProvider] fetchStudentEmbeddings error: $e');
    }
  }

  /// Submits the currently active attendance session to the backend and uploads photos if present.
  Future<CreateAttendanceResponse?> submitActiveAttendance() async {
    final key = effectiveAttendanceKey;
    if (key == null) return null;

    final raw = _storageService.get<String>(
      StorageConstants.createAttendanceBox,
      key,
    );
    if (raw == null || raw.isEmpty) return null;

    final attendance =
        CreateAttendance.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response =
          await _attendanceService.createAttendance(attendance);

      if (!response.err) {
        // Upload images if any
        if (response.id != null &&
            attendance.images != null &&
            attendance.images!.isNotEmpty) {
          await _attendanceService.uploadAttendanceImages(
            attendanceId: response.id!,
            imagePaths: attendance.images!,
          );
        }

        // Clean up session in local storage
        await deleteOngoingAttendance();
        return response;
      } else {
        _errorMessage = response.message;
        return response;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return CreateAttendanceResponse(
        err: true,
        message: e.toString(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
