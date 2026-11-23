import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_connect/src/models/complaint.dart';
import 'package:school_connect/src/models/event_payment.dart';
import 'package:school_connect/src/models/event_timing.dart';
import 'package:school_connect/src/services/school_connect_service.dart';

class _FakeApiClient extends Fake implements ApiClient {
  @override
  T parse<T>(Response<dynamic> response, T Function(dynamic data) fromJson) =>
      fromJson(response.data);

  dynamic body;
  String? lastPath;
  Map<String, dynamic>? lastData;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastPath = path;
    lastData = data as Map<String, dynamic>?;
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  group('event timing', () {
    final today = DateTime(2026, 3, 10, 15);

    test('parses dd-MMM-yyyy and rejects other text', () {
      expect(parseEventDate('07-Mar-2026'), DateTime(2026, 3, 7));
      expect(parseEventDate('2026-03-07'), isNull);
      expect(parseEventDate(''), isNull);
    });

    test('phase is upcoming, happening now, ended or unknown', () {
      final upcoming = eventPhase(DateTime(2026, 3, 12), null, today);
      expect(upcoming.phase, EventPhase.upcoming);
      expect(upcoming.daysToGo, 2);
      expect(
        eventPhase(DateTime(2026, 3, 10), DateTime(2026, 3, 10), today).phase,
        EventPhase.happeningNow,
      );
      expect(
        eventPhase(DateTime(2026, 3), DateTime(2026, 3, 9), today).phase,
        EventPhase.ended,
      );
      expect(eventPhase(null, null, today).phase, EventPhase.unknown);
    });

    test('duration counts both days', () {
      expect(eventDurationDays(DateTime(2026, 3), DateTime(2026, 3, 3)), 3);
      expect(eventDurationDays(null, DateTime(2026, 3)), isNull);
    });

    test('payment date accepts both server formats', () {
      expect(
        parsePaymentDateTime('03/07/2026', '14:30'),
        DateTime(2026, 3, 7, 14, 30),
      );
      expect(
        parsePaymentDateTime('07-03-2026', '14:30'),
        DateTime(2026, 3, 7, 14, 30),
      );
      expect(parsePaymentDateTime('soon', '14:30'), isNull);
    });
  });

  test('ComplaintStatus maps codes and falls back to open', () {
    expect(ComplaintStatus.fromCode(2), ComplaintStatus.resolved);
    expect(ComplaintStatus.fromCode(9), ComplaintStatus.open);
  });

  test('EventPaymentPage parses totals and nested bookings', () {
    final page = EventPaymentPage.fromJson({
      'metadata': {'total': 12},
      'data': [
        {
          'Id': 1,
          'EventName': 'Fete',
          'PaymentStatus': 'Completed',
          'Amount': 105.5,
          'StuNames': ['Asha'],
          'Events': [
            {
              'AttendDate': '07-Mar-2026',
              'NoOfPersonAttend': 2,
              'CustomQnsAns': [
                {'Id': 1, 'Qns': 'Diet?', 'Ans': 'Veg'},
              ],
            },
          ],
        },
      ],
    });
    expect(page.total, 12);
    expect(page.payments.single.bookings.single.answers.single.answer, 'Veg');
    expect(page.payments.single.amount, 105.5);
  });

  group('SchoolConnectService', () {
    test('getComplaints keeps the server spelling PrimayContact', () async {
      final api = _FakeApiClient()..body = <dynamic>[];
      await SchoolConnectService(api)
          .getComplaints(studentId: 4, primaryContact: '9000000000');
      expect(api.lastData, {'StudentId': 4, 'PrimayContact': '9000000000'});
    });

    test('getEntryQrCode reads data.QRCode', () async {
      final api = _FakeApiClient()
        ..body = {
          'data': {'QRCode': 'abc'},
        };
      expect(
        await SchoolConnectService(api)
            .getEntryQrCode(studentId: 1, admissionNumber: 'A'),
        'abc',
      );
    });

    test('getEventPayments sends paging', () async {
      final api = _FakeApiClient()..body = {'data': <dynamic>[]};
      await SchoolConnectService(api)
          .getEventPayments(studentId: 1, admissionNumber: 'A', page: 3);
      expect(api.lastData?['PageNumber'], 3);
      expect(api.lastData?['PageSize'], 10);
    });
  });
}
