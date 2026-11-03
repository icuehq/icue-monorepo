import 'package:expenses/expenses.dart';
import 'package:flutter_test/flutter_test.dart';

class MockExpenseService implements ExpenseService {
  List<ExpenseType> mockExpenseTypes = [];
  List<Detail> mockCategories = [];
  List<Detail> mockSubCategories = [];
  List<Storage> mockStorages = [];
  bool updateSelfFillingSuccess = true;
  bool storeExpenseSuccess = true;
  StoreExpenseRequest? lastStoreRequest;
  SelfFillingStatusRequest? lastStatusRequest;

  @override
  Future<List<ExpenseType>> getExpenseTypes() async => mockExpenseTypes;

  @override
  Future<List<Detail>> getExpenseCategories() async => mockCategories;

  @override
  Future<List<Detail>> getExpenseSubCategories(int categoryId) async =>
      mockSubCategories;

  @override
  Future<List<Storage>> getFuelStorages(String? fuelType) async => mockStorages;

  @override
  Future<bool> updateSelfFillingStatus(SelfFillingStatusRequest request) async {
    lastStatusRequest = request;
    return updateSelfFillingSuccess;
  }

  @override
  Future<Map<String, dynamic>?> generateRefNo(
    Map<String, dynamic> data, {
    List<int>? odometerBytes,
    String? odometerName,
  }) async {
    return {'RefNo': 'REF-12345', 'BillAmount': '500'};
  }

  @override
  Future<String?> generateBillNo(String billDate) async => 'AUTO-BILL-99';

  @override
  Future<bool> storeExpense(StoreExpenseRequest request) async {
    lastStoreRequest = request;
    return storeExpenseSuccess;
  }
}

void main() {
  group('Expense Models Serialization', () {
    test('ExpenseType deserializes and serializes successfully', () {
      final json = <String, dynamic>{
        'ExpenseType': 1,
        'ExpenseTypeDesc': 'Battery',
        'Code': 'battery',
        'SubItems': false,
        'IsMode': false,
        'ExpenseTypeDetails': [
          {
            'Id': 101,
            'Name': 'Battery Capacity',
            'Code': 'BatteryCapacity',
            'Type': 'text',
            'IsRequired': true,
            'RegexPattern': r'^[0-9]+Ah$',
            'Details': [
              {'Id': 1, 'Name': '100Ah'},
            ],
          },
        ],
        'Modes': [
          {'Id': 5, 'Name': 'Full Replacement', 'Code': 'replace'},
        ],
      };

      final expenseType = ExpenseType.fromJson(json);

      expect(expenseType.expenseType, equals(1));
      expect(expenseType.expenseTypeDesc, equals('Battery'));
      expect(expenseType.code, equals('battery'));
      expect(expenseType.subItems, isFalse);
      expect(expenseType.expenseTypeDetails.length, equals(1));

      final detail = expenseType.expenseTypeDetails.first;
      expect(detail.id, equals(101));
      expect(detail.name, equals('Battery Capacity'));
      expect(detail.isRequired, isTrue);
      expect(detail.regexPattern, equals(r'^[0-9]+Ah$'));
      expect(detail.details.length, equals(1));
      expect(detail.details.first.name, equals('100Ah'));

      expect(expenseType.modes.length, equals(1));
      expect(expenseType.modes.first.code, equals('replace'));

      final encoded = expenseType.toJson();
      expect(encoded['Code'], equals('battery'));
      expect(encoded['ExpenseType'], equals(1));
    });

    test('ExpenseCategoryResponse parses categories record', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Loaded',
        'Record': [
          {'Id': 1, 'Name': 'Engine Oil'},
          {'Id': 2, 'Name': 'Brake Pads'},
        ],
      };

      final resp = ExpenseCategoryResponse.fromJson(json);
      expect(resp.err, isFalse);
      expect(resp.record.length, equals(2));
      expect(resp.record.first.name, equals('Engine Oil'));
      expect(resp.record.last.id, equals(2));
    });

    test('FuelStorageResponse parses fuel storage tanks and pumps', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'toFill': true,
        'data': [
          {
            'Type': 'Tank',
            'Items': [
              {
                'Name': 'Diesel Tank 1',
                'Capacity': 5000,
                'FuelType': 'Diesel',
                'FuelPrice': '94.50',
                'Type': 'Storage',
              },
            ],
          },
        ],
      };

      final resp = FuelStorageResponse.fromJson(json);
      expect(resp.err, isFalse);
      expect(resp.toFill, isTrue);
      expect(resp.data.length, equals(1));

      final item = resp.data.first.items.first;
      expect(item.name, equals('Diesel Tank 1'));
      expect(item.capacity, equals(5000));
      expect(item.fuelPrice, equals('94.50'));
    });
  });

  group('ExpenseProvider State Management', () {
    late MockExpenseService mockService;
    late ExpenseProvider provider;

    setUp(() {
      mockService = MockExpenseService();
      provider = ExpenseProvider(mockService);
    });

    test('fetchExpenseTypes loads types into provider', () async {
      mockService.mockExpenseTypes = [
        const ExpenseType(
          expenseType: 1,
          expenseTypeDesc: 'Tyres',
          code: 'tyres',
        ),
      ];

      expect(provider.expenseTypes, isEmpty);
      await provider.fetchExpenseTypes();

      expect(provider.isLoading, isFalse);
      expect(provider.expenseTypes.length, equals(1));
      expect(provider.expenseTypes.first.code, equals('tyres'));
    });

    test('fetchExpenseCategories and subcategories updates lists', () async {
      mockService.mockCategories = [
        const Detail(id: 10, name: 'Periodic Service'),
      ];
      mockService.mockSubCategories = [
        const Detail(id: 101, name: 'Coolant Change'),
      ];

      await provider.fetchExpenseCategories();
      expect(provider.categories.length, equals(1));

      await provider.fetchExpenseSubCategories(10);
      expect(provider.subCategories.length, equals(1));
      expect(provider.subCategories.first.name, equals('Coolant Change'));
    });

    test('fetchFuelStorages populates storage tanks', () async {
      mockService.mockStorages = [
        const Storage(
          type: 'Pump',
          items: [StorageItem(name: 'Pump 1', capacity: 1000)],
        ),
      ];

      await provider.fetchFuelStorages('Diesel');
      expect(provider.fuelStorages.length, equals(1));
      expect(provider.fuelStorages.first.items.first.name, equals('Pump 1'));
    });

    test(
      'updateSelfFillingStatus persists start gauge reading and calls service',
      () async {
        const request = SelfFillingStatusRequest(
          fuelType: 'Diesel',
          gaugeMode: 'start',
          startReading: '12450.5',
        );

        final success = await provider.updateSelfFillingStatus(request);
        expect(success, isTrue);
        expect(provider.startGaugeReading, equals('12450.5'));
        expect(mockService.lastStatusRequest?.startReading, equals('12450.5'));
      },
    );

    test(
      'submitExpense delegates to service and tracks filled vehicle',
      () async {
        const request = StoreExpenseRequest(
          vehicleNumber: 'AP29AB1234',
          expenseType: ExpenseType(
            expenseType: 2,
            expenseTypeDesc: 'Maintenance',
            code: 'maintenance',
          ),
          billDate: '2026-10-30',
          billAmount: '1500',
          vendorName: 'Bosch Auto Care',
        );

        final success = await provider.submitExpense(request);
        expect(success, isTrue);
        expect(
          mockService.lastStoreRequest?.vehicleNumber,
          equals('AP29AB1234'),
        );
        expect(provider.filledVehicleNumbers, contains('AP29AB1234'));
      },
    );
  });
}
