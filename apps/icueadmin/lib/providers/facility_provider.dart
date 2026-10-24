import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

import '../models/cleaning_task_response.dart';
import '../models/facility_task.dart';
import '../models/qr_cleaning_tasks_response.dart';
import '../models/user_info.dart';
import '../services/api_client.dart';
import '../services/hive_service.dart';
import '../utils/app_utils.dart';

class _ImageCompressParams {
  const _ImageCompressParams(this.bytes);

  final Uint8List bytes;
  static const int quality = 55;
  static const int maxDimension = 800;
}

Uint8List _compressImageWorker(_ImageCompressParams params) {
  try {
    final decoded = img.decodeImage(params.bytes);
    if (decoded == null) return params.bytes;

    img.Image resized = decoded;
    const maxDim = _ImageCompressParams.maxDimension;
    if (decoded.width > maxDim || decoded.height > maxDim) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: maxDim);
      } else {
        resized = img.copyResize(decoded, height: maxDim);
      }
    }

    return Uint8List.fromList(
      img.encodeJpg(resized, quality: _ImageCompressParams.quality),
    );
  } catch (_) {
    return params.bytes;
  }
}

@lazySingleton
class FacilityProvider extends ChangeNotifier {
  FacilityProvider(this._apiClient);

  final ApiClient _apiClient;

