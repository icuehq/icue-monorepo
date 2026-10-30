class Address {
  const Address({required this.line1, this.line2});

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    line1: json['Line1'] as String? ?? '',
    line2: json['Line2'] as String?,
  );

  final String line1;
  final String? line2;

  Map<String, dynamic> toJson() => {
    'Line1': line1,
    if (line2 != null) 'Line2': line2,
  };
}

class Driver {
  const Driver({
    required this.id,
    required this.firstName,
    this.middleName,
    this.lastName,
    this.mobile,
    this.alternateNumber,
    this.dateOfBirth,
    this.dateOfJoining,
    this.email,
    this.designation,
    this.drivingExperience,
    this.licenceNumber,
    this.licenceIssuedDate,
    this.licenceExpiryDate,
    this.licenceCopy,
    this.healthRecord,
    this.policeRecord,
    this.address = const Address(line1: ''),
    this.city,
    this.state,
    this.country,
    this.pincode,
    this.identificationId,
    this.idType,
    this.enforceChangePassword = false,
    this.userType,
    this.vehicles = const <String>[],
    this.routes = const <String>[],
  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['Id'] as int? ?? 0,
    firstName: json['FirstName'] as String? ?? '',
    middleName: json['MiddleName'] as String?,
    lastName: json['LastName'] as String?,
    mobile: json['Mobile'],
    alternateNumber: json['AlternateNumber'] as int?,
    dateOfBirth: json['DateOfBirth'] as String?,
    dateOfJoining: json['DateOfJoining'] as String?,
    email: json['Email'] as String?,
    designation: json['Designation'],
    drivingExperience: json['DrivingExperience'],
    licenceNumber: json['LicenceNumber'] as String?,
    licenceIssuedDate: json['LicenceIssuedDate'] as String?,
    licenceExpiryDate: json['LicenceExpiryDate'] as String?,
    licenceCopy: json['LicenceCopy'],
    healthRecord: json['HealthRecord'],
    policeRecord: json['PoliceRecord'],
    address: json['Address'] is Map<String, dynamic>
        ? Address.fromJson(json['Address'] as Map<String, dynamic>)
        : const Address(line1: ''),
    city: json['City'] as String?,
    state: json['State'] as String?,
    country: json['Country'] as String?,
    pincode: json['Pincode'],
    identificationId: json['IdentificationId'] as String?,
    idType: json['IdType'] as String?,
    enforceChangePassword: json['EnforceChangePassword'] as bool? ?? false,
    userType: json['UserType'],
    vehicles: json['vehicles'] is List
        ? List<String>.from((json['vehicles'] as List).map((x) => x.toString()))
        : const <String>[],
    routes: json['routes'] is List
        ? List<String>.from((json['routes'] as List).map((x) => x.toString()))
        : const <String>[],
  );

  final int id;
  final String firstName;
  final String? middleName;
  final String? lastName;
  final dynamic mobile;
  final int? alternateNumber;
  final String? dateOfBirth;
  final String? dateOfJoining;
  final dynamic designation;
  final dynamic drivingExperience;
  final String? email;
  final bool enforceChangePassword;
  final dynamic healthRecord;
  final String? idType;
  final String? identificationId;
  final dynamic licenceCopy;
  final String? licenceExpiryDate;
  final String? licenceIssuedDate;
  final String? licenceNumber;
  final Address address;
  final String? city;
  final String? state;
  final String? country;
  final dynamic pincode;
  final dynamic policeRecord;
  final dynamic userType;
  final List<String> vehicles;
  final List<String> routes;

  String get fullName {
    final parts = [
      firstName,
      middleName,
      lastName,
    ].where((p) => p != null && p.trim().isNotEmpty).join(' ');
    return parts.isEmpty ? firstName : parts;
  }

  Map<String, dynamic> toJson() => {
    'Id': id,
    'FirstName': firstName,
    'MiddleName': middleName,
    'LastName': lastName,
    'Mobile': mobile,
    'AlternateNumber': alternateNumber,
    'DateOfBirth': dateOfBirth,
    'DateOfJoining': dateOfJoining,
    'Email': email,
    'Designation': designation,
    'DrivingExperience': drivingExperience,
    'LicenceNumber': licenceNumber,
    'LicenceIssuedDate': licenceIssuedDate,
    'LicenceExpiryDate': licenceExpiryDate,
    'LicenceCopy': licenceCopy,
    'HealthRecord': healthRecord,
    'PoliceRecord': policeRecord,
    'Address': address.toJson(),
    'City': city,
    'State': state,
    'Country': country,
    'Pincode': pincode,
    'IdentificationId': identificationId,
    'IdType': idType,
    'EnforceChangePassword': enforceChangePassword,
    'UserType': userType,
    'vehicles': vehicles,
    'routes': routes,
  };
}
