import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

import '../models/exam_marks.dart';
import '../models/exam_results.dart';
import '../models/exam_schedule.dart';
import '../models/marks.dart';
import '../models/marks_correction.dart';
import '../models/prep_exam.dart';
import '../services/api_client.dart';
import '../services/hive_service.dart';
import '../utils/app_utils.dart';

@lazySingleton
class ExamProvider extends ChangeNotifier {
  ExamProvider(this._apiClient);

  bool loading = false;

  List<PrepExam> prepExams = [];
  List<ExamResult> results = [];
  bool saving = false;
  List<ExamSchedule> schedules = [];
  ExamSchedule? selectedSchedule;
  List<ExamStudent> students = [];
  List<MarksCorrectionItem> marksCorrectionRequests = [];
  bool loadingMarksCorrections = false;

  static final _dateFormat = DateFormat('M/d/yyyy');

  static final _timeFormat = DateFormat('h:mm:ss a');

  final ApiClient _apiClient;
  final Map<int, int> _studentIndexMap = {};

  int get totalStudentsCount => students.length;

  int get presentStudentsCount =>
      students.where((s) => s.status == 'PRESENT' && s.marks != null).length;

  int get absentStudentsCount =>
      students.where((s) => s.status == 'ABSENT').length;

  int get naStudentsCount => students.where((s) => s.status == 'NA').length;

  int get unsavedStudentsCount => students.where((s) => !s.isSaved).length;

  ExamStudent? getStudentById(int studentId) {
    final index = _studentIndexMap[studentId];
    if (index != null && index >= 0 && index < students.length) {
      return students[index];
    }
    return null;
  }

  void reset() {
    loading = false;
    saving = false;
    prepExams = [];
    results = [];
    schedules = [];
    selectedSchedule = null;
    students = [];
    _studentIndexMap.clear();
    marksCorrectionRequests = [];
    loadingMarksCorrections = false;
    notifyListeners();
  }

  void clearMarksCorrectionRequests() {
    marksCorrectionRequests = [];
    notifyListeners();
  }

  void clearStudents() {
    students = [];
    _studentIndexMap.clear();
    notifyListeners();
  }

  void clearResults() {
    results = [];
    notifyListeners();
  }

  void clearSchedules() {
    schedules = [];
    selectedSchedule = null;
    notifyListeners();
  }

  void setSelectedSchedule(ExamSchedule? schedule) {
    if (selectedSchedule == schedule) return;
    selectedSchedule = schedule;
    notifyListeners();
  }

  // --- Prep Exams ---
  Future<void> getPrepExams(String academicYear) async {
    try {
      final response = await _apiClient.post(
        '/v1.0/getPrepExams',
        data: {'AcademicYear': academicYear},
      );

      final rawList = _extractList(response.data) ?? [];
      prepExams = rawList
          .whereType<Map>()
          .map((m) => PrepExam.fromJson(Map<String, dynamic>.from(m)))
          .where((e) => e.status != 'Inactive')
          .toList();
    } catch (error, stack) {
      prepExams = [];
      _logError('/getPrepExams', error, stack);
    } finally {
      notifyListeners();
    }
  }

  // --- Student Marks & Status (O(1) Lookups & Change Guards) ---
  void updateStudentMark(int studentId, num? marks) {
    final index =
        _studentIndexMap[studentId] ??
        students.indexWhere((s) => s.studentId == studentId);
    if (index != -1 && index < students.length) {
      final student = students[index];
      final newStatus = marks != null ? 'PRESENT' : student.status;
      // Guard against redundant notification if no actual change
      if (student.marks == marks && student.status == newStatus) {
        return;
      }
      student.marks = marks;
      if (marks != null) {
        student.status = 'PRESENT';
      }
      student.isSaved = false;
      notifyListeners();
    }
  }

  void updateStudentStatus(int studentId, String status) {
    final index =
        _studentIndexMap[studentId] ??
        students.indexWhere((s) => s.studentId == studentId);
    if (index != -1 && index < students.length) {
      final student = students[index];
      final willClearMarks = status == 'ABSENT' || status == 'NA';
      // Guard against redundant notification if no actual change
      if (student.status == status &&
          (!willClearMarks || student.marks == null)) {
        return;
      }
      student.status = status;
      if (willClearMarks) {
        student.marks = null;
      }
      student.isSaved = false;
      notifyListeners();
    }
  }

