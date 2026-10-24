import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

import '../models/class_attendance_detail.dart';
import '../models/class_attendance_stats.dart';
import '../models/create_attendance.dart';
import '../models/create_attendance_response.dart';
import '../models/meta_data.dart';
import '../services/api_client.dart';
import '../services/hive_service.dart';
import '../utils/app_utils.dart';
import '../utils/constants.dart';

@lazySingleton
class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._apiClient);

  // Class Attendance Statistics state
  List<ClassAttendanceStatItem> attendanceStats = [];

  bool attendanceStatsLoading = false;
  Metadata? attendanceStatsMetadata;
  bool classAttendanceLoading = false;
  Metadata? classAttendanceMetadata;
  // Class Attendance Details (student records) state
  List<ClassAttendanceStudentItem> classAttendanceStudents = [];

  bool loading = false;
  CreateAttendance? ongoingAttendance;
  String? ongoingAttendanceKey;

  final ApiClient _apiClient;

  /// Returns the active ongoingAttendanceKey, or falls back to the first key in Hive if available.
  String? get effectiveAttendanceKey {
    if (ongoingAttendanceKey != null &&
        HiveService.createAttendanceBox.containsKey(ongoingAttendanceKey)) {
      return ongoingAttendanceKey;
    }
    final keys = HiveService.createAttendanceBox.keys;
    if (keys.isNotEmpty) {
      final key = keys.first.toString();
      ongoingAttendanceKey = key;
      return key;
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

  Future<CreateAttendance?> getOngoingAttendance() async {
    try {
      final box = HiveService.createAttendanceBox;
      final ongoingAttendanceKeys = box.keys.toList();
      if (ongoingAttendanceKeys.isNotEmpty) {
        ongoingAttendanceKey = ongoingAttendanceKeys.first.toString();
        ongoingAttendance = box.get(ongoingAttendanceKey);
        return ongoingAttendance;
      } else {
        ongoingAttendanceKey = null;
        ongoingAttendance = null;
      }
      return null;
    } catch (error, stack) {
      _apiClient.logCrash('getOngoingAttendance()', error, stack);
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteOngoingAttendance() async {
    try {
      final key = effectiveAttendanceKey;
      if (key != null) {
        await HiveService.createAttendanceBox.delete(key);
      }
      ongoingAttendanceKey = null;
      ongoingAttendance = null;
    } catch (error, stack) {
      _apiClient.logCrash('deleteOngoingAttendance()', error, stack);
    } finally {
      notifyListeners();
    }
  }

  Future<void> updateAttendance({
    required int classId,
    required String className,
    required String section,
    required String period,
    required AttendanceStudent student,
  }) async {
    try {
      final box = HiveService.createAttendanceBox;
      final key = generateAttendanceKey(
        classId: classId,
        section: section,
        period: period,
      );
      if (ongoingAttendanceKey != key) {
        ongoingAttendanceKey = key;
        notifyListeners();
      }

      final activePeriod = period.isEmpty ? '1' : period;
      final attendance = box.get(key);
      if (attendance == null) {
        await box.put(
          key,
          CreateAttendance(
            source: 'adminapp',
            students: [student],
            classId: classId,
            section: section,
            standard: className,
            attendanceDate: DateTime.now().formattedGatePassDate() ?? '',
            attendanceTime: DateTime.now().formattedAttendanceTime(),
            month: DateTime.now().month,
            year: DateTime.now().year,
            period: activePeriod,
            attendanceMode: student.attendanceMode,
          ),
        );
      } else {
        final index = attendance.students.indexWhere((e) => e.id == student.id);
        final updatedStudents = List<AttendanceStudent>.from(
          attendance.students,
        );
        if (index != -1) {
          updatedStudents[index] = student;
        } else {
          updatedStudents.add(student);
        }
        await box.put(
          key,
          attendance.copyWith(
            students: updatedStudents,
            attendanceMode: attendance.attendanceMode ?? student.attendanceMode,
          ),
        );
      }
    } catch (error, stack) {
      _apiClient.logCrash('updateAttendance()', error, stack);
    }
  }

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
      final box = HiveService.createAttendanceBox;
      final key = generateAttendanceKey(
        classId: classId,
        section: section,
        period: period,
      );
      if (ongoingAttendanceKey != key) {
        ongoingAttendanceKey = key;
      }

      final activePeriod = period.isEmpty ? '1' : period;
      final attendance = box.get(key);
      if (attendance == null) {
        await box.put(
          key,
          CreateAttendance(
            source: 'adminapp',
            students: students,
            classId: classId,
            section: section,
            standard: className,
            attendanceDate: DateTime.now().formattedGatePassDate() ?? '',
            attendanceTime: DateTime.now().formattedAttendanceTime(),
            month: DateTime.now().month,
            year: DateTime.now().year,
            period: activePeriod,
            attendanceMode:
                attendanceMode ??
                (students.isNotEmpty ? students.first.attendanceMode : null),
            images: images,
          ),
        );
      } else {
        final studentMap = {for (var s in attendance.students) s.id: s};
        for (var student in students) {
          studentMap[student.id] = student;
        }
        final updatedStudents = studentMap.values.toList();
        final combinedImages = images != null
            ? {...?attendance.images, ...images}.toList()
            : attendance.images;
        await box.put(
          key,
          attendance.copyWith(
            students: updatedStudents,
            attendanceMode: attendanceMode ?? attendance.attendanceMode,
            images: combinedImages,
          ),
        );
      }
    } catch (error, stack) {
      _apiClient.logCrash('updateAttendanceBulk()', error, stack);
    } finally {
      notifyListeners();
    }
  }

  Future<void> setAttendanceImages(List<String> images) async {
    try {
      final key = effectiveAttendanceKey;
      if (key == null) return;
      final box = HiveService.createAttendanceBox;
      final attendance = box.get(key);
      if (attendance != null) {
        await box.put(key, attendance.copyWith(images: images));
        notifyListeners();
      }
    } catch (error, stack) {
      _apiClient.logCrash('setAttendanceImages()', error, stack);
    }
  }

  Future<bool> uploadAttendanceImages({
    required int id,
    required List<String> images,
    BuildContext? context,
  }) async {
    if (images.isEmpty) return true;
    try {
      final multipartFiles = <MultipartFile>[];
      for (var i = 0; i < images.length; i++) {
        final imgPath = images[i];
        Uint8List? rawBytes;

        if (imgPath.startsWith('data:image')) {
          final base64Str = imgPath.split(',').last;
          rawBytes = base64Decode(base64Str);
        } else {
          final file = File(imgPath);
          if (await file.exists()) {
            rawBytes = await file.readAsBytes();
          }
        }

        if (rawBytes != null && rawBytes.isNotEmpty) {
          final compressedBytes = _compressImageBytes(rawBytes);
          multipartFiles.add(
            MultipartFile.fromBytes(
              compressedBytes,
              filename: 'attendance_image_$i.jpg',
              contentType: DioMediaType('image', 'jpeg'),
            ),
          );
        }
      }

      final formData = FormData.fromMap({
        'Id': id,
        'Source': 'adminapp',
        'Images': multipartFiles.length == 1
            ? multipartFiles.first
            : multipartFiles,
      });

      final response = await _apiClient.post(
        '/v2.0/uploadAttendanceImages',
        data: formData,
      );

      final responseData = response.data;
      if (response.statusCode == 200) {
        if (responseData is Map && responseData['err'] == true) {
          final msg =
              responseData['message'] ?? 'Failed to upload attendance images.';
          if (context != null && context.mounted) {
            AppUtils.showErrorMessage(context, msg);
          }
          return false;
        }
        return true;
      } else if (response.statusCode == 202) {
        final msg =
            (responseData is Map ? responseData['message'] : null) ??
            'Images not Uploaded. Please try again.';
        if (context != null && context.mounted) {
          AppUtils.showErrorMessage(context, msg);
        }
        return false;
      } else {
        final msg =
            (responseData is Map ? responseData['message'] : null) ??
            'Failed to upload attendance images.';
        if (context != null && context.mounted) {
          AppUtils.showErrorMessage(context, msg);
        }
        return false;
      }
    } on DioException catch (dioError, stack) {
      final responseData = dioError.response?.data;
      String message = 'Failed to upload attendance images.';
      if (responseData is Map && responseData['message'] != null) {
        message = responseData['message'].toString();
      } else if (dioError.response?.statusCode == 400) {
        message = 'Bad Request in uploadAttendanceImages';
      } else if (dioError.response?.statusCode == 500) {
        message = 'Failed to save attendance photos';
      }
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, message);
      }
      _apiClient.logCrash('/v2.0/uploadAttendanceImages', dioError, stack);
      return false;
    } catch (error, stack) {
      _apiClient.logCrash('/v2.0/uploadAttendanceImages', error, stack);
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(
          context,
          'Failed to upload attendance images.',
        );
      }
      return false;
    }
  }

  Future<void> createAttendance(BuildContext context) async {
    final box = HiveService.createAttendanceBox;
    final keys = box.keys.toList();
    if (keys.isEmpty) return;

    AppUtils.showLoadingDialog(context, 'Updating attendance...Please wait...');
    try {
      bool hasError = false;
      bool isSuccess = false;
      String? errorMessage;
      String? successMessage;

      for (final key in keys) {
        final data = box.get(key);
        if (data == null) continue;

        final response = await _apiClient.post(
          '/v1.0/createAttendance',
          data: createAttendanceToJson(data),
        );

        if (response.statusCode == 200) {
          final responseData = response.data;
          int? createdId;

          if (responseData is Map) {
            final createResponse = CreateAttendanceResponse.fromJson(
              responseData.cast<String, dynamic>(),
            );
            createdId = createResponse.id;
            successMessage = createResponse.message.isNotEmpty
                ? createResponse.message
                : 'Attendance submitted successfully.';
          } else {
            successMessage = 'Attendance submitted successfully.';
          }

          // If images exist in the attendance record, upload them using the created Id
          if (createdId != null &&
              data.images != null &&
              data.images!.isNotEmpty) {
            final uploadResult = await uploadAttendanceImages(
              id: createdId,
              images: data.images!,
              context: context,
            );
            if (!uploadResult) {
              hasError = true;
            }
          }

          await box.delete(key);
          isSuccess = true;
        } else if (response.statusCode == 202) {
          hasError = true;
          errorMessage =
              response.data['message'] ??
              'Attendance has already been submitted for this date.';
        } else {
          hasError = true;
          final responseData = response.data;
          if (responseData is Map && responseData['err'] == true) {
            errorMessage =
                responseData['message'] ?? 'Failed to save attendance';
          } else {
            errorMessage =
                (responseData is Map ? responseData['message'] : null) ??
                'Failed to save attendance';
          }
        }
      }

      if (context.mounted) {
        if (hasError && errorMessage != null) {
          AppUtils.showErrorMessage(context, errorMessage);
        } else if (successMessage != null) {
          AppUtils.showSucessMessage(context, successMessage);
        }
      }

      if (isSuccess && !hasError) {
        ongoingAttendanceKey = null;
        ongoingAttendance = null;
        if (context.mounted) {
          context.go('/');
        }
      }
    } catch (error, stack) {
      _apiClient.logCrash('/createAttendance', error, stack);
    } finally {
      if (context.mounted) {
        AppUtils.hideLoadingDialog(context);
      }
    }
  }

  Future<bool> checkAttendanceExists({
    required BuildContext context,
    required int classId,
    required String section,
    required String date,
    required String period,
  }) async {
    try {
      final response = await _apiClient.post(
        '/v1.0/getClassAttendancesByDate',
        data: {
          'ClassId': classId,
          'Section': section,
          'AttendanceDate': date,
          'Period': period.isEmpty ? '1' : period,
          'Source': 'adminapp',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          if (data.isEmpty) {
            return false;
          } else {
            if (context.mounted) {
              AppUtils.showErrorMessage(
                context,
                'Attendance has already been submitted for this section.',
              );
            }
            return true;
          }
        } else if (data is Map && data['err'] == true) {
          if (context.mounted) {
            AppUtils.showErrorMessage(
              context,
              data['message'] ?? 'Failed to check attendance status.',
            );
          }
          return true;
        }
      }

      if (context.mounted) {
        AppUtils.showErrorMessage(
          context,
          'Failed to check attendance status. Please try again.',
        );
      }
      return true;
    } catch (error, stack) {
      _apiClient.logCrash('/getClassAttendancesByDate check', error, stack);
      return true;
    }
  }

  Future<void> getAttendance({
    required BuildContext context,
    required int classId,
    required String section,
    required String date,
  }) async {
    loading = true;
    notifyListeners();
    try {
      await _apiClient.post(
        '/v1.0/getClassAttendancesByDate',
        data: {'ClassId': classId, 'Section': section, 'AttendanceDate': date},
      );

      if (context.mounted) {
        AppUtils.showSucessMessage(context, 'Attendance updated successfully!');
      }
    } catch (error, stack) {
      _apiClient.logCrash('/getClassAttendancesByDate', error, stack);
    } finally {
      if (context.mounted) {
        AppUtils.hideLoadingDialog(context);
      }
    }
  }

  Future<void> toggleStudentAttendance(AttendanceStudent student) async {
    try {
      final key = effectiveAttendanceKey;
      if (key == null) return;
      final box = HiveService.createAttendanceBox;
      final attendance = box.get(key);
      if (attendance == null) return;

      final index = attendance.students.indexWhere((e) => e.id == student.id);
      if (index != -1) {
        final updatedStudents = List<AttendanceStudent>.from(
          attendance.students,
        );
        updatedStudents[index] = student.copyWith(
          isPresent: !student.isPresent,
        );
        await box.put(key, attendance.copyWith(students: updatedStudents));
        notifyListeners();
      }
    } catch (error, stack) {
      _apiClient.logCrash('toggleStudentAttendance()', error, stack);
    }
  }

  void clearAttendanceStats() {
    attendanceStats.clear();
    attendanceStatsMetadata = null;
    notifyListeners();
  }

  void clearClassAttendanceStudents() {
    classAttendanceStudents.clear();
    classAttendanceMetadata = null;
    notifyListeners();
  }

  Future<ClassAttendanceStatsResponse?> getClassAttendanceStats({
    required FilterMode reportMode,
    DateTime? fromDate,
    DateTime? toDate,
    String? month,
    String? year,
    int? classId,
    String? section,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    if (pageNumber == 1) {
      attendanceStatsLoading = true;
      attendanceStats.clear();
      notifyListeners();
    }

    try {
      final user = HiveService.userInfoBox.values.firstOrNull;
      final branchId =
          HiveService.zonalBranch.get('selected')?.id ?? user?.branchId;

      final payload = <String, dynamic>{
        'ReportMode': reportMode.name,
        'PageSize': pageSize,
        'PageNumber': pageNumber,
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': branchId,
      };

      if (reportMode == FilterMode.bydate) {
        payload['FromDate'] = fromDate != null
            ? DateFormat('MM/dd/yyyy').format(fromDate)
            : DateFormat('MM/dd/yyyy').format(DateTime.now());
      } else if (reportMode == FilterMode.byperiod) {
        if (fromDate != null) {
          payload['FromDate'] = DateFormat('MM/dd/yyyy').format(fromDate);
        }
        if (toDate != null) {
          payload['ToDate'] = DateFormat('MM/dd/yyyy').format(toDate);
        }
      } else if (reportMode == FilterMode.bymonth) {
        if (month != null) payload['Month'] = month;
        if (year != null) payload['Year'] = year;
      }

      if (classId != null) {
        payload['ClassId'] = classId;
      }
      if (section != null && section.isNotEmpty) {
        payload['Section'] = section;
      }

      final response = await _apiClient.post(
        '/v2.0/getClassAttendanceStats',
        data: payload,
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final result = ClassAttendanceStatsResponse.fromJson(responseData);
        attendanceStatsMetadata = result.metadata;
        if (pageNumber == 1) {
          attendanceStats = List<ClassAttendanceStatItem>.from(result.data);
        } else {
          attendanceStats.addAll(result.data);
        }
        return result;
      }
      return null;
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getClassAttendanceStats', error, stack);
      }
      return null;
    } finally {
      attendanceStatsLoading = false;
      notifyListeners();
    }
  }

  Future<ClassAttendanceDetailResponse?> getClassAttendance({
    required FilterMode reportMode,
    required int classId,
    required String section,
    DateTime? fromDate,
    DateTime? toDate,
    String? month,
    String? year,
    String status = '',
    int pageNumber = 1,
    int pageSize = 10,
    bool clearPrevious = true,
  }) async {
    if (pageNumber == 1 && clearPrevious) {
      classAttendanceLoading = true;
      classAttendanceStudents.clear();
      notifyListeners();
    } else if (pageNumber == 1) {
      classAttendanceLoading = true;
      notifyListeners();
    }

    try {
      final user = HiveService.userInfoBox.values.firstOrNull;
      final branchId =
          HiveService.zonalBranch.get('selected')?.id ?? user?.branchId;

      final payload = <String, dynamic>{
        'ReportMode': reportMode.name,
        'ClassId': classId,
        'Section': section,
        'Status': status,
        'PageSize': pageSize,
        'PageNumber': pageNumber,
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': branchId,
      };

      if (reportMode == FilterMode.bydate) {
        payload['FromDate'] = fromDate != null
            ? DateFormat('MM/dd/yyyy').format(fromDate)
            : DateFormat('MM/dd/yyyy').format(DateTime.now());
      } else if (reportMode == FilterMode.byperiod) {
        if (fromDate != null) {
          payload['FromDate'] = DateFormat('MM/dd/yyyy').format(fromDate);
        }
        if (toDate != null) {
          payload['ToDate'] = DateFormat('MM/dd/yyyy').format(toDate);
        }
      } else if (reportMode == FilterMode.bymonth) {
        if (month != null) payload['Month'] = month;
        if (year != null) payload['Year'] = year;
      }

      final response = await _apiClient.post(
        '/v2.0/getClassAttendance',
        data: payload,
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final result = ClassAttendanceDetailResponse.fromJson(responseData);
        classAttendanceMetadata = result.metadata;
        if (pageNumber == 1) {
          classAttendanceStudents = List<ClassAttendanceStudentItem>.from(
            result.data,
          );
        } else {
          classAttendanceStudents.addAll(result.data);
        }
        return result;
      }
      return null;
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getClassAttendance', error, stack);
      }
      return null;
    } finally {
      classAttendanceLoading = false;
      notifyListeners();
    }
  }

  Uint8List _compressImageBytes(
    Uint8List inputBytes, {
    int quality = 35,
    int maxWidth = 800,
  }) {
    try {
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) return inputBytes;

      final resized = decoded.width > maxWidth
          ? img.copyResize(decoded, width: maxWidth)
          : decoded;

      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (_) {
      return inputBytes;
    }
  }
}
