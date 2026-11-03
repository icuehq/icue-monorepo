import 'package:drivers/src/models/driver.dart';

class AddDriverRequest {
  const AddDriverRequest({
    this.source = 'adminapp',
    this.id,
    this.organizationId,
    this.zoneId,
    this.branchId,
    required this.firstName,
    this.middleName,
    this.lastName,
    required this.mobile,
    this.alternateNumber,
    this.email,
    this.address,
    this.dateOfBirth,
    this.dateOfJoining,
    this.country,
    this.state,
    this.city,
    this.pincode,
    this.idType,
    this.drivingExperience,
    this.licenceNumber,
    this.licenceIssuedDate,
    this.licenceExpiryDate,
  });

  factory AddDriverRequest.fromJson(Map<String, dynamic> json) =>
      AddDriverRequest(
        source: json['Source'] as String? ?? 'adminapp',
        id: json['Id'] as int?,
        organizationId: json['OrganizationId'] as int?,
        zoneId: json['ZoneId'] as int?,
        branchId: json['BranchId'] as int?,
        firstName: json['FirstName'] as String? ?? '',
        middleName: json['MiddleName'] as String?,
        lastName: json['LastName'] as String?,
        mobile: json['Mobile'],
        alternateNumber: json['AlternateNumber'] as int?,
        email: json['Email'] as String?,
        address: json['Address'] is Map<String, dynamic>
            ? Address.fromJson(json['Address'] as Map<String, dynamic>)
            : null,
        dateOfBirth: json['DateOfBirth'] as String?,
        dateOfJoining: json['DateOfJoining'] as String?,
        country: json['Country'] as String?,
        state: json['State'] as String?,
        city: json['City'] as String?,
        pincode: json['Pincode'],
        idType: json['IdType'] as String?,
        drivingExperience: json['DrivingExperience'],
        licenceNumber: json['LicenceNumber'] as String?,
        licenceIssuedDate: json['LicenceIssuedDate'] as String?,
        licenceExpiryDate: json['LicenceExpiryDate'] as String?,
      );

  final String source;
  final int? id;
  final int? organizationId;
  final int? zoneId;
  final int? branchId;
  final String firstName;
  final String? middleName;
  final String? lastName;
  final dynamic mobile;
  final int? alternateNumber;
  final String? email;
  final Address? address;
  final String? dateOfBirth;
  final String? dateOfJoining;
  final String? country;
  final String? state;
  final String? city;
  final dynamic pincode;
  final String? idType;
  final dynamic drivingExperience;
  final String? licenceNumber;
  final String? licenceIssuedDate;
  final String? licenceExpiryDate;

  Map<String, dynamic> toJson() => {
    'Source': source,
    if (id != null) 'Id': id,
    if (organizationId != null) 'OrganizationId': organizationId,
    if (zoneId != null) 'ZoneId': zoneId,
    if (branchId != null) 'BranchId': branchId,
    'FirstName': firstName,
    'MiddleName': middleName,
    'LastName': lastName,
    'Mobile': mobile,
    'AlternateNumber': alternateNumber,
    'Email': email,
    'Address': address?.toJson() ?? const Address(line1: '').toJson(),
    'DateOfBirth': dateOfBirth,
    'DateOfJoining': dateOfJoining,
    'Country': country,
    'State': state,
    'City': city,
    'Pincode': pincode,
    'IdType': idType,
    'DrivingExperience': drivingExperience,
    'LicenceNumber': licenceNumber,
    'LicenceIssuedDate': licenceIssuedDate,
    'LicenceExpiryDate': licenceExpiryDate,
  };
}