  void updateStudentRemarks(int studentId, String remarks) {
    final index =
        _studentIndexMap[studentId] ??
        students.indexWhere((s) => s.studentId == studentId);
    if (index != -1 && index < students.length) {
      final student = students[index];
      // Guard against redundant notification if no actual change
      if (student.remarks == remarks) {
        return;
      }
      student.remarks = remarks;
      student.isSaved = false;
      notifyListeners();
    }
  }

  // 1. Create Exam Schedule
  Future<bool> createExamSchedule(
    BuildContext? context, {
    required String academicYear,
    required String examName,
    required int classId,
    required String section,
    required int subjectId,
    required String subject,
    required String examType,
    required String examDate,
    required num maximumMarks,
    required num passingMarks,
  }) async {
    return _runWithDialog<bool>(
      context: context,
      message: 'Creating exam schedule...',
      action: () async {
        try {
          final user = HiveService.userInfoBox.values.firstOrNull;
          final payload = {
            'AcademicYear': academicYear,
            'ExamName': examName,
            'ClassId': classId,
            'Section': section,
            'SubjectId': subjectId,
            'Subject': subject,
            'ExamType': examType,
            'ExamDate': examDate,
            'MaximumMarks': maximumMarks,
            'PassingMarks': passingMarks,
            'OrganizationId': user?.organizationId,
            'ZoneId': user?.zoneId,
            'BranchId': user?.branchId,
          };

          final response = await _apiClient.post(
            '/v1.0/createExamSchedule',
            data: payload,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            if (context != null && context.mounted) {
              AppUtils.showSucessMessage(
                context,
                'Exam schedule created successfully',
              );
            }
            await getExamSchedules(
              academicYear: academicYear,
              classId: classId,
              section: section,
              examName: examName,
            );
            return true;
          }
          return false;
        } catch (error, stack) {
          _logError('/createExamSchedule', error, stack);
          return false;
        }
      },
    );
  }

  // 2. List Exam Schedules
  Future<void> getExamSchedules({
    required String academicYear,
    required String examName,
    required int classId,
    required String section,
  }) async {
    loading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/v1.0/getExamSchedules',
        data: {
          'AcademicYear': academicYear,
          'ExamName': examName,
          'ClassId': classId,
          'Section': section,
        },
      );

