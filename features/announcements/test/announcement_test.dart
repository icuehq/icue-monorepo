import 'package:announcements/announcements.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAnnouncementService implements AnnouncementService {
  List<Announcement> mockAnnouncements = [];
  List<AnnouncementTitle> mockTitles = [];
  bool createFleetSuccess = true;
  CreateAnnouncementRequest? lastCreateRequest;

  @override
  Future<List<Announcement>> getAnnouncements() async {
    return mockAnnouncements;
  }

  @override
  Future<List<AnnouncementTitle>> getAnnouncementTitles() async {
    return mockTitles;
  }

  @override
  Future<bool> createFleetAnnouncement(
    CreateAnnouncementRequest request,
  ) async {
    lastCreateRequest = request;
    return createFleetSuccess;
  }
}

void main() {
  group('Announcement Models Serialization', () {
    test('Announcement deserializes and serializes successfully', () {
      final json = <String, dynamic>{
        '_id': 'ann_123',
        'Id': 42,
        'OrganizationId': 1,
        'ZoneIds': [10, 20],
        'BranchIds': [101, 102],
        'StudentIds': [501, 502],
        'Title': 'School Bus Delayed',
        'Description': 'Bus 4 will arrive 15 minutes late due to traffic.',
        'AnnouncementDate': '2026-10-30',
        'AnnouncementTime': '08:15 AM',
        'ExpiryDate': '2026-10-31',
        'Image': 'https://example.com/bus.png',
        'CreatedBy': 'Admin User',
        'CreatedDate': '2026-10-30T08:15:00.000Z',
        'IsActive': true,
      };

      final announcement = Announcement.fromJson(json);

      expect(announcement.announcementId, equals('ann_123'));
      expect(announcement.id, equals(42));
      expect(announcement.organizationId, equals(1));
      expect(announcement.zoneIds, equals([10, 20]));
      expect(announcement.branchIds, equals([101, 102]));
      expect(announcement.studentIds, equals([501, 502]));
      expect(announcement.title, equals('School Bus Delayed'));
      expect(announcement.description, contains('Bus 4 will arrive'));
      expect(announcement.announcementDate, equals('2026-10-30'));
      expect(announcement.announcementTime, equals('08:15 AM'));
      expect(announcement.expiryDate, equals('2026-10-31'));
      expect(announcement.image, equals('https://example.com/bus.png'));
      expect(announcement.createdBy, equals('Admin User'));
      expect(announcement.createdDate, isNotNull);
      expect(announcement.isActive, isTrue);

      final encoded = announcement.toJson();
      expect(encoded['_id'], equals('ann_123'));
      expect(encoded['Id'], equals(42));
      expect(encoded['Title'], equals('School Bus Delayed'));
      expect(encoded['IsActive'], isTrue);
    });

    test('AnnouncementTitle & Response deserialize and serialize properly', () {
      final responseJson = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'data': [
          {
            'Type': 1,
            'Title': 'Route Delay',
            'DescHeader': 'Dear Parents,',
            'DescBody': 'Route [Route] is running [Minutes] mins late.',
            'DescFooter': 'Regards, Transport Office',
            'Vars': ['Route', 'Minutes'],
            'IsActive': true,
          },
        ],
      };

      final response = AnnouncementTitlesResponse.fromJson(responseJson);
      expect(response.err, isFalse);
      expect(response.message, equals('Success'));
      expect(response.data.length, equals(1));

      final titleItem = response.data.first;
      expect(titleItem.type, equals(1));
      expect(titleItem.title, equals('Route Delay'));
      expect(titleItem.descHeader, equals('Dear Parents,'));
      expect(titleItem.descBody, contains('[Route]'));
      expect(titleItem.descFooter, contains('Regards'));
      expect(titleItem.vars, equals(['Route', 'Minutes']));
      expect(titleItem.isActive, isTrue);

      final encoded = titleItem.toJson();
      expect(encoded['Type'], equals(1));
      expect(encoded['Title'], equals('Route Delay'));
      expect(encoded['Vars'], equals(['Route', 'Minutes']));
    });

    test('CreateAnnouncementRequest serializes correctly', () {
      const request = CreateAnnouncementRequest(
        title: 'Emergency Alert',
        description: 'Severe weather advisory for afternoon drop.',
        mode: 'Drop',
        routes: [10, 11],
        points: ['Gate 1', 'Main Square'],
        studentIds: [1001, 1002],
      );

      final json = request.toJson();
      expect(json['Title'], equals('Emergency Alert'));
      expect(json['Description'], contains('Severe weather advisory'));
      expect(json['Mode'], equals('Drop'));
      expect(json['Routes'], equals([10, 11]));
      expect(json['PickUpPoints'], equals(['Gate 1', 'Main Square']));
      expect(json['StudentIds'], equals([1001, 1002]));
    });
  });

  group('AnnouncementsProvider State Management', () {
    late MockAnnouncementService mockService;
    late AnnouncementsProvider provider;

    setUp(() {
      mockService = MockAnnouncementService();
      provider = AnnouncementsProvider(mockService);
    });

    test('fetchAnnouncements loads announcements and updates state', () async {
      mockService.mockAnnouncements = [
        const Announcement(
          announcementId: '1',
          id: 1,
          title: 'Welcome',
          description: 'Welcome back to school!',
        ),
      ];

      expect(provider.announcements, isEmpty);
      expect(provider.isLoading, isFalse);

      final future = provider.fetchAnnouncements();
      expect(provider.isLoading, isTrue);

      await future;

      expect(provider.isLoading, isFalse);
      expect(provider.announcements.length, equals(1));
      expect(provider.announcements.first.title, equals('Welcome'));
      expect(provider.errorMessage, isNull);
    });

    test('fetchAnnouncementTitles loads template list', () async {
      mockService.mockTitles = [
        const AnnouncementTitle(
          type: 1,
          title: 'Breakdown',
          descHeader: 'Bus',
          descBody: 'Broken down',
          descFooter: 'Sorry',
        ),
      ];

      await provider.fetchAnnouncementTitles();

      expect(provider.isLoading, isFalse);
      expect(provider.announcementTitles.length, equals(1));
      expect(provider.announcementTitles.first.title, equals('Breakdown'));
    });

    test(
      'postAnnouncement delegates to service and reloads announcements',
      () async {
        mockService.mockAnnouncements = [
          const Announcement(
            announcementId: '2',
            id: 2,
            title: 'Updated Alert',
            description: 'Broadcast published.',
          ),
        ];

        const req = CreateAnnouncementRequest(
          title: 'Heavy Traffic',
          description: 'Expect 20 min delay.',
          mode: 'Pickup',
          routes: [5],
        );

        final result = await provider.postAnnouncement(req);

        expect(result, isTrue);
        expect(mockService.lastCreateRequest?.title, equals('Heavy Traffic'));
        expect(provider.announcements.length, equals(1));
        expect(provider.announcements.first.title, equals('Updated Alert'));
        expect(provider.isLoading, isFalse);
      },
    );
  });
}
