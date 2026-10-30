import 'package:vehicles/src/models/vehicle_data.dart';

class AddVehicleRequest {
  const AddVehicleRequest({
    this.source = 'adminapp',
    this.id,
    this.organizationId,
    this.zoneId,
    this.branchId,
    required this.number,
    required this.fuelType,
    this.companyClaimedMileage,
    this.actualExpectedMileage,
    this.driverId,
    this.driverNumber,
    this.driverName,
    this.airCondition = 'No',
    this.chasisNumber,
    this.engineNumber,
    this.year,
    this.rtaOfcName,
    this.dateOfReg,
    this.model,
    this.make,
    this.capacity,
    this.serviceDate,
    this.colour,
    this.fireExtName,
    this.fireExtInstallDate,
    this.fireExtExpiryDate,
    this.firstAidKit = const <FirstAidKit>[],
    this.dashCamId,
  });

  factory AddVehicleRequest.fromJson(Map<String, dynamic> json) =>
      AddVehicleRequest(
        source: json['Source'] as String? ?? 'adminapp',
        id: json['Id'] as int?,
        dashCamId: json['DashcamId'] as String?,
        organizationId: json['OrganizationId'] as int?,
        zoneId: json['ZoneId'] as int?,
        branchId: json['BranchId'] as int?,
        number: json['Number'] as String? ?? '',
        fuelType: json['FuelType'] as String? ?? 'Diesel',
        companyClaimedMileage: json['CompanyClaimedMileage'],
        actualExpectedMileage: json['ActualExpectedMileage'],
        driverId: json['DriverId'] as int?,
        driverNumber: json['DriverNumber'],
        driverName: json['DriverName'] as String?,
        airCondition: json['AirCondition'] as String? ?? 'No',
        chasisNumber: json['ChasisNumber'] as String?,
        engineNumber: json['EngineNumber'] as String?,
        year: json['Year'] as String?,
        rtaOfcName: json['RtaOfcName'] as String?,
        dateOfReg: json['DateOfReg'] as String?,
        model: json['Model'] as String?,
        make: json['Make'] as String?,
        capacity: json['Capacity'],
        serviceDate: json['ServiceDate'] as String?,
        colour: json['Colour'] as String?,
        fireExtName: json['FireExtName'] as String?,
        fireExtInstallDate: json['FireExtInstallDate'] as String?,
        fireExtExpiryDate: json['FireExtExpiryDate'] as String?,
        firstAidKit: json['FirstAidKit'] is List
            ? (json['FirstAidKit'] as List)
                .whereType<Map<String, dynamic>>()
                .map(FirstAidKit.fromJson)
                .toList()
            : const <FirstAidKit>[],
      );

  final String source;
  final int? id;
  final String? dashCamId;
  final int? organizationId;
  final int? zoneId;
  final int? branchId;
  final String number;
  final String fuelType;
  final dynamic companyClaimedMileage;
  final dynamic actualExpectedMileage;
  final int? driverId;
  final dynamic driverNumber;
  final String? driverName;
  final String airCondition;
  final String? chasisNumber;
  final String? engineNumber;
  final String? year;
  final String? rtaOfcName;
  final String? dateOfReg;
  final String? model;
  final String? make;
  final dynamic capacity;
  final String? serviceDate;
  final String? colour;
  final String? fireExtName;
  final String? fireExtInstallDate;
  final String? fireExtExpiryDate;
  final List<FirstAidKit> firstAidKit;

  Map<String, dynamic> toJson() => {
        'Source': source,
        if (id != null) 'Id': id,
        if (dashCamId != null) 'DashcamId': dashCamId,
        if (organizationId != null) 'OrganizationId': organizationId,
        if (zoneId != null) 'ZoneId': zoneId,
        if (branchId != null) 'BranchId': branchId,
        'Number': number,
        'FuelType': fuelType,
        'CompanyClaimedMileage': companyClaimedMileage,
        'ActualExpectedMileage': actualExpectedMileage,
        'DriverId': driverId,
        'DriverNumber': driverNumber,
        'DriverName': driverName,
        'AirCondition': airCondition,
        'ChasisNumber': chasisNumber,
        'EngineNumber': engineNumber,
        'Year': year,
        'RtaOfcName': rtaOfcName,
        'DateOfReg': dateOfReg,
        'Model': model,
        'Make': make,
        'Capacity': capacity,
        'ServiceDate': serviceDate,
        'Colour': colour,
        'FireExtName': fireExtName,
        'FireExtInstallDate': fireExtInstallDate,
        'FireExtExpiryDate': fireExtExpiryDate,
        'FirstAidKit': firstAidKit.map((x) => x.toJson()).toList(),
      };
}