      final rawList = _extractList(response.data) ?? [];
      schedules = rawList
          .whereType<Map>()
          .map((m) => ExamSchedule.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (error, stack) {
      schedules = [];
      _logError('/getExamSchedules', error, stack);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // 3. Publish Exam Schedule
  Future<bool> publishExamSchedule(BuildContext? context, int examId) async {
    return _runWithDialog<bool>(
      context: context,
      message: 'Publishing exam schedule...',
      action: () async {
        try {
          final response = await _apiClient.post(
            '/v1.0/publishExamSchedule',
            data: {'Id': examId},
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            if (context != null && context.mounted) {
              AppUtils.showSucessMessage(
                context,
                'Exam schedule published successfully',
              );
            }
            final index = schedules.indexWhere((s) => s.id == examId);
            if (index != -1) {
              schedules[index] = schedules[index].copyWith(
                isPublished: true,
                status: 'PUBLISHED',
              );
              if (selectedSchedule != null && selectedSchedule!.id == examId) {
                selectedSchedule = schedules[index];
              }
              notifyListeners();
            }
            return true;
          }
          return false;
        } catch (error, stack) {
          _logError('/publishExamSchedule', error, stack);
          return false;
        }
      },
    );
  }

  // 4. Update Exam Schedule
  Future<bool> updateExamSchedule(
    BuildContext? context, {
    required int id,
    required String academicYear,
    required String examName,
    required int classId,
    required String section,
    required int subjectId,
    required String subject,
    required String examType,
    required String examDate,
    required num maximumMarks,
    required num passingMarks,
  }) async {
    return _runWithDialog<bool>(
      context: context,
      message: 'Updating exam schedule...',
      action: () async {
        try {
          final payload = {
            'Id': id,
            'AcademicYear': academicYear,
            'ExamName': examName,
            'ClassId': classId,
            'Section': section,
            'SubjectId': subjectId,
            'Subject': subject,
            'ExamType': examType,
            'ExamDate': examDate,
            'MaximumMarks': maximumMarks,
            'PassingMarks': passingMarks,
          };

          final response = await _apiClient.post(
            '/v1.0/updateExamSchedule',
            data: payload,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            if (context != null && context.mounted) {
              AppUtils.showSucessMessage(
                context,
                'Exam schedule updated successfully',
              );
            }
            await getExamSchedules(
              academicYear: academicYear,
              classId: classId,
              section: section,
              examName: examName,
            );
            return true;
          }
          return false;
        } catch (error, stack) {
          _logError('/updateExamSchedule', error, stack);
          return false;
        }
      },
    );
  }

  // 5. Delete Exam Schedules
  Future<bool> deleteExamSchedules(
    BuildContext? context,
    List<int> examIds,
  ) async {
    return _runWithDialog<bool>(
      context: context,
      message: 'Deleting exam schedule(s)...',
      action: () async {
        try {
          final response = await _apiClient.post(
            '/v1.0/deleteExamSchedules',
            data: {'Ids': examIds},
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            if (context != null && context.mounted) {
              AppUtils.showSucessMessage(
                context,
                'Exam schedule(s) deleted successfully',
              );
            }
            final idSet = examIds.toSet();
            schedules.removeWhere((s) => idSet.contains(s.id));
            if (selectedSchedule != null &&
                idSet.contains(selectedSchedule!.id)) {
              selectedSchedule = null;
            }
            notifyListeners();
            return true;
          }
          return false;
        } catch (error, stack) {
          _logError('/deleteExamSchedules', error, stack);
          return false;
        }
      },
    );
  }

  // 6. Load Students for Exam
  Future<void> getExamStudents({
    required int examId,
    required String academicYear,
    required int classId,
    required String section,
  }) async {
    loading = true;
    students = [];
    _studentIndexMap.clear();
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/v1.0/getExamStudents',
        data: {
          'ExamId': examId,
          'AcademicYear': academicYear,
          'ClassId': classId,
          'Section': section,
        },
      );

      final rawList = _extractList(response.data) ?? [];
      students = rawList
          .whereType<Map>()
          .map((m) => ExamStudent.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      _rebuildStudentIndex();

      // Fetch saved marks silently to avoid intermediate UI flicker before loading completes
      await getExamMarks(examId: examId, notify: false);

      // Silently fetch any pending marks correction requests to identify blocked students
      try {
        final pendingCorrections = await getMarksCorrectionRequests(
          examId: examId,
        );
        for (final req in pendingCorrections) {
          final s = getStudentById(req.studentId);
          if (s != null) {
            s.isCorrectionPending = true;
            s.correction = req.correction;
          }
        }
      } catch (_) {
        // Silently ignore if getMarksCorrectionRequests fails during initial student load
      }
    } catch (error, stack) {
      students = [];
      _studentIndexMap.clear();
      _logError('/getExamStudents', error, stack);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // 7. Save Marks (with Absent & NA support, and remarks)
  Future<bool> saveExamMarks(
    BuildContext? context, {
    required int examId,
    required List<ExamStudent> studentList,
    bool showLoading = true,
  }) async {
    saving = true;
    notifyListeners();

    final showDialog = showLoading && context != null && context.mounted;
    if (showDialog) {
      AppUtils.showLoadingDialog(context, 'Saving marks... Please wait...');
    }

    try {
      final marksData = studentList.map((s) {
        final entry = <String, dynamic>{'StudentId': s.studentId};
        final upperStatus = s.status.trim().toUpperCase();
        if (upperStatus == 'ABSENT' || upperStatus == 'NA') {
          entry['Status'] = upperStatus;
        } else {
          entry['Marks'] = s.marks ?? 0;
          entry['Status'] = '';
        }
        entry['Remarks'] = s.remarks?.trim() ?? '';
        return entry;
      }).toList();

      final now = DateTime.now();
      final initiatedDate = _dateFormat.format(now);
      final initiatedTime = _timeFormat.format(now);

      final response = await _apiClient.post(
        '/v1.0/saveExamMarks',
        data: {
          'ExamId': examId,
          'Marks': marksData,
          'InitiatedDate': initiatedDate,
          'InitiatedTime': initiatedTime,
        },
      );

      final dynamic responseData =
          response.data is Map && response.data['data'] != null
          ? response.data['data']
          : response.data;

      final isSavedSuccess =
          (response.statusCode == 200 || response.statusCode == 201) &&
          (responseData is Map
              ? (responseData['saved'] == 1 ||
                    responseData['saved'] == true ||
                    responseData['saved'] == '1' ||
                    responseData['success'] == true ||
                    responseData['status'] == 200 ||
                    responseData['status'] == 'success')
              : true);

      if (isSavedSuccess) {
        for (final s in studentList) {
          s.isSaved = true;
          s.hasExistingMarks = true;
        }
        if (context != null && context.mounted) {
          AppUtils.showSucessMessage(
            context,
            studentList.length == 1
                ? 'Marks saved for ${studentList.first.name}'
                : 'Marks saved successfully',
          );
        }
        return true;
      } else {
        final msg = (responseData is Map && responseData['message'] != null)
            ? responseData['message'].toString()
            : 'Failed to save marks';
        if (context != null && context.mounted) {
          AppUtils.showErrorMessage(context, msg);
        }
        return false;
      }
    } catch (error, stack) {
      _logError('/saveExamMarks', error, stack);
      return false;
    } finally {
      if (showDialog && context.mounted) {
        AppUtils.hideLoadingDialog(context);
      }
      saving = false;
      notifyListeners();
    }
  }

  // 8. Read Saved Marks (O(1) lookups and optional notify flag)
  Future<void> getExamMarks({required int examId, bool notify = true}) async {
    try {
      final response = await _apiClient.post(
        '/v1.0/getExamMarks',
        data: {'ExamId': examId},
      );

      final rawList = _extractList(response.data);
      if (rawList == null) return;

      final data = rawList.whereType<Map>().map(
        (m) => ExamMarks.fromJson(Map<String, dynamic>.from(m)),
      );

      bool changed = false;
      for (final item in data) {
        final studentId = item.studentId;
        if (studentId == null) continue;

        final studentIndex =
            _studentIndexMap[studentId] ??
            students.indexWhere((s) => s.studentId == studentId);
        if (studentIndex != -1 && studentIndex < students.length) {
          final s = students[studentIndex];
          s.marks = item.marks;
          if (item.status != null) {
            final statusStr = item.status.toString().trim().toUpperCase();
            s.status = (statusStr == 'ABSENT' || statusStr == 'NA')
                ? statusStr
                : 'PRESENT';
          }
          if (item.remarks != null) {
            s.remarks = item.remarks;
          }
          s.isSaved = true;
          s.hasExistingMarks = true;
          if (item.correction != null) {
            s.correction = item.correction;
            s.isCorrectionPending =
                item.correction?.status?.trim().toLowerCase() == 'pending';
          }
          changed = true;
        }
      }
      if (changed && notify) {
        notifyListeners();
      }
    } catch (error, stack) {
      _logError('/getExamMarks', error, stack);
    }
  }

  // 9. Get Class Results
  Future<List<ExamResult>> getExamResults({
    required String academicYear,
    required int classId,
    required String section,
    String? examName,
  }) async {
    loading = true;
    results = [];
    notifyListeners();
    try {
      final now = DateTime.now();
      final dateStr = _dateFormat.format(now);
      final timeStr = _timeFormat.format(now);

      final payload = <String, dynamic>{
        'AcademicYear': academicYear,
        'ClassId': classId,
        'Section': section,
        'Source': 'app',
        'AppName': 'IcueAdmin',
        'source': 'App',
        'InitiatedDate': dateStr,
        'InitiatedTime': timeStr,
      };
      if (examName != null && examName.isNotEmpty && examName != 'All exams') {
        payload['ExamName'] = examName;
      }

      final response = await _apiClient.post(
        '/v1.0/getExamResults',
        data: payload,
      );

      final rawList = _extractList(response.data) ?? [];
      final parsedResults = rawList
          .whereType<Map>()
          .map((m) => ExamResult.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      _computeRanksIfMissing(parsedResults);
      results = parsedResults;
      return results;
    } catch (error, stack) {
      results = [];
      _logError('/getExamResults', error, stack);
      return [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // 10. Request Marks Correction
  Future<RequestMarksCorrectionResponse> requestMarksCorrection({
    BuildContext? context,
    required int examId,
    required int studentId,
    num? newMarks,
    String? newStatus,
    String? reason,
    bool showLoading = true,
  }) async {
    final showDialog = showLoading && context != null && context.mounted;
    if (showDialog) {
      AppUtils.showLoadingDialog(
        context,
        'Submitting marks correction request...',
      );
    }

    try {
      final payload = <String, dynamic>{
        'ExamId': examId,
        'StudentId': studentId,
        'NewMarks': newMarks,
        'NewStatus': newStatus ?? '',
        'Reason': reason ?? '',
      };

      final response = await _apiClient.post(
        '/v1.0/requestMarksCorrection',
        data: payload,
      );

      final dynamic responseData = response.data is Map ? response.data : {};
      final result = RequestMarksCorrectionResponse.fromJson(
        Map<String, dynamic>.from(responseData as Map),
      );

      if (result.success && !result.err) {
        final studentIndex =
            _studentIndexMap[studentId] ??
            students.indexWhere((s) => s.studentId == studentId);
        if (studentIndex != -1 && studentIndex < students.length) {
          final student = students[studentIndex];
          student.isCorrectionPending = true;
          student.correction = Correction(
            status: result.correctionStatus ?? 'Pending',
            statusAt: result.correctionStatusAt,
            marks: result.requestedMarks,
            markStatus: result.requestedStatus,
            reason: reason,
          );
          notifyListeners();
        }
        if (context != null && context.mounted) {
          AppUtils.showSucessMessage(
            context,
            result.message.isNotEmpty
                ? result.message
                : 'Marks correction request submitted successfully for Principal approval',
          );
        }
      } else {
        if (result.err &&
            result.message.toLowerCase().contains('already pending')) {
          final studentIndex =
              _studentIndexMap[studentId] ??
              students.indexWhere((s) => s.studentId == studentId);
          if (studentIndex != -1 && studentIndex < students.length) {
            students[studentIndex].isCorrectionPending = true;
            notifyListeners();
          }
        }
        final errorMsg = result.message.isNotEmpty
            ? result.message
            : 'Failed to submit marks correction request';
        if (context != null && context.mounted) {
          AppUtils.showErrorMessage(context, errorMsg);
        }
      }

      return result;
    } catch (error, stack) {
      _logError('/requestMarksCorrection', error, stack);
      String errorMsg = 'Failed to submit marks correction request';
      if (error is DioException) {
        final data = error.response?.data;
        if (data is Map && data['message'] != null) {
          errorMsg = data['message'].toString();
        } else if (data is String && data.isNotEmpty) {
          errorMsg = data;
        }
      }
      return RequestMarksCorrectionResponse.error(errorMsg);
    } finally {
      if (showDialog && context.mounted) {
        AppUtils.hideLoadingDialog(context);
      }
    }
  }

  // 11. Get Marks Correction Requests
  Future<List<MarksCorrectionItem>> getMarksCorrectionRequests({
    String? correctionStatus = 'Pending',
    int? examId,
  }) async {
    loadingMarksCorrections = true;
    marksCorrectionRequests = [];
    notifyListeners();

    try {
      final payload = <String, dynamic>{};
      if (correctionStatus != null && correctionStatus.isNotEmpty) {
        payload['CorrectionStatus'] = correctionStatus;
      }
      if (examId != null) {
        payload['ExamId'] = examId;
      }

      final response = await _apiClient.post(
        '/v1.0/getMarksCorrectionRequests',
        data: payload,
      );

      final dynamic responseData = response.data;
      if (responseData is Map) {
        final parsed = GetMarksCorrectionRequestsResponse.fromJson(
          Map<String, dynamic>.from(responseData),
        );
        marksCorrectionRequests = parsed.data;
      } else if (responseData is List) {
        marksCorrectionRequests = responseData
            .whereType<Map>()
            .map(
              (m) => MarksCorrectionItem.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList();
      }
      return marksCorrectionRequests;
    } catch (error, stack) {
      marksCorrectionRequests = [];
      _logError('/getMarksCorrectionRequests', error, stack);
      return [];
    } finally {
      loadingMarksCorrections = false;
      notifyListeners();
    }
  }

  // 12. Approve or Reject Marks Correction
  Future<ApproveMarksCorrectionResponse> approveMarksCorrection({
    BuildContext? context,
    required int examId,
    required int studentId,
    required String decision,
    String? remarks,
    bool showLoading = true,
  }) async {
    final showDialog = showLoading && context != null && context.mounted;
    if (showDialog) {
      AppUtils.showLoadingDialog(
        context,
        decision.toLowerCase() == 'approved'
            ? 'Approving marks correction...'
            : 'Rejecting marks correction...',
      );
    }

    try {
      final payload = <String, dynamic>{
        'ExamId': examId,
        'StudentId': studentId,
        'Decision': decision,
        'Remarks': remarks ?? '',
      };

      final response = await _apiClient.post(
        '/v1.0/approveMarksCorrection',
        data: payload,
      );

      final dynamic responseData = response.data is Map ? response.data : {};
      final result = ApproveMarksCorrectionResponse.fromJson(
        Map<String, dynamic>.from(responseData as Map),
      );

      if (result.success && !result.err) {
        if (context != null && context.mounted) {
          AppUtils.showSucessMessage(
            context,
            result.message.isNotEmpty
                ? result.message
                : 'Marks correction request $decision successfully',
          );
        }

        // Update local student mark & status if student is currently loaded
        final studentIndex =
            _studentIndexMap[studentId] ??
            students.indexWhere((s) => s.studentId == studentId);
        if (studentIndex != -1 && studentIndex < students.length) {
          final student = students[studentIndex];
          if (decision.toLowerCase() == 'approved') {
            if (result.marks != null) {
              student.marks = result.marks;
            }
            if (result.status != null && result.status!.isNotEmpty) {
              student.status = result.status!;
            }
            student.isSaved = true;
          }
        }

        // Update in marksCorrectionRequests list
        marksCorrectionRequests.removeWhere(
          (item) => item.examId == examId && item.studentId == studentId,
        );
        notifyListeners();
      } else {
        final errorMsg = result.message.isNotEmpty
            ? result.message
            : 'Failed to process marks correction request';
        if (context != null && context.mounted) {
          AppUtils.showErrorMessage(context, errorMsg);
        }
      }

      return result;
    } catch (error, stack) {
      _logError('/approveMarksCorrection', error, stack);
      String errorMsg = 'Failed to process marks correction request';
      if (error is DioException) {
        final data = error.response?.data;
        if (data is Map && data['message'] != null) {
          errorMsg = data['message'].toString();
        } else if (data is String && data.isNotEmpty) {
          errorMsg = data;
        }
      }
      return ApproveMarksCorrectionResponse.error(errorMsg);
    } finally {
      if (showDialog && context.mounted) {
        AppUtils.hideLoadingDialog(context);
      }
    }
  }

  void _computeRanksIfMissing(List<ExamResult> list) {
    if (list.isEmpty) return;
    if (list.any((r) => r.rank != null && r.rank! > 0)) return;

    final rankable =
        list
            .where(
              (r) =>
                  (r.percentage != null || r.totalMarks != null) &&
                  r.result?.trim().toUpperCase() != 'N/A',
            )
            .toList()
          ..sort(
            (a, b) => (b.percentage ?? b.totalMarks ?? 0).compareTo(
              a.percentage ?? a.totalMarks ?? 0,
            ),
          );

    int currentRank = 1;
    for (int i = 0; i < rankable.length; i++) {
      if (i > 0) {
        final prev = rankable[i - 1];
        final curr = rankable[i];
        final prevVal = prev.percentage ?? prev.totalMarks ?? 0;
        final currVal = curr.percentage ?? curr.totalMarks ?? 0;
        if (currVal < prevVal) {
          currentRank = i + 1;
        }
      }
      rankable[i].rank = currentRank;
    }
  }

  void _rebuildStudentIndex() {
    _studentIndexMap.clear();
    for (var i = 0; i < students.length; i++) {
      _studentIndexMap[students[i].studentId] = i;
    }
  }

  // --- Safe Helpers ---
  void _logError(String endpoint, Object error, StackTrace stack) {
    if (error.runtimeType.toString() != 'DioException') {
      _apiClient.logCrash(endpoint, error, stack);
    }
  }

  List<dynamic>? _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return null;
  }

  Future<T> _runWithDialog<T>({
    BuildContext? context,
    required String message,
    required Future<T> Function() action,
  }) async {
    final showDialog = context != null && context.mounted;
    if (showDialog) {
      AppUtils.showLoadingDialog(context, message);
    }
    try {
      return await action();
    } finally {
      if (showDialog && context.mounted) {
        AppUtils.hideLoadingDialog(context);
      }
    }
  }
}
