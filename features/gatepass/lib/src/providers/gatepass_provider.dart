import 'package:flutter/foundation.dart';
import 'package:gatepass/src/models/create_gatepass_request.dart';
import 'package:gatepass/src/models/gatepass_request.dart';
import 'package:gatepass/src/models/gatepass_type.dart';
import 'package:gatepass/src/services/gatepass_service.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

@lazySingleton
class GatePassProvider extends ChangeNotifier {
  GatePassProvider(this._gatePassService);

  final GatePassService _gatePassService;

  bool _isLoading = false;
  String? _errorMessage;

  List<GatePassType> _gatepassTypes = <GatePassType>[];
  List<GatePassRequest> _requests = <GatePassRequest>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<GatePassType> get gatepassTypes => List.unmodifiable(_gatepassTypes);
  List<GatePassRequest> get requests => List.unmodifiable(_requests);

  void clearData() {
    _requests.clear();
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetches available gate pass types and categories (cached in-memory).
  Future<void> fetchGatePassTypes() async {
    if (_gatepassTypes.isNotEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _gatepassTypes = await _gatePassService.getGatePassTypes();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches pending gate pass requests for the chosen date.
  Future<void> fetchGatePassRequests(DateTime date) async {
    _isLoading = true;
    _errorMessage = null;
    _requests.clear();
    notifyListeners();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      _requests = await _gatePassService.getGatePassRequests(dateStr);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Issues a new gate pass. Returns true on success.
  Future<bool> issueGatePass(CreateGatePassRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _gatePassService.issueGatePass(request);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approves or rejects a gate pass request.
  Future<bool> updateGatePassStatus({
    required int id,
    required int personId,
    required String date,
    required String status,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _gatePassService.updateGatePassStatus(
        id: id,
        personId: personId,
        date: date,
        status: status,
      );
      if (success) {
        _requests.removeWhere((r) => r.id == id);
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
