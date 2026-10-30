import 'package:flutter/foundation.dart';

@immutable
class CreateGatePassRequest {
  const CreateGatePassRequest({
    required this.personId,
    required this.name,
    this.classId = 0,
    this.className = '',
    this.section = '',
    this.admissionNumber = '',
    this.isHostelite = false,
    this.hostelType = 'InCampus',
    this.gatePassDate = '',
    this.gatePassType = '',
    this.personType = 'STUDENT',
    this.rfid = '',
  });

  final String admissionNumber;
  final int classId;
  final String className;
  final String gatePassDate;
  final String gatePassType;
  final String hostelType;
  final bool isHostelite;
  final String name;
  final int personId;
  final String personType;
  final String rfid;
  final String section;

  Map<String, dynamic> toJson() => {
        'ClassId': classId,
        'PersonId': personId,
        'Class': className,
        'Section': section,
        'Name': name,
        'UniqueNo': admissionNumber,
        'IsHostelite': isHostelite,
        'HostelType': hostelType,
        'GatePassDate': gatePassDate,
        'GatePassType': gatePassType,
        'RFID': rfid,
        'PersonType': personType,
      };
}
