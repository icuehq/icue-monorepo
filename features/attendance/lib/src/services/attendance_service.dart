import 'dart:convert';
import 'dart:io';
import 'package:api_client/api_client.dart';
import 'package:attendance/src/models/create_attendance.dart';
import 'package:attendance/src/models/create_attendance_response.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';

@lazySingleton
class AttendanceService {
  AttendanceService(this._apiClient);

  final ApiClient _apiClient;

  /// Checks if attendance has already been submitted for the specified class, section, and date.
  Future<bool> checkAttendanceExists({
    required int classId,
    required String section,
    required String date,
    required String period,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getClassAttendancesByDate',
      data: {
        'ClassId': classId,
        'Section': section,
        'AttendanceDate': date,
        'Period': period.isEmpty ? '1' : period,
        'Source': 'adminapp',
      },
    );

    final data = response.data;
    if (data is List) {
      return data.isNotEmpty;
    } else if (data is Map && data['err'] == true) {
      return true; // Treat error response as potential collision
    }
    return false;
  }

  /// Fetches registered MobileFaceNet embeddings for a list of students.
  Future<Map<int, List<double>>> getStudentEmbeddings({
    required int organizationId,
    required int zoneId,
    required int branchId,
    required List<int> studentIds,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v2.0/getStuEmbeddings',
      data: {
        'OrganizationId': organizationId,
        'ZoneId': zoneId,
        'BranchId': branchId,
        'StudentIds': studentIds,
      },
    );

    final embeddings = <int, List<double>>{};
    final data = response.data;
    if (data is Map && data['data'] is List) {
      final list = data['data'] as List;
      for (final item in list) {
        if (item is Map) {
          final studentId = item['StudentId'] as int?;
          final embeddingList = item['Embedding'] as List?;
          if (studentId != null && embeddingList != null) {
            embeddings[studentId] = embeddingList
                .whereType<num>()
                .map((e) => e.toDouble())
                .toList();
          }
        }
      }
    }
    return embeddings;
  }

  /// Submits attendance records for a class section.
  Future<CreateAttendanceResponse> createAttendance(
    CreateAttendance attendance,
  ) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/createAttendance',
      data: attendance.toJson(),
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return CreateAttendanceResponse.fromJson(data);
    }
    return CreateAttendanceResponse(
      err: response.statusCode != 200,
      message: 'Unexpected server response',
    );
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

  /// Compresses and uploads session snapshot photos associated with the submitted attendance ID.
  Future<bool> uploadAttendanceImages({
    required int attendanceId,
    required List<String> imagePaths,
  }) async {
    if (imagePaths.isEmpty) return true;

    try {
      final multipartFiles = <MultipartFile>[];
      for (var i = 0; i < imagePaths.length; i++) {
        final imgPath = imagePaths[i];
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
        'Id': attendanceId,
        'Source': 'adminapp',
        'Images': multipartFiles.length == 1
            ? multipartFiles.first
            : multipartFiles,
      });

      final response = await _apiClient.post<dynamic>(
        '/v2.0/uploadAttendanceImages',
        data: formData,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[AttendanceService] uploadAttendanceImages error: $e');
      return false;
    }
  }
}