  /// Safely retrieves the currently authenticated user from Hive cache
  UserInfo? get _currentUser {
    try {
      if (Hive.isBoxOpen('userInfo-v2') && HiveService.userInfoBox.isOpen) {
        return HiveService.userInfoBox.values.firstOrNull;
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------
  // State Variables & Loading Flags
  // ---------------------------------------------------------
  bool _tasksLoading = false;
  bool _qrTasksLoading = false;
  bool _detailsLoading = false;
  bool _actionLoading = false;
  String? _errorMessage;

  List<FacilityTask> cleaningTasks = [];
  List<FacilityTask> cleaningTasksQr = [];
  Facility? currentFacilityQr;
  CleaningTask? cleaningTaskDetails;
  Map<String, String> cachedImages = {};
  final Set<String> _failedImageDocumentIds = {};

  /// Global loading flag for backward compatibility
  bool get loading =>
      _tasksLoading || _qrTasksLoading || _detailsLoading || _actionLoading;

  /// Granular loading state getters for optimized, smooth UI rebuilding
  bool get isTasksLoading => _tasksLoading;
  bool get isQrTasksLoading => _qrTasksLoading;
  bool get isDetailsLoading => _detailsLoading;
  bool get isActionLoading => _actionLoading;

  /// Last error message, if any
  String? get errorMessage => _errorMessage;

  /// Clears any active error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clears cached task details when navigating away
  void clearDetails() {
    cleaningTaskDetails = null;
    notifyListeners();
  }

  /// Resets all facility provider state
  void reset() {
    cleaningTasks.clear();
    cleaningTasksQr.clear();
    currentFacilityQr = null;
    cleaningTaskDetails = null;
    cachedImages.clear();
    _failedImageDocumentIds.clear();
    _errorMessage = null;
    _tasksLoading = false;
    _qrTasksLoading = false;
    _detailsLoading = false;
    _actionLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------
  // 1. Fetch Cleaning Tasks by Date
  // ---------------------------------------------------------
  Future<void> getCleaningTasks(DateTime scheduledDate) async {
    _tasksLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _currentUser;
      final payload = {
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': user?.branchId,
        'ScheduledDate': DateFormat('MM/dd/yyyy').format(scheduledDate),
        'PageNumber': 1,
        'PageSize': 20,
      };

      final response = await _apiClient.post(
        '/v1.0/listUserCleaningTasks',
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = FacilityTasksResponse.fromJson(response.data);
        cleaningTasks = data.data;
      } else {
        _errorMessage = response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : 'Failed to load cleaning tasks';
      }
    } on DioException catch (dioError, stack) {
      _errorMessage = 'Network error loading cleaning tasks';
      _apiClient.logCrash(
        '/listUserCleaningTasks',
        dioError,
        stack,
        message: dioError.message,
      );
    } catch (error, stack) {
      _errorMessage = 'An unexpected error occurred while loading tasks';
      _apiClient.logCrash(
        '/listUserCleaningTasks',
        error,
        stack,
        message: error.toString(),
      );
    } finally {
      _tasksLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------
  // 2. Fetch Cleaning Tasks by QR Code
  // ---------------------------------------------------------
  Future<bool> getCleaningTasksByQR(
    DateTime scheduledDate,
    String qrCode, {
    bool? isBasicFacilityMgmt,
  }) async {
    _qrTasksLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _currentUser;
      final payload = <String, dynamic>{
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': user?.branchId,
        'ScheduledDate': DateFormat('MM/dd/yyyy').format(scheduledDate),
        'PageNumber': 1,
        'PageSize': 20,
        'QrCode': qrCode,
        'AssignedUserId': user?.id,
        'IsBasicFacilityMgmt': ?isBasicFacilityMgmt,
      };

      final response = await _apiClient.post(
        '/v1.0/getFacilityTasksByQrCode',
        data: payload,
      );

      final isErr = response.data is Map && response.data['err'] == true;
      if (response.statusCode == 200 && response.data != null && !isErr) {
        final data = QrCleaningTaskResponse.fromJson(response.data);
        cleaningTasksQr = data.data.tasks;
        currentFacilityQr = data.data.facility;
        return true;
      } else {
        _errorMessage = response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : 'Failed to load tasks for scanned QR code';
        return false;
      }
    } on DioException catch (dioError, stack) {
      _errorMessage = 'Network error fetching QR facility tasks';
      _apiClient.logCrash(
        '/getFacilityTasksByQrCode',
        dioError,
        stack,
        message: dioError.message,
      );
      return false;
    } catch (error, stack) {
      _errorMessage = 'An unexpected error occurred while loading QR tasks';
      _apiClient.logCrash(
        '/getFacilityTasksByQrCode',
        error,
        stack,
        message: error.toString(),
      );
      return false;
    } finally {
      _qrTasksLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------
  // 3. Fetch Cleaning Task Details
  // ---------------------------------------------------------
  Future<void> getCleaningTaskDetails(int id) async {
    _detailsLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _currentUser;
      final payload = {
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': user?.branchId,
        'Id': id,
      };

      final response = await _apiClient.post(
        '/v1.0/getCleaningTask',
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = CleaningTaskResponse.fromJson(response.data);
        cleaningTaskDetails = data.data;
      } else {
        _errorMessage = response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : 'Failed to load task details';
      }
    } on DioException catch (dioError, stack) {
      _errorMessage = 'Network error loading task details';
      _apiClient.logCrash(
        '/getCleaningTask',
        dioError,
        stack,
        message: dioError.message,
      );
    } catch (error, stack) {
      _errorMessage = 'An unexpected error occurred while loading task details';
      _apiClient.logCrash(
        '/getCleaningTask',
        error,
        stack,
        message: error.toString(),
      );
    } finally {
      _detailsLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------
  // 4. Start Cleaning Task (Optimistic State Sync)
  // ---------------------------------------------------------
  Future<bool> startCleaningTask(int id, {BuildContext? context}) async {
    _actionLoading = true;
    notifyListeners();

    try {
      final user = _currentUser;
      final payload = {
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': user?.branchId,
        'Id': id,
      };

      final response = await _apiClient.post(
        '/v1.0/startCleaningTask',
        data: payload,
      );

      if (kDebugMode) {
        log('startCleaningTask => ${jsonEncode(response.data)}');
      }

      final isErr = response.data is Map && response.data['err'] == true;
      if (response.statusCode == 200 && !isErr) {
        // Optimistically update status in local memory for smooth UI transition
        _updateTaskStatusInLists(id, 'InProgress', startedAt: DateTime.now());
        if (cleaningTaskDetails != null && cleaningTaskDetails!.id == id) {
          cleaningTaskDetails = cleaningTaskDetails!.copyWith(
            status: 'InProgress',
          );
        }

        if (context != null && context.mounted) {
          final message =
              response.data is Map && response.data['message'] != null
              ? response.data['message'].toString()
              : 'Cleaning task started successfully';
          AppUtils.showSucessMessage(context, message);
        }
        return true;
      }

      final errMsg = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : 'Failed to start cleaning task.';
      _errorMessage = errMsg;
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, errMsg);
      }
      return false;
    } on DioException catch (dioError, stack) {
      _errorMessage = 'Network error starting cleaning task';
      _apiClient.logCrash(
        '/v1.0/startCleaningTask',
        dioError,
        stack,
        message: dioError.message,
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to start cleaning task.');
      }
      return false;
    } catch (error, stack) {
      _errorMessage =
          'An unexpected error occurred while starting cleaning task';
      _apiClient.logCrash(
        '/v1.0/startCleaningTask',
        error,
        stack,
        message: error.toString(),
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to start cleaning task.');
      }
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------
  // 5. Image Compression & Concurrent Photo Uploads (via Isolate)
  // ---------------------------------------------------------
  Future<List<String>> uploadCleaningTaskPhotos({
    required List<XFile> photos,
    BuildContext? context,
  }) async {
    if (photos.isEmpty) return [];

    try {
      final user = _currentUser;

      // Upload all photos concurrently for high-speed performance
      final uploadFutures = photos.asMap().entries.map((entry) async {
        final i = entry.key;
        final photo = entry.value;

        final rawBytes = await photo.readAsBytes();
        final compressedBytes = await compute(
          _compressImageWorker,
          _ImageCompressParams(rawBytes),
        );

        final filename = photo.name.isNotEmpty
            ? photo.name
            : 'cleaning_photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final ext = filename.split('.').last.toLowerCase();
        final imageType = (ext == 'png') ? 'png' : 'jpeg';

        final formData = FormData.fromMap({
          'OrganizationId': user?.organizationId,
          'ZoneId': user?.zoneId,
          'BranchId': user?.branchId,
          'Photos': MultipartFile.fromBytes(
            compressedBytes,
            filename: filename,
            contentType: DioMediaType('image', imageType),
          ),
        });

        final response = await _apiClient.post(
          '/v1.0/uploadCleaningTaskPhotos',
          data: formData,
        );

        if (kDebugMode) {
          log('uploadCleaningTaskPhoto[$i] => ${jsonEncode(response.data)}');
        }

        final List<String> ids = [];
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data is Map && data['data'] is List) {
            for (var item in data['data'] as List) {
              if (item is Map && item['DocumentId'] != null) {
                ids.add(item['DocumentId'].toString());
              }
            }
          } else if (data is List) {
            for (var item in data) {
              if (item is Map && item['DocumentId'] != null) {
                ids.add(item['DocumentId'].toString());
              }
            }
          }
        }
        return ids;
      });

      final results = await Future.wait(uploadFutures);
      final documentIds = results.expand((x) => x).toList();
      return documentIds;
    } on DioException catch (dioError, stack) {
      _apiClient.logCrash(
        '/v1.0/uploadCleaningTaskPhotos',
        dioError,
        stack,
        message: dioError.message,
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to upload task photos.');
      }
      return [];
    } catch (error, stack) {
      _apiClient.logCrash(
        '/v1.0/uploadCleaningTaskPhotos',
        error,
        stack,
        message: error.toString(),
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to upload task photos.');
      }
      return [];
    }
  }

  // ---------------------------------------------------------
  // 6. Complete Cleaning Task (Optimistic State Sync)
  // ---------------------------------------------------------
  Future<bool> completeCleaningTask(
    int id,
    String remarks,
    List<dynamic> checklistResults,
    List<String> beforePhotoDocIds,
    List<String> afterPhotoDocIds, {
    BuildContext? context,
  }) async {
    _actionLoading = true;
    notifyListeners();

    try {
      final user = _currentUser;
      final payload = {
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': user?.branchId,
        'Id': id,
        'Remarks': remarks,
        'ChecklistResults': checklistResults,
        'BeforePhotos': [
          for (var docId in beforePhotoDocIds) {'DocumentId': docId},
        ],
        'AfterPhotos': [
          for (var docId in afterPhotoDocIds) {'DocumentId': docId},
        ],
      };

      final response = await _apiClient.post(
        '/v1.0/completeCleaningTask',
        data: payload,
      );

      if (kDebugMode) {
        log('completeCleaningTask => ${jsonEncode(response.data)}');
      }

      final isErr = response.data is Map && response.data['err'] == true;
      if (response.statusCode == 200 && !isErr) {
        // Optimistically update status in local memory
        _updateTaskStatusInLists(id, 'Completed');
        if (cleaningTaskDetails != null && cleaningTaskDetails!.id == id) {
          cleaningTaskDetails = cleaningTaskDetails!.copyWith(
            status: 'Completed',
            checklistResults: checklistResults,
            beforePhotos: [
              for (var docId in beforePhotoDocIds) {'DocumentId': docId},
            ],
            afterPhotos: [
              for (var docId in afterPhotoDocIds) {'DocumentId': docId},
            ],
          );
        }

        if (context != null && context.mounted) {
          final message =
              response.data is Map && response.data['message'] != null
              ? response.data['message'].toString()
              : 'Cleaning task completed successfully';
          AppUtils.showSucessMessage(context, message);
        }
        return true;
      }

      final errMsg = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : 'Failed to complete cleaning task.';
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, errMsg);
      }
      return false;
    } on DioException catch (dioError, stack) {
      _apiClient.logCrash(
        '/v1.0/completeCleaningTask',
        dioError,
        stack,
        message: dioError.message,
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to complete cleaning task.');
      }
      return false;
    } catch (error, stack) {
      _apiClient.logCrash(
        '/v1.0/completeCleaningTask',
        error,
        stack,
        message: error.toString(),
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to complete cleaning task.');
      }
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------
  // 7. Skip Cleaning Task (Optimistic State Sync)
  // ---------------------------------------------------------
  Future<bool> skipCleaningTask({
    required int taskId,
    required String remarks,
    BuildContext? context,
  }) async {
    _actionLoading = true;
    notifyListeners();

    try {
      final user = _currentUser;
      final payload = {
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': user?.branchId,
        'Id': taskId,
        'Remarks': remarks.trim(),
      };

      final response = await _apiClient.post(
        '/v1.0/skipCleaningTask',
        data: payload,
      );

      if (kDebugMode) {
        log('skipCleaningTask => ${jsonEncode(response.data)}');
      }

      final isErr = response.data is Map && response.data['err'] == true;
      if (response.statusCode == 200 && !isErr) {
        // Optimistically update status in local memory
        _updateTaskStatusInLists(taskId, 'Skipped');
        if (cleaningTaskDetails != null && cleaningTaskDetails!.id == taskId) {
          cleaningTaskDetails = cleaningTaskDetails!.copyWith(
            status: 'Skipped',
            skipRemarks: remarks.trim(),
            skippedAt: DateTime.now(),
          );
        }

        if (context != null && context.mounted) {
          final message =
              response.data is Map && response.data['message'] != null
              ? response.data['message'].toString()
              : 'Cleaning task skipped successfully';
          AppUtils.showSucessMessage(context, message);
        }
        return true;
      }

      final errMsg = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : 'Failed to skip cleaning task.';
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, errMsg);
      }
      return false;
    } on DioException catch (dioError, stack) {
      _apiClient.logCrash(
        '/v1.0/skipCleaningTask',
        dioError,
        stack,
        message: dioError.message,
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to skip cleaning task.');
      }
      return false;
    } catch (error, stack) {
      _apiClient.logCrash(
        '/v1.0/skipCleaningTask',
        error,
        stack,
        message: error.toString(),
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to skip cleaning task.');
      }
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------
  // 8. Fail Cleaning Task (Optimistic State Sync)
  // ---------------------------------------------------------
  Future<bool> failCleaningTask({
    required int taskId,
    required String remarks,
    BuildContext? context,
  }) async {
    _actionLoading = true;
    notifyListeners();

    try {
      final user = _currentUser;
      final payload = {
        'OrganizationId': user?.organizationId,
        'ZoneId': user?.zoneId,
        'BranchId': user?.branchId,
        'Id': taskId,
        'Remarks': remarks.trim(),
      };

      final response = await _apiClient.post(
        '/v1.0/failCleaningTask',
        data: payload,
      );

      if (kDebugMode) {
        log('failCleaningTask => ${jsonEncode(response.data)}');
      }

      final isErr = response.data is Map && response.data['err'] == true;
      if (response.statusCode == 200 && !isErr) {
        // Optimistically update status in local memory
        _updateTaskStatusInLists(taskId, 'Failed');
        if (cleaningTaskDetails != null && cleaningTaskDetails!.id == taskId) {
          cleaningTaskDetails = cleaningTaskDetails!.copyWith(
            status: 'Failed',
            skipRemarks: remarks.trim(),
          );
        }

        if (context != null && context.mounted) {
          final message =
              response.data is Map && response.data['message'] != null
              ? response.data['message'].toString()
              : 'Cleaning task reported as failed';
          AppUtils.showSucessMessage(context, message);
        }
        return true;
      }

      final errMsg = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : 'Failed to report cleaning task failure.';
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, errMsg);
      }
      return false;
    } on DioException catch (dioError, stack) {
      _apiClient.logCrash(
        '/v1.0/failCleaningTask',
        dioError,
        stack,
        message: dioError.message,
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to fail cleaning task.');
      }
      return false;
    } catch (error, stack) {
      _apiClient.logCrash(
        '/v1.0/failCleaningTask',
        error,
        stack,
        message: error.toString(),
      );
      if (context != null && context.mounted) {
        AppUtils.showErrorMessage(context, 'Failed to fail cleaning task.');
      }
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------
  // 9. Fetch Image URLs by Document IDs
  // ---------------------------------------------------------
  Future<Map<String, String>> getImagesByDocumentIds({
    required List<String> documentIds,
  }) async {
    if (documentIds.isEmpty) return {};

    // Check what IDs are missing from cache and have not already failed
    final missingIds = documentIds
        .where(
          (id) =>
              (!cachedImages.containsKey(id) || cachedImages[id]!.isEmpty) &&
              !_failedImageDocumentIds.contains(id),
        )
        .toList();

    if (missingIds.isEmpty) {
      return {
        for (var id in documentIds)
          if (cachedImages[id] != null && cachedImages[id]!.isNotEmpty)
            id: cachedImages[id]!,
      };
    }

    try {
      final payload = {'DocumentIds': missingIds};

      final response = await _apiClient.post(
        '/v1.0/getImagesByDocumentIds',
        data: payload,
      );

      if (kDebugMode) {
        log('getImagesByDocumentIds => ${jsonEncode(response.data)}');
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List? imagesList;

        if (data is Map) {
          if (data['Images'] is List) {
            imagesList = data['Images'] as List;
          } else if (data['data'] is List) {
            imagesList = data['data'] as List;
          } else if (data['data'] is Map) {
            (data['data'] as Map).forEach((k, v) {
              cachedImages[k.toString()] = v.toString();
            });
          }
        } else if (data is List) {
          imagesList = data;
        }

        if (imagesList != null) {
          for (var item in imagesList) {
            if (item is Map) {
              final docId = item['DocumentId']?.toString();
              final url =
                  (item['ImageUrl'] ??
                          item['Url'] ??
                          item['Image'] ??
                          item['url'])
                      ?.toString();
              if (docId != null &&
                  docId.isNotEmpty &&
                  url != null &&
                  url.isNotEmpty) {
                cachedImages[docId] = url;
              }
            }
          }
        }

        // Record any missing IDs as failed so we don't query again
        for (var id in missingIds) {
          if (!cachedImages.containsKey(id) || cachedImages[id]!.isEmpty) {
            _failedImageDocumentIds.add(id);
          }
        }
      } else {
        // Record all missing as failed on error response
        _failedImageDocumentIds.addAll(missingIds);
      }

      return {
        for (var id in documentIds)
          if (cachedImages[id] != null && cachedImages[id]!.isNotEmpty)
            id: cachedImages[id]!,
      };
    } on DioException catch (dioError, stack) {
      _failedImageDocumentIds.addAll(missingIds);
      _apiClient.logCrash(
        '/v1.0/getImagesByDocumentIds',
        dioError,
        stack,
        message: dioError.message,
      );
      return {
        for (var id in documentIds)
          if (cachedImages[id] != null && cachedImages[id]!.isNotEmpty)
            id: cachedImages[id]!,
      };
    } catch (error, stack) {
      _failedImageDocumentIds.addAll(missingIds);
      _apiClient.logCrash(
        '/v1.0/getImagesByDocumentIds',
        error,
        stack,
        message: error.toString(),
      );
      return {
        for (var id in documentIds)
          if (cachedImages[id] != null && cachedImages[id]!.isNotEmpty)
            id: cachedImages[id]!,
      };
    }
  }

  // ---------------------------------------------------------
  // Helper: Synchronize Local Task Lists Status
  // ---------------------------------------------------------
  void _updateTaskStatusInLists(
    int taskId,
    String newStatus, {
    DateTime? startedAt,
  }) {
    // 1. Update cleaningTasks
    final index = cleaningTasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final current = cleaningTasks[index];
      cleaningTasks[index] = current.copyWith(
        status: newStatus,
        startedAt: startedAt ?? current.startedAt,
      );
    }

    // 2. Update cleaningTasksQr
    final qrIndex = cleaningTasksQr.indexWhere((t) => t.id == taskId);
    if (qrIndex != -1) {
      final current = cleaningTasksQr[qrIndex];
      cleaningTasksQr[qrIndex] = current.copyWith(
        status: newStatus,
        startedAt: startedAt ?? current.startedAt,
      );
    }
  }
}
