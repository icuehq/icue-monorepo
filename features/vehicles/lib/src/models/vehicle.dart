class Vehicle {
  const Vehicle({
    required this.id,
    required this.number,
    this.driverId,
    this.driverName,
    this.driverNumber,
    this.capacity,
    this.fuelType,
    this.price,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['Id'] as int? ?? 0,
    number: json['Number'] as String? ?? '',
    driverId: json['DriverId'] as num?,
    driverName: json['DriverName'] as String?,
    driverNumber: json['DriverNumber'],
    capacity: json['Capacity'],
    fuelType: json['FuelType'],
    price: json['Price'] as String?,
  );

  final int id;
  final String number;
  final num? driverId;
  final String? driverName;
  final dynamic driverNumber;
  final dynamic capacity;
  final dynamic fuelType;
  final String? price;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Number': number,
    'DriverId': driverId,
    'DriverName': driverName,
    'DriverNumber': driverNumber,
    'Capacity': capacity,
    'FuelType': fuelType,
    'Price': price,
  };
}

class VehicleDetails {
  const VehicleDetails({
    this.vehicleDetailsId,
    required this.id,
    this.organizationId,
    this.zoneId,
    this.branchId,
    required this.number,
    this.driverId,
    this.driverName,
    this.driverNumber,
    this.vendorId,
    this.make,
    this.model,
    this.colour,
    this.year,
    this.chasisNumber,
    this.insuranceNumber,
    this.insuredDate,
    this.insuranceExpiryDate,
    this.insuranceCopy,
    this.rcExpiryDate,
    this.serviceDate,
    this.capacity,
    this.status,
    this.isActive = true,
    this.lastUpdatedOn,
    this.updatedBy,
    this.carrierId,
    this.dashcamId,
    this.isEnabledBluetoothDevice,
  });

  factory VehicleDetails.fromJson(Map<String, dynamic> json) => VehicleDetails(
    vehicleDetailsId: json['_id'],
    id: json['Id'] as int? ?? 0,
    organizationId: json['OrganizationId'] as int?,
    zoneId: json['ZoneId'] as int?,
    branchId: json['BranchId'] as int?,
    number: json['Number'] as String? ?? '',
    driverId: json['DriverId'] as int?,
    driverName: json['DriverName'] as String?,
    driverNumber: json['DriverNumber'],
    vendorId: json['VendorId'],
    make: json['Make'] as String?,
    model: json['Model'] as String?,
    colour: json['Colour'] as String?,
    year: json['Year'] as String?,
    chasisNumber: json['ChasisNumber'] as String?,
    insuranceNumber: json['InsuranceNumber'] as String?,
    insuredDate: json['InsuredDate'] as String?,
    insuranceExpiryDate: json['InsuranceExpiryDate'] as String?,
    insuranceCopy: json['InsuranceCopy'],
    rcExpiryDate: json['RCExpiryDate'] as String?,
    serviceDate: json['ServiceDate'] as String?,
    capacity: json['Capacity'],
    status: json['Status'] as String?,
    isActive: json['IsActive'] as bool? ?? true,
    lastUpdatedOn: json['LastUpdatedOn'] != null
        ? DateTime.tryParse(json['LastUpdatedOn'].toString())
        : null,
    updatedBy: json['UpdatedBy'] as String?,
    carrierId: json['CarrierId'],
    dashcamId: json['DashcamId'],
    isEnabledBluetoothDevice: json['IsEnabledBluetoothDevice'],
  );

  final dynamic vehicleDetailsId;
  final int id;
  final int? organizationId;
  final int? zoneId;
  final int? branchId;
  final String number;
  final int? driverId;
  final String? driverName;
  final dynamic driverNumber;
  final dynamic vendorId;
  final String? make;
  final String? model;
  final String? colour;
  final String? year;
  final String? chasisNumber;
  final String? insuranceNumber;
  final String? insuredDate;
  final String? insuranceExpiryDate;
  final dynamic insuranceCopy;
  final String? rcExpiryDate;
  final String? serviceDate;
  final dynamic capacity;
  final String? status;
  final bool isActive;
  final DateTime? lastUpdatedOn;
  final String? updatedBy;
  final dynamic carrierId;
  final dynamic dashcamId;
  final dynamic isEnabledBluetoothDevice;

  Map<String, dynamic> toJson() => {
    '_id': vehicleDetailsId,
    'Id': id,
    'OrganizationId': organizationId,
    'ZoneId': zoneId,
    'BranchId': branchId,
    'Number': number,
    'DriverId': driverId,
    'DriverName': driverName,
    'DriverNumber': driverNumber,
    'VendorId': vendorId,
    'Make': make,
    'Model': model,
    'Colour': colour,
    'Year': year,
    'ChasisNumber': chasisNumber,
    'InsuranceNumber': insuranceNumber,
    'InsuredDate': insuredDate,
    'InsuranceExpiryDate': insuranceExpiryDate,
    'InsuranceCopy': insuranceCopy,
    'RCExpiryDate': rcExpiryDate,
    'ServiceDate': serviceDate,
    'Capacity': capacity,
    'Status': status,
    'IsActive': isActive,
    'LastUpdatedOn': lastUpdatedOn?.toIso8601String(),
    'UpdatedBy': updatedBy,
    'CarrierId': carrierId,
    'DashcamId': dashcamId,
    'IsEnabledBluetoothDevice': isEnabledBluetoothDevice,
  };
}
