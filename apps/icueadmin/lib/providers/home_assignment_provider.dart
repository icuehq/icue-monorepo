import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

import '../models/home_assignment.dart';
import '../models/meta_data.dart';
import '../services/api_client.dart';
import '../services/hive_service.dart';
import '../utils/app_utils.dart';

@lazySingleton
class HomeAssignmentProvider extends ChangeNotifier {
  HomeAssignmentProvider(this._apiClient);

  static final DateFormat apiDateFormat = DateFormat('MM/dd/yyyy');

  List<HomeAssignment> assignments = [];
  final Map<String, String> cachedDocumentImages = {};
  bool loading = false;
  bool loadingImages = false;
  Metadata? metadata;
  int? selectedClassId;
  DateTime selectedDate = DateTime.now();
  String? selectedSection;
  String? selectedStandard;
  String? selectedSubject;
  int? selectedSubjectId;
  bool submitting = false;

  final ApiClient _apiClient;

  void setFilter({
    DateTime? date,
    int? classId,
    String? standard,
    String? section,
    int? subjectId,
    String? subject,
  }) {
    if (date != null) selectedDate = date;
    if (classId != null) selectedClassId = classId;
    if (standard != null) selectedStandard = standard;
    if (section != null) selectedSection = section;
    selectedSubjectId = subjectId;
    selectedSubject = subject;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
  }

  void resetFilters() {
    selectedDate = DateTime.now();
    selectedClassId = null;
    selectedStandard = null;
    selectedSection = null;
    selectedSubjectId = null;
    selectedSubject = null;
    assignments = [];
    metadata = null;
    notifyListeners();
  }

  Future<void> getHomeAssignments({
    BuildContext? context,
    bool isRefresh = false,
  }) async {
    if (selectedClassId == null || selectedSection == null) {
      assignments = [];
      metadata = null;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();

    try {
      final user = HiveService.currentUser;
      final selectedBranch = HiveService.currentZonalBranch;
      final branchId = selectedBranch?.id ?? user?.branchId;

      final payload = {
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': branchId,
        'ReportMode': 'bydate',
        'FromDate': apiDateFormat.format(selectedDate),
        'ClassId': selectedClassId,
        'Section': selectedSection,
        if (selectedSubjectId != null && selectedSubjectId! > 0)
          'SubjectId': selectedSubjectId,
        'PageSize': 50,
        'PageNumber': 1,
      };

      final response = await _apiClient.post(
        '/v1.0/getHomeAssignments',
        data: payload,
      );

      if (response.statusCode == 200) {
        final data = homeAssignmentResponseFromJson(jsonEncode(response.data));
        assignments = data.data;
        metadata = data.metadata;

        // Fetch image URLs for all uncached document IDs
        final unCachedDocIds = assignments
            .expand((a) => a.images)
            .where(
              (id) => id.isNotEmpty && !cachedDocumentImages.containsKey(id),
            )
            .toSet()
            .toList();

        if (unCachedDocIds.isNotEmpty) {
          fetchImagesForDocumentIds(unCachedDocIds);
        }
      } else {
        assignments = [];
        metadata = null;
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getHomeAssignments', error, stack);
      }
      log('Error getting home assignments: $error');
      assignments = [];
      metadata = null;
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(
          context,
          'Failed to fetch home assignments. Please try again.',
        );
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchImagesForDocumentIds(List<String> docIds) async {
    if (docIds.isEmpty) return;

    loadingImages = true;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        '/v1.0/getImagesByDocumentIds',
        data: {'DocumentIds': docIds},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = documentImagesResponseFromJson(jsonEncode(response.data));

        for (final item in data.images) {
          if (item.documentId.isNotEmpty && item.imageUrl.isNotEmpty) {
            cachedDocumentImages[item.documentId] = item.imageUrl;
          }
        }
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getImagesByDocumentIds', error, stack);
      }
      log('Error fetching document images: $error');
    } finally {
      loadingImages = false;
      notifyListeners();
    }
  }

  Future<bool> createHomeWork({
    required BuildContext context,
    required int classId,
    required String section,
    required String standard,
    required int subjectId,
    required String subject,
    required DateTime submissionDate,
    required String work,
    List<PlatformFile>? platformFiles,
    List<XFile>? xFiles,
  }) async {
    submitting = true;
    notifyListeners();
    AppUtils.showLoadingDialog(
      context,
      'Submitting homework... Please wait...',
    );

    try {
      final user = HiveService.currentUser;
      final selectedBranch = HiveService.currentZonalBranch;
      final branchId = selectedBranch?.id ?? user?.branchId;

      final formData = FormData.fromMap({
        'ClassId': classId.toString(),
        'Section': section,
        'Standard': standard,
        'SubjectId': subjectId.toString(),
        'Subject': subject,
        'SubmissionDate': apiDateFormat.format(submissionDate),
        'Work': work,
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': branchId,
      });

      // Attach files if provided
      if (platformFiles != null && platformFiles.isNotEmpty) {
        for (final file in platformFiles) {
          if (file.bytes != null) {
            formData.files.add(
              MapEntry(
                'Files',
                MultipartFile.fromBytes(file.bytes!, filename: file.name),
              ),
            );
          } else if (file.path != null) {
            formData.files.add(
              MapEntry(
                'Files',
                await MultipartFile.fromFile(file.path!, filename: file.name),
              ),
            );
          }
        }
      } else if (xFiles != null && xFiles.isNotEmpty) {
        for (final file in xFiles) {
          final bytes = await file.readAsBytes();
          formData.files.add(
            MapEntry(
              'Files',
              MultipartFile.fromBytes(bytes, filename: file.name),
            ),
          );
        }
      }

      final response = await _apiClient.post(
        '/v1.0/createHomeWorksWithFiles',
        data: formData,
      );

      final responseData = response.data;
      final isErr = responseData is Map && responseData['err'] == true;
      final message = responseData is Map
          ? responseData['message']?.toString() ?? ''
          : '';

      if (response.statusCode == 200 && !isErr) {
        if (context.mounted) {
          AppUtils.showSucessMessage(
            context,
            message.isNotEmpty ? message : 'Homework created successfully!',
          );
        }
        // Refresh homework list for the current class & section
        await getHomeAssignments(context: context);
        return true;
      } else {
        if (context.mounted) {
          AppUtils.showErrorMessage(
            context,
            message.isNotEmpty ? message : 'Failed to save Homework.',
          );
        }
        return false;
      }
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/createHomeWorksWithFiles', error, stack);
      }
      log('Error creating homework: $error');
      if (context.mounted) {
        AppUtils.showErrorMessage(
          context,
          'Failed to save Homework. Please try again.',
        );
      }
      return false;
    } finally {
      if (context.mounted) {
        AppUtils.hideLoadingDialog(context);
      }
      submitting = false;
      notifyListeners();
    }
  }
}
