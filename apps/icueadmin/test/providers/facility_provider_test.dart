import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/config/env.dart';
import 'package:icueadmin/models/cleaning_task_response.dart';
import 'package:icueadmin/models/facility_task.dart';
import 'package:icueadmin/models/facility_task_status.dart';
import 'package:icueadmin/models/qr_cleaning_tasks_response.dart';
import 'package:icueadmin/providers/facility_provider.dart';
import 'package:icueadmin/services/api_client.dart';
import 'package:icueadmin/services/crashlytics_service.dart';

class FakeCrashlyticsService extends Fake implements CrashlyticsService {
  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {}
}

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(Dio(), FakeCrashlyticsService());

  Response? mockResponse;
  DioException? mockError;
  dynamic capturedData;
  String? capturedPath;

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    capturedPath = path;
    capturedData = data;
    if (mockError != null) throw mockError!;
    return mockResponse ??
        Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {'err': false, 'data': {}},
        );
  }
}

void main() {
  setUpAll(() {
    Env().initEnvConfig();
  });

  late FakeApiClient fakeApiClient;
  late FacilityProvider provider;

  setUp(() {
    fakeApiClient = FakeApiClient();
    provider = FacilityProvider(fakeApiClient);
  });

  group('FacilityProvider State Management', () {
    test('initial state is clean', () {
      expect(provider.loading, isFalse);
      expect(provider.isTasksLoading, isFalse);
      expect(provider.isQrTasksLoading, isFalse);
      expect(provider.isDetailsLoading, isFalse);
      expect(provider.isActionLoading, isFalse);
      expect(provider.cleaningTasks, isEmpty);
      expect(provider.cleaningTasksQr, isEmpty);
      expect(provider.cleaningTaskDetails, isNull);
      expect(provider.errorMessage, isNull);
    });

    test('clearError and clearDetails reset specific state', () {
      provider.cleaningTaskDetails = CleaningTask(
        id: 1,
        scheduleName: 'Test Task',
        status: 'Pending',
      );
      expect(provider.cleaningTaskDetails, isNotNull);

      provider.clearDetails();
      expect(provider.cleaningTaskDetails, isNull);

      provider.clearError();
      expect(provider.errorMessage, isNull);
    });

    test('reset clears all provider state', () {
      provider.cleaningTasks = [FacilityTask(id: 1, status: 'Pending')];
      provider.cleaningTasksQr = [FacilityTask(id: 2, status: 'Pending')];
      provider.cleaningTaskDetails = CleaningTask(id: 1, status: 'Pending');

      provider.reset();

      expect(provider.cleaningTasks, isEmpty);
      expect(provider.cleaningTasksQr, isEmpty);
      expect(provider.cleaningTaskDetails, isNull);
      expect(provider.loading, isFalse);
    });
  });

  group('FacilityProvider Optimistic Updates', () {
    test(
      'startCleaningTask optimistically updates task status in lists and details',
      () async {
        provider.cleaningTasks = [
          FacilityTask(id: 10, status: 'Pending'),
          FacilityTask(id: 20, status: 'Pending'),
        ];
        provider.cleaningTasksQr = [FacilityTask(id: 10, status: 'Pending')];
        provider.cleaningTaskDetails = CleaningTask(id: 10, status: 'Pending');

        fakeApiClient.mockResponse = Response(
          requestOptions: RequestOptions(path: '/v1.0/startCleaningTask'),
          statusCode: 200,
          data: {'err': false, 'message': 'Task started'},
        );

        final result = await provider.startCleaningTask(10);

        expect(result, isTrue);
        expect(
          provider.cleaningTasks.firstWhere((t) => t.id == 10).status,
          equals('InProgress'),
        );
        expect(
          provider.cleaningTasks.firstWhere((t) => t.id == 10).startedAt,
          isNotNull,
        );
        expect(
          provider.cleaningTasks.firstWhere((t) => t.id == 20).status,
          equals('Pending'),
        );
        expect(
          provider.cleaningTasksQr.firstWhere((t) => t.id == 10).status,
          equals('InProgress'),
        );
        expect(provider.cleaningTaskDetails?.status, equals('InProgress'));
      },
    );

    test(
      'completeCleaningTask optimistically updates task status to Completed',
      () async {
        provider.cleaningTasks = [FacilityTask(id: 15, status: 'InProgress')];
        provider.cleaningTasksQr = [FacilityTask(id: 15, status: 'InProgress')];
        provider.cleaningTaskDetails = CleaningTask(
          id: 15,
          status: 'InProgress',
        );

        fakeApiClient.mockResponse = Response(
          requestOptions: RequestOptions(path: '/v1.0/completeCleaningTask'),
          statusCode: 200,
          data: {'err': false, 'message': 'Task completed'},
        );

        final result = await provider.completeCleaningTask(
          15,
          'Done well',
          [
            {'ItemId': '1', 'Completed': true},
          ],
          ['doc1'],
          ['doc2'],
        );

        expect(result, isTrue);
        expect(provider.cleaningTasks.first.status, equals('Completed'));
        expect(provider.cleaningTasksQr.first.status, equals('Completed'));
        expect(provider.cleaningTaskDetails?.status, equals('Completed'));
      },
    );

    test(
      'skipCleaningTask optimistically updates task status to Skipped with remarks',
      () async {
        provider.cleaningTasks = [FacilityTask(id: 30, status: 'Pending')];
        provider.cleaningTasksQr = [FacilityTask(id: 30, status: 'Pending')];
        provider.cleaningTaskDetails = CleaningTask(id: 30, status: 'Pending');

        fakeApiClient.mockResponse = Response(
          requestOptions: RequestOptions(path: '/v1.0/skipCleaningTask'),
          statusCode: 200,
          data: {'err': false, 'message': 'Task skipped'},
        );

        final result = await provider.skipCleaningTask(
          taskId: 30,
          remarks: 'Area locked',
        );

        expect(result, isTrue);
        expect(provider.cleaningTasks.first.status, equals('Skipped'));
        expect(provider.cleaningTasksQr.first.status, equals('Skipped'));
        expect(provider.cleaningTaskDetails?.status, equals('Skipped'));
        expect(
          provider.cleaningTaskDetails?.skipRemarks,
          equals('Area locked'),
        );
      },
    );

    test(
      'failCleaningTask optimistically updates task status to Failed with remarks',
      () async {
        provider.cleaningTasks = [FacilityTask(id: 40, status: 'InProgress')];
        provider.cleaningTasksQr = [FacilityTask(id: 40, status: 'InProgress')];
        provider.cleaningTaskDetails = CleaningTask(
          id: 40,
          status: 'InProgress',
        );

        fakeApiClient.mockResponse = Response(
          requestOptions: RequestOptions(path: '/v1.0/failCleaningTask'),
          statusCode: 200,
          data: {'err': false, 'message': 'Task failed'},
        );

        final result = await provider.failCleaningTask(
          taskId: 40,
          remarks: 'Water supply issue',
        );

        expect(result, isTrue);
        expect(provider.cleaningTasks.first.status, equals('Failed'));
        expect(provider.cleaningTasksQr.first.status, equals('Failed'));
        expect(provider.cleaningTaskDetails?.status, equals('Failed'));
        expect(
          provider.cleaningTaskDetails?.skipRemarks,
          equals('Water supply issue'),
        );
      },
    );
  });

  group('getImagesByDocumentIds', () {
    test('returns empty map when documentIds list is empty', () async {
      final result = await provider.getImagesByDocumentIds(documentIds: []);
      expect(result, isEmpty);
    });

    test(
      'parses and returns documentId to URL mapping from response data array',
      () async {
        fakeApiClient.mockResponse = Response(
          requestOptions: RequestOptions(path: '/v1.0/getImagesByDocumentIds'),
          statusCode: 200,
          data: {
            'err': false,
            'data': [
              {'DocumentId': 'doc_123', 'Url': 'https://example.com/img1.jpg'},
              {'DocumentId': 'doc_456', 'Url': 'https://example.com/img2.jpg'},
            ],
          },
        );

        final result = await provider.getImagesByDocumentIds(
          documentIds: ['doc_123', 'doc_456'],
        );

        expect(result.length, equals(2));
        expect(result['doc_123'], equals('https://example.com/img1.jpg'));
        expect(result['doc_456'], equals('https://example.com/img2.jpg'));
      },
    );

    test(
      'parses and returns documentId to ImageUrl mapping from Images response array and caches it',
      () async {
        fakeApiClient.mockResponse = Response(
          requestOptions: RequestOptions(path: '/v1.0/getImagesByDocumentIds'),
          statusCode: 200,
          data: {
            'err': false,
            'message': 'succes',
            'Images': [
              {
                'DocumentId': '81fce417-d2fc-4eda-99fd-6c6cad7fef83',
                'ImageUrl':
                    'https://vroomdms.s3.ap-south-1.amazonaws.com/img1.jpg',
              },
            ],
          },
        );

        final result = await provider.getImagesByDocumentIds(
          documentIds: ['81fce417-d2fc-4eda-99fd-6c6cad7fef83'],
        );

        expect(result.length, equals(1));
        expect(
          result['81fce417-d2fc-4eda-99fd-6c6cad7fef83'],
          equals('https://vroomdms.s3.ap-south-1.amazonaws.com/img1.jpg'),
        );
        expect(
          provider.cachedImages['81fce417-d2fc-4eda-99fd-6c6cad7fef83'],
          equals('https://vroomdms.s3.ap-south-1.amazonaws.com/img1.jpg'),
        );

        // Subsequent call with cached ID should return immediately without API call
        fakeApiClient.mockResponse = null;
        fakeApiClient.capturedPath = null;

        final cachedResult = await provider.getImagesByDocumentIds(
          documentIds: ['81fce417-d2fc-4eda-99fd-6c6cad7fef83'],
        );
        expect(cachedResult.length, equals(1));
        expect(fakeApiClient.capturedPath, isNull);
      },
    );
  });

  group('CleaningTask.fromJson complete API response parsing', () {
    test(
      'parses full getCleaningTask API response with metadata and photos',
      () {
        final json = {
          'Id': 3796,
          'OrganizationId': 19,
          'ZoneId': 13,
          'BranchId': 17,
          'FacilityId': 32,
          'FacilityTypeId': 5,
          'ScheduleId': 14,
          'ScheduleName': 'myp girls washroom',
          'CleaningTemplateId': 22,
          'TemplateVersion': 1,
          'TemplateGroupId': 'def309f5-e733-4b37-b9b6-4bb39ddae149',
          'AssignedRole': 'Fms_Cleaner',
          'AssignedUserId': 4237,
          'AssignedUser': 'Mohan Krishna',
          'ScheduledDate': '2026-08-30',
          'ScheduledStartTime': '06:00',
          'ScheduledEndTime': '08:00',
          'ChecklistSnapshot': [
            {
              'ItemId': 'item-1787900158588-330',
              'Name': 'Dustbins',
              'Description': '',
              'Required': true,
              'Sequence': 1,
            },
          ],
          'ChecklistResults': [
            {
              'ItemId': 'item-1787900158588-330',
              'Name': 'Dustbins',
              'Completed': true,
              'Remarks': '',
              'CompletedAt': '2026-09-01T11:11:54.676Z',
              'BeforePhotos': [],
              'AfterPhotos': [],
            },
          ],
          'BeforePhotos': [
            {'DocumentId': '81fce417-d2fc-4eda-99fd-6c6cad7fef83'},
          ],
          'AfterPhotos': [
            {'DocumentId': '6f095e22-f6ff-4726-8fe4-436e0cb9d5b3'},
          ],
          'Status': 'COMPLETED',
          'CreatedBy': 'SYSTEM_SCHEDULER',
          'CreatedDate': '2026-08-29T18:54:28.136Z',
          'StartedAt': '2026-09-01T11:11:06.188Z',
          'StartedBy': 'Mohan Krishna',
          'StartedByUserId': 4237,
          'UpdatedBy': 'Mohan Krishna',
          'UpdatedDate': '2026-09-01T11:11:54.674Z',
          'CompletedAt': '2026-09-01T11:11:54.677Z',
          'CompletedBy': 'Mohan Krishna',
          'CompletedByUserId': 4237,
          'CompletionRemarks': 'All tasks done cleanly',
        };

        final task = CleaningTask.fromJson(json);

        expect(task.id, equals(3796));
        expect(task.scheduleName, equals('myp girls washroom'));
        expect(task.status, equals('COMPLETED'));
        expect(task.startedBy, equals('Mohan Krishna'));
        expect(task.startedAt, isNotNull);
        expect(task.completedBy, equals('Mohan Krishna'));
        expect(task.completedAt, isNotNull);
        expect(task.completionRemarks, equals('All tasks done cleanly'));
        expect(task.beforePhotos?.length, equals(1));
        expect(
          task.beforePhotos?.first['DocumentId'],
          equals('81fce417-d2fc-4eda-99fd-6c6cad7fef83'),
        );
        expect(task.afterPhotos?.length, equals(1));
        expect(
          task.afterPhotos?.first['DocumentId'],
          equals('6f095e22-f6ff-4726-8fe4-436e0cb9d5b3'),
        );
        expect(task.taskStatus, equals(FacilityTaskStatus.completed));
      },
    );
  });

  group('FacilityTaskStatus Enum & Model Extensions', () {
    test('fromString parses various status string variations correctly', () {
      expect(
        FacilityTaskStatus.fromString('Pending'),
        equals(FacilityTaskStatus.pending),
      );
      expect(
        FacilityTaskStatus.fromString('pending'),
        equals(FacilityTaskStatus.pending),
      );
      expect(
        FacilityTaskStatus.fromString('InProgress'),
        equals(FacilityTaskStatus.inProgress),
      );
      expect(
        FacilityTaskStatus.fromString('in-progress'),
        equals(FacilityTaskStatus.inProgress),
      );
      expect(
        FacilityTaskStatus.fromString('in_progress'),
        equals(FacilityTaskStatus.inProgress),
      );
      expect(
        FacilityTaskStatus.fromString('INPROGRESS'),
        equals(FacilityTaskStatus.inProgress),
      );
      expect(
        FacilityTaskStatus.fromString('Completed'),
        equals(FacilityTaskStatus.completed),
      );
      expect(
        FacilityTaskStatus.fromString('COMPLETED'),
        equals(FacilityTaskStatus.completed),
      );
      expect(
        FacilityTaskStatus.fromString('Skipped'),
        equals(FacilityTaskStatus.skipped),
      );
      expect(
        FacilityTaskStatus.fromString('SKIPPED'),
        equals(FacilityTaskStatus.skipped),
      );
      expect(
        FacilityTaskStatus.fromString('Failed'),
        equals(FacilityTaskStatus.failed),
      );
      expect(
        FacilityTaskStatus.fromString('FAILED'),
        equals(FacilityTaskStatus.failed),
      );
      expect(
        FacilityTaskStatus.fromString('UnknownStatus'),
        equals(FacilityTaskStatus.pending),
      );
      expect(
        FacilityTaskStatus.fromString(null),
        equals(FacilityTaskStatus.pending),
      );
    });

    test('FacilityTask taskStatus property maps accurately', () {
      final task1 = FacilityTask(id: 1, status: 'in-progress');
      expect(task1.taskStatus, equals(FacilityTaskStatus.inProgress));
      expect(task1.taskStatus.isInProgress, isTrue);

      final task2 = FacilityTask(id: 2, status: 'COMPLETED');
      expect(task2.taskStatus, equals(FacilityTaskStatus.completed));
      expect(task2.taskStatus.isCompleted, isTrue);
    });

    test(
      'Facility.fromJson handles null parentFacilityId, location, description gracefully',
      () {
        final json = {
          'Id': 32,
          'ParentFacilityId': null,
          'OrganizationId': 19,
          'BranchId': 17,
          'FacilityTypeId': 5,
          'Code': 'FAC001',
          'Name': 'Ground Floor Restroom',
          'Description': null,
          'Location': null,
          'Capacity': 10,
          'Status': 'ACTIVE',
          'CreatedBy': 'Admin',
          'CreatedDate': null,
        };

        final facility = Facility.fromJson(json);
        expect(facility.id, equals(32));
        expect(facility.parentFacilityId, isNull);
        expect(facility.description, equals(''));
        expect(facility.location, equals(''));
        expect(facility.createdDate, isNull);
        expect(facility.name, equals('Ground Floor Restroom'));
      },
    );

    test(
      'FacilityTasksResponse.fromJson safely handles null data and empty lists',
      () {
        final emptyResponse = FacilityTasksResponse.fromJson({
          'err': false,
          'data': null,
          'pagination': null,
        });
        expect(emptyResponse.data, isEmpty);
        expect(emptyResponse.pagination, isNull);
      },
    );
  });

  group('Negative Caching in getImagesByDocumentIds', () {
    test(
      'records missing document IDs in failed set to avoid duplicate network queries',
      () async {
        fakeApiClient.mockResponse = Response(
          requestOptions: RequestOptions(path: '/v1.0/getImagesByDocumentIds'),
          statusCode: 200,
          data: {
            'err': false,
            'Images': [
              {
                'DocumentId': 'doc_valid',
                'ImageUrl': 'https://example.com/valid.jpg',
              },
            ],
          },
        );

        final result1 = await provider.getImagesByDocumentIds(
          documentIds: ['doc_valid', 'doc_non_existent'],
        );

        expect(result1.length, equals(1));
        expect(result1['doc_valid'], equals('https://example.com/valid.jpg'));

        // Next call requesting the non-existent doc ID should skip network request
        fakeApiClient.mockResponse = null;
        fakeApiClient.capturedPath = null;

        final result2 = await provider.getImagesByDocumentIds(
          documentIds: ['doc_non_existent'],
        );

        expect(result2, isEmpty);
        expect(
          fakeApiClient.capturedPath,
          isNull,
        ); // Skipped because it's in _failedImageDocumentIds
      },
    );
  });
}
