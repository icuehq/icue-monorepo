class Docs {
  const Docs({
    required this.recordId,
    required this.type,
    this.rcNumber,
    this.rcStartDate,
    this.rcExpiryDate,
    required this.docUrl,
    required this.contentType,
    this.insuranceNumber,
    this.insuredDate,
    this.insuranceExpiryDate,
    this.fitnessNumber,
    this.fitnessStartDate,
    this.fitnessExpiryDate,
    this.roadTaxNumber,
    this.roadTaxStartDate,
    this.roadTaxExpiryDate,
    this.pollutionNumber,
    this.pollutionStartDate,
    this.pollutionExpiryDate,
    this.permitNumber,
    this.permitStartDate,
    this.permitExpiryDate,
  });

  factory Docs.fromJson(Map<String, dynamic> json) => Docs(
        recordId: json['RecordId'] as int? ?? 0,
        type: json['Type'] as String? ?? '',
        rcNumber: json['RCNumber'] as String?,
        rcStartDate: json['RCStartDate'] as String?,
        rcExpiryDate: json['RCExpiryDate'] as String?,
        docUrl: json['DocUrl'] as String? ?? '',
        contentType: json['ContentType'] as String? ?? '',
        insuranceNumber: json['InsuranceNumber'] as String?,
        insuredDate: json['InsuredDate'] as String?,
        insuranceExpiryDate: json['InsuranceExpiryDate'] as String?,
        fitnessNumber: json['FitnessNumber'] as String?,
        fitnessStartDate: json['FitnessStartDate'] as String?,
        fitnessExpiryDate: json['FitnessExpiryDate'] as String?,
        roadTaxNumber: json['RoadTaxNumber'] as String?,
        roadTaxStartDate: json['RoadTaxStartDate'] as String?,
        roadTaxExpiryDate: json['RoadTaxExpiryDate'] as String?,
        pollutionNumber: json['PollutionNumber'] as String?,
        pollutionStartDate: json['PollutionStartDate'] as String?,
        pollutionExpiryDate: json['PollutionExpiryDate'] as String?,
        permitNumber: json['PermitNumber'] as String?,
        permitStartDate: json['PermitStartDate'] as String?,
        permitExpiryDate: json['PermitExpiryDate'] as String?,
      );

  final int recordId;
  final String type;
  final String? rcNumber;
  final String? rcStartDate;
  final String? rcExpiryDate;
  final String docUrl;
  final String contentType;
  final String? insuranceNumber;
  final String? insuredDate;
  final String? insuranceExpiryDate;
  final String? fitnessNumber;
  final String? fitnessStartDate;
  final String? fitnessExpiryDate;
  final String? roadTaxNumber;
  final String? roadTaxStartDate;
  final String? roadTaxExpiryDate;
  final String? pollutionNumber;
  final String? pollutionStartDate;
  final String? pollutionExpiryDate;
  final String? permitNumber;
  final String? permitStartDate;
  final String? permitExpiryDate;

  Map<String, dynamic> toJson() => {
        'RecordId': recordId,
        'Type': type,
        'RCNumber': rcNumber,
        'RCStartDate': rcStartDate,
        'RCExpiryDate': rcExpiryDate,
        'DocUrl': docUrl,
        'ContentType': contentType,
        'InsuranceNumber': insuranceNumber,
        'InsuredDate': insuredDate,
        'InsuranceExpiryDate': insuranceExpiryDate,
        'FitnessNumber': fitnessNumber,
        'FitnessStartDate': fitnessStartDate,
        'FitnessExpiryDate': fitnessExpiryDate,
        'RoadTaxNumber': roadTaxNumber,
        'RoadTaxStartDate': roadTaxStartDate,
        'RoadTaxExpiryDate': roadTaxExpiryDate,
        'PollutionNumber': pollutionNumber,
        'PollutionStartDate': pollutionStartDate,
        'PollutionExpiryDate': pollutionExpiryDate,
        'PermitNumber': permitNumber,
        'PermitStartDate': permitStartDate,
        'PermitExpiryDate': permitExpiryDate,
      };
}

class VehicleDocs {
  const VehicleDocs({
    this.err = false,
    this.message = '',
    this.docs,
  });

  factory VehicleDocs.fromJson(Map<String, dynamic> json) => VehicleDocs(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        docs: json['docs'] is Map<String, dynamic>
            ? Docs.fromJson(json['docs'] as Map<String, dynamic>)
            : null,
      );

  final bool err;
  final String message;
  final Docs? docs;

  Map<String, dynamic> toJson() => {
        'err': err,
        'message': message,
        'docs': docs?.toJson(),
      };
}
