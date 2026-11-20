import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:school_connect/src/models/event_payment.dart';
import 'package:school_connect/src/models/school_event.dart';
import 'package:school_connect/src/services/school_connect_service.dart';

@lazySingleton
class EventsProvider extends ChangeNotifier {
  EventsProvider(this._service, this._auth);

  final SchoolConnectService _service;
  final ParentAuthProvider _auth;

  List<SchoolEvent> events = <SchoolEvent>[];
  String? qrCode;
  List<EventPayment> payments = <EventPayment>[];
  int paymentTotal = 0;
  bool loading = false;
  bool loadingMore = false;
  int _page = 1;

  bool get hasMorePayments => payments.length < paymentTotal;

  Future<void> loadEvents() async {
    final student = _auth.selectedStudent;
    if (student == null) return;
    loading = true;
    notifyListeners();
    try {
      events = await _service.getEvents(
        studentId: student.id,
        loggedInContact: _auth.mobile,
        admissionNumber: student.admissionNumber,
      );
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadQrCode() async {
    final student = _auth.selectedStudent;
    if (student == null) return;
    qrCode = null;
    loading = true;
    notifyListeners();
    try {
      qrCode = await _service.getEntryQrCode(
        studentId: student.id,
        admissionNumber: student.admissionNumber,
      );
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Loads the first page, replacing the list.
  Future<void> loadPayments() async {
    payments = <EventPayment>[];
    paymentTotal = 0;
    _page = 1;
    loading = true;
    notifyListeners();
    await _fetchPayments();
    loading = false;
    notifyListeners();
  }

  Future<void> loadMorePayments() async {
    if (loading || loadingMore || !hasMorePayments) return;
    loadingMore = true;
    _page++;
    notifyListeners();
    await _fetchPayments();
    loadingMore = false;
    notifyListeners();
  }

  Future<void> _fetchPayments() async {
    final student = _auth.selectedStudent;
    if (student == null) return;
    try {
      final page = await _service.getEventPayments(
        studentId: student.id,
        admissionNumber: student.admissionNumber,
        page: _page,
      );
      payments = [...payments, ...page.payments];
      paymentTotal = page.total;
    } on ApiException {
      if (_page > 1) _page--;
    }
  }
}
