import 'package:flutter_test/flutter_test.dart';
import 'package:icue_sdk/src/models/announcements.dart';
import 'package:icue_sdk/src/models/route_coordinates.dart';
import 'package:icue_sdk/src/models/route_notifications.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/models/vehicle_location.dart';

void main() {
  group('Model Deserialization & Coordinate Bounds Tests', () {
    test(
        'User.fromJson parses valid SchoolPoint and rejects invalid coordinates',
        () {
      final validUserJson = {
        'Id': 1,
        'Name': 'John',
        'RollNo': '10',
        'AdmissionNumber': 'ADM001',
        'ClassId': 2,
        'Standard': '2',
        'Section': 'A',
        'Gender': 'M',
        'ParentName': 'Parent',
        'OrganizationId': 100,
        'BranchId': 10,
        'ZoneId': 1,
        'SchoolPoint': [17.4065, 78.4772],
      };

      final user = User.fromJson(validUserJson);
      expect(user.schoolPoint, isNotNull);
      expect(user.schoolPoint!.length, equals(2));
      expect(user.schoolPoint![0], closeTo(17.4065, 1e-4));
      expect(user.schoolPoint![1], closeTo(78.4772, 1e-4));

      // Test with single coordinate element (should be rejected/null)
      final invalidUserJson = {
        ...validUserJson,
        'SchoolPoint': [17.4065],
      };
      final userInvalid = User.fromJson(invalidUserJson);
      expect(userInvalid.schoolPoint, isNull);

      // Test with null SchoolPoint
      final nullPointUser = User.fromJson({
        ...validUserJson,
        'SchoolPoint': null,
      });
      expect(nullPointUser.schoolPoint, isNull);
    });

    test('VehicleLocation.fromJson filters out invalid coordinate pairs', () {
      final json = {
        'RouteDetailsId': 12,
        'RouteNo': 'R-12',
        'coordinates': [
          [17.4065, 78.4772], // valid
          [999.0, 78.4772], // invalid latitude (>90)
          [17.4065], // incomplete
          ['17.4080', '78.4790'], // valid string numbers
        ],
        'CoordinatesTime': '10:00:00',
        'CoordinatesSpeed': 25.5,
        'ServerTime': '10:00:02',
        'RouteTrackId': 101,
        'enableLocationPush': true,
        'enableLocPush': true,
        'MsgAvailable': true,
        'MsgCount': 2,
        'IsETAPush': true,
        'IsETAFetch': true,
      };

      final vehicleLoc = VehicleLocation.fromJson(json);
      expect(vehicleLoc.coordinates.length, equals(2));
      expect(vehicleLoc.coordinates[0], equals([17.4065, 78.4772]));
      expect(vehicleLoc.coordinates[1], equals([17.4080, 78.4790]));
    });

    test('RouteCoordinates.fromJson parses offlineCoordinates safely', () {
      final json = {
        'err': false,
        'OfflineCoordinates': [
          [17.4000, 78.4000],
          [17.4100, 78.4100],
        ],
        'DefaultRouteDate': '2026-08-29',
      };

      final routeCoords = RouteCoordinates.fromJson(json);
      expect(routeCoords.err, isFalse);
      expect(routeCoords.offlineCoordinates.length, equals(2));
      expect(routeCoords.defaultRouteDate, equals('2026-08-29'));
    });

    test('RouteNotifications and Announcements safely handle non-string fields',
        () {
      final notifJson = {
        'err': false,
        'message': 12345, // numeric message
        'msgs': [
          {'msg': 'Bus departed', 'at': '08:30 AM'},
          {'msg': 999, 'at': 123456}, // non-string msg and at
        ],
      };

      final notifs = RouteNotifications.fromJson(notifJson);
      expect(notifs.message, equals('12345'));
      expect(notifs.msgs.length, equals(2));
      expect(notifs.msgs[1].msg, equals('999'));
      expect(notifs.msgs[1].at, equals('123456'));

      final announcementJson = {
        'Title': 'School Notice',
        'Description': 42,
        'AnnouncementDate': '2026-08-29',
        'AnnouncementTime': 1030,
      };

      final announcement = Announcements.fromJson(announcementJson);
      expect(announcement.title, equals('School Notice'));
      expect(announcement.description, equals('42'));
      expect(announcement.announcementTime, equals('1030'));
    });
  });
}
