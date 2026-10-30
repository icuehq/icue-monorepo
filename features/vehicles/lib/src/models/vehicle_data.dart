class FirstAidKit {
  const FirstAidKit({
    this.id,
    this.medicineDetails,
    this.medicineExpiryDate,
  });

  factory FirstAidKit.fromJson(Map<String, dynamic> json) => FirstAidKit(
        id: json['Id'] as int?,
        medicineDetails: json['MedicineDetails'] as String?,
        medicineExpiryDate: json['MedicineExpiryDate'] as String?,
      );

  final int? id;
  final String? medicineDetails;
  final String? medicineExpiryDate;

  Map<String, dynamic> toJson() => {
        if (id != null) 'Id': id,
        'MedicineDetails': medicineDetails,
        'MedicineExpiryDate': medicineExpiryDate,
      };
}

class VehicleData {
  const VehicleData({
    this.id,
    required this.number,
    this.driverId,
    this.driverName,
    this.driverNumber,
    this.capacity,
    this.dashcamId,
    this.isEnabledBluetoothDevice,
    this.colour,
    this.vendorId,
    this.make,
    this.airCondition,
    this.model,
    this.year,
    this.chasisNumber,
    this.insuranceCopy,
    this.serviceDate,
    this.companyClaimedMileage,
    this.actualExpectedMileage,
    this.fuelType,
    this.insuranceNumber,
    this.insuredDate,
    this.insuranceExpiryDate,
    this.rcNumber,
    this.rcStartDate,
    this.rcExpiryDate,
    this.fitnessNumber,
    this.fitnessStartDate,
    this.fitnessExpiryDate,
    this.roadTaxNumber,
    this.roadTaxStartDate,
    this.roadTaxExpiryDate,
    this.pollutionExpiryDate,
    this.permitNumber,
    this.permitStartDate,
    this.permitExpiryDate,
    this.pollutionNumber,
    this.pollutionStartDate,
    this.engineNumber,
    this.rtaOfcName,
    this.dateOfReg,
    this.fireExtName,
    this.fireExtInstallDate,
    this.fireExtExpiryDate,
    this.firstAidKit = const <FirstAidKit>[],
    this.routes = const <String>[],
  });

  factory VehicleData.fromJson(Map<String, dynamic> json) => VehicleData(
        id: json['Id'] as int?,
        number: json['Number'] as String? ?? '',
        driverId: json['DriverId'] as int?,
        driverName: json['DriverName'] as String?,
        driverNumber: json['DriverNumber'],
        capacity: json['Capacity'],
        dashcamId: json['DashcamId'] as String?,
        isEnabledBluetoothDevice: json['IsEnabledBluetoothDevice'] as bool?,
        colour: json['Colour'] as String?,
        vendorId: json['VendorId'],
        make: json['Make'] as String?,
        airCondition: json['AirCondition'] as String?,
        model: json['Model'] as String?,
        year: json['Year'] as String?,
        chasisNumber: json['ChasisNumber'] as String?,
        insuranceCopy: json['InsuranceCopy'],
        serviceDate: json['ServiceDate'] as String?,
        companyClaimedMileage: json['CompanyClaimedMileage'],
        actualExpectedMileage: json['ActualExpectedMileage'],
        fuelType: json['FuelType'] as String?,
        insuranceNumber: json['InsuranceNumber'] as String?,
        insuredDate: json['InsuredDate'] as String?,
        insuranceExpiryDate: json['InsuranceExpiryDate'] as String?,
        rcNumber: json['RCNumber'] as String?,
        rcStartDate: json['RCStartDate'] as String?,
        rcExpiryDate: json['RCExpiryDate'] as String?,
        fitnessNumber: json['FitnessNumber'] as String?,
        fitnessStartDate: json['FitnessStartDate'] as String?,
        fitnessExpiryDate: json['FitnessExpiryDate'] as String?,
        roadTaxNumber: json['RoadTaxNumber'] as String?,
        roadTaxStartDate: json['RoadTaxStartDate'] as String?,
        roadTaxExpiryDate: json['RoadTaxExpiryDate'] as String?,
        pollutionExpiryDate: json['PollutionExpiryDate'] as String?,
        permitNumber: json['PermitNumber'] as String?,
        permitStartDate: json['PermitStartDate'] as String?,
        permitExpiryDate: json['PermitExpiryDate'] as String?,
        pollutionNumber: json['PollutionNumber'] as String?,
        pollutionStartDate: json['PollutionStartDate'] as String?,
        engineNumber: json['EngineNumber'] as String?,
        rtaOfcName: json['RtaOfcName'] as String?,
        dateOfReg: json['DateOfReg'] as String?,
        fireExtName: json['FireExtName'] as String?,
        fireExtInstallDate: json['FireExtInstallDate'] as String?,
        fireExtExpiryDate: json['FireExtExpiryDate'] as String?,
        firstAidKit: json['FirstAidKit'] is List
            ? (json['FirstAidKit'] as List)
                .whereType<Map<String, dynamic>>()
                .map(FirstAidKit.fromJson)
                .toList()
            : const <FirstAidKit>[],
        routes: json['routes'] is List
            ? List<String>.from((json['routes'] as List).map((x) => x.toString()))
            : const <String>[],
      );

