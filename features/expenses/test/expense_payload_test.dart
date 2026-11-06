import 'package:api_client/api_client.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingApiClient extends Fake implements ApiClient {
  final calls = <String, Map<String, dynamic>>{};

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    calls[path] = data is FormData
        ? {for (final field in data.fields) field.key: field.value}
        : Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
    final body = switch (path) {
      '/v1.0/addExpense' => {
        'err': false,
        'data': {'RefNo': 'R1', 'BillAmount': '900'},
      },
      '/v1.0/generateBillNo' => {'BillNo': 'B1'},
      _ => {'err': false},
    };
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

ExpenseType _type(String code) =>
    ExpenseType(expenseType: 3, expenseTypeDesc: code, code: code);

void main() {
  test('tyre expense sends the legacy backend keys', () async {
    final client = _RecordingApiClient();
    await ExpenseService(client).storeExpense(
      StoreExpenseRequest(
        vehicleNumber: 'AP1',
        expenseType: _type('tyres'),
        billDate: '03/05/2025',
        billAmount: '1200',
        speedometer: '500',
        extraFields: const {
          'Type': 'New',
          'TyreName': 'MRF',
          'TyreNo': '10x20',
          'Warranty': '12',
          'FixedDate': '03/05/2025',
        },
      ),
    );
    final stored = client.calls['/v1.0/storeExpense']!;
    expect(
      stored.keys,
      containsAll([
        'Type',
        'TyreName',
        'TyreNo',
        'Warranty',
        'FixedDate',
        'Speedometer',
        'BillAmount',
        'RefNo',
      ]),
    );
    expect(stored.keys, isNot(contains('TyreBrand')));
  });

  test('fuel expense sends no amount; the server computes it', () async {
    final client = _RecordingApiClient();
    await ExpenseService(client).storeExpense(
      StoreExpenseRequest(
        vehicleNumber: 'AP1',
        expenseType: _type('fuel'),
        billDate: '03/05/2025',
        billAmount: '',
        mode: 'FuelStation',
        fuelType: 'Diesel',
        extraFields: const {'KM': '1000', 'FuelFilled': '40'},
      ),
    );
    final added = client.calls['/v1.0/addExpense']!;
    expect(added.keys, isNot(contains('BillAmount')));
    expect(added['KM'], '1000');
    expect(client.calls['/v1.0/storeExpense']!['BillAmount'], '900');
  });

  test('self-filling status uses a single File part and US date', () async {
    final client = _RecordingApiClient();
    await ExpenseService(client).updateSelfFillingStatus(
      const SelfFillingStatusRequest(
        fuelType: 'DIESEL',
        gaugeMode: 'start',
        gaugeFileBytes: [1, 2],
        billFileBytes: [3],
      ),
    );
    final sent = client.calls['/v1.0/updateSelfFillingStatus']!;
    expect(sent['TransDate'], matches(RegExp(r'^\d{2}/\d{2}/\d{4}$')));
    expect(sent['ImgUpload'], 'ALL');
  });

  test('loose fuel sends storage keys and no vehicle number', () async {
    final client = _RecordingApiClient();
    await ExpenseService(client).storeExpense(
      StoreExpenseRequest(
        vehicleNumber: '',
        expenseType: _type('loosefuel'),
        billDate: '03/05/2025',
        billAmount: '400',
        fuelType: 'DIESEL',
        extraFields: const {
          'StorType': 'Tank',
          'StorName': 'T1',
          'StorCap': 1000,
          'FuelFilled': '4',
          'PricePerLitre': '100',
        },
      ),
    );
    final stored = client.calls['/v1.0/storeExpense']!;
    expect(stored.keys, isNot(contains('VehicleNumber')));
    expect(stored['StorName'], 'T1');
    expect(stored['PricePerLitre'], '100');
  });
}