  final int? id;
  final String number;
  final int? driverId;
  final String? driverName;
  final dynamic driverNumber;
  final dynamic capacity;
  final String? dashcamId;
  final bool? isEnabledBluetoothDevice;
  final String? colour;
  final dynamic vendorId;
  final String? make;
  final String? airCondition;
  final String? model;
  final String? year;
  final String? chasisNumber;
  final dynamic insuranceCopy;
  final String? serviceDate;
  final dynamic companyClaimedMileage;
  final dynamic actualExpectedMileage;
  final String? fuelType;
  final String? insuranceNumber;
  final String? insuredDate;
  final String? insuranceExpiryDate;
  final String? rcNumber;
  final String? rcStartDate;
  final String? rcExpiryDate;
  final String? fitnessNumber;
  final String? fitnessStartDate;
  final String? fitnessExpiryDate;
  final String? roadTaxNumber;
  final String? roadTaxStartDate;
  final String? roadTaxExpiryDate;
  final String? pollutionExpiryDate;
  final String? permitNumber;
  final String? permitStartDate;
  final String? permitExpiryDate;
  final String? pollutionNumber;
  final String? pollutionStartDate;
  final String? engineNumber;
  final String? rtaOfcName;
  final String? dateOfReg;
  final String? fireExtName;
  final String? fireExtInstallDate;
  final String? fireExtExpiryDate;
  final List<FirstAidKit> firstAidKit;
  final List<String> routes;

  Map<String, dynamic> toJson() => {
        if (id != null) 'Id': id,
        'Number': number,
        'DriverId': driverId,
        'DriverName': driverName,
        'DriverNumber': driverNumber,
        'Capacity': capacity,
        'DashcamId': dashcamId,
        'IsEnabledBluetoothDevice': isEnabledBluetoothDevice,
        'Colour': colour,
        'VendorId': vendorId,
        'Make': make,
        'AirCondition': airCondition,
        'Model': model,
        'Year': year,
        'ChasisNumber': chasisNumber,
        'InsuranceCopy': insuranceCopy,
        'ServiceDate': serviceDate,
        'CompanyClaimedMileage': companyClaimedMileage,
        'ActualExpectedMileage': actualExpectedMileage,
        'FuelType': fuelType,
        'InsuranceNumber': insuranceNumber,
        'InsuredDate': insuredDate,
        'InsuranceExpiryDate': insuranceExpiryDate,
        'RCNumber': rcNumber,
        'RCStartDate': rcStartDate,
        'RCExpiryDate': rcExpiryDate,
        'FitnessNumber': fitnessNumber,
        'FitnessStartDate': fitnessStartDate,
        'FitnessExpiryDate': fitnessExpiryDate,
        'RoadTaxNumber': roadTaxNumber,
        'RoadTaxStartDate': roadTaxStartDate,
        'RoadTaxExpiryDate': roadTaxExpiryDate,
        'PollutionExpiryDate': pollutionExpiryDate,
        'PermitNumber': permitNumber,
        'PermitStartDate': permitStartDate,
        'PermitExpiryDate': permitExpiryDate,
        'PollutionNumber': pollutionNumber,
        'PollutionStartDate': pollutionStartDate,
        'EngineNumber': engineNumber,
        'RtaOfcName': rtaOfcName,
        'DateOfReg': dateOfReg,
        'FireExtName': fireExtName,
        'FireExtInstallDate': fireExtInstallDate,
        'FireExtExpiryDate': fireExtExpiryDate,
        'FirstAidKit': firstAidKit.map((x) => x.toJson()).toList(),
        'routes': routes,
      };
}
