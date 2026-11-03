import 'package:flutter/foundation.dart';

@immutable
class Complaint {
  const Complaint({
    required this.id,
    required this.complaintNo,
    required this.vehicleNo,
    required this.categoryName,
    this.details = const <ComplaintDetail>[],
    required this.currStatus,
    required this.currAction,
    this.stsUpdatedDt = '',
    this.stsUpdatedTime = '',
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
    id: json['Id'] as int? ?? 0,
    complaintNo: json['ComplaintNo'] as int? ?? 0,
    vehicleNo: json['VehicleNo'] as String? ?? '',
    categoryName: json['CategoryName'] as String? ?? '',
    details:
        (json['Details'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(ComplaintDetail.fromJson)
            .toList() ??
        const <ComplaintDetail>[],
    currStatus: json['CurrStatus'] as String? ?? 'Open',
    currAction: json['CurrAction'] as String? ?? '',
    stsUpdatedDt: json['StsUpdatedDt'] as String? ?? '',
    stsUpdatedTime: json['StsUpdatedTime'] as String? ?? '',
  );

  final int id;
  final int complaintNo;
  final String vehicleNo;
  final String categoryName;
  final List<ComplaintDetail> details;
  final String currStatus;
  final String currAction;
  final String stsUpdatedDt;
  final String stsUpdatedTime;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'ComplaintNo': complaintNo,
    'VehicleNo': vehicleNo,
    'CategoryName': categoryName,
    'Details': details.map((x) => x.toJson()).toList(),
    'CurrStatus': currStatus,
    'CurrAction': currAction,
    'StsUpdatedDt': stsUpdatedDt,
    'StsUpdatedTime': stsUpdatedTime,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Complaint &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          complaintNo == other.complaintNo;

  @override
  int get hashCode => id.hashCode ^ complaintNo.hashCode;
}

@immutable
class ComplaintDetail {
  const ComplaintDetail({
    this.status = '',
    this.action = '',
    this.date = '',
    this.time = '',
    this.description = '',
    this.createdBy = '',
    this.imageUrls = const <String>[],
  });

  factory ComplaintDetail.fromJson(Map<String, dynamic> json) =>
      ComplaintDetail(
        status: json['Status'] as String? ?? '',
        action: json['Action'] as String? ?? '',
        date: json['Date'] as String? ?? '',
        time: json['Time'] as String? ?? '',
        description: json['Description'] as String? ?? '',
        createdBy: json['CreatedBy'] as String? ?? '',
        imageUrls:
            (json['ImageUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
      );

  final String status;
  final String action;
  final String date;
  final String time;
  final String description;
  final String createdBy;
  final List<String> imageUrls;

  Map<String, dynamic> toJson() => {
    'Status': status,
    'Action': action,
    'Date': date,
    'Time': time,
    'Description': description,
    'CreatedBy': createdBy,
    'ImageUrls': imageUrls,
  };
}

@immutable
class ComplaintDataResponse {
  const ComplaintDataResponse({
    this.err = false,
    this.message = '',
    this.total = 0,
    this.data = const <Complaint>[],
  });

  factory ComplaintDataResponse.fromJson(Map<String, dynamic> json) {
    int totalCount = 0;
    if (json['metadata'] is Map) {
      final meta = json['metadata'] as Map<dynamic, dynamic>;
      totalCount = (meta['total'] as num?)?.toInt() ?? 0;
    }

    return ComplaintDataResponse(
      err: json['err'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      total: totalCount,
      data:
          (json['data'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(Complaint.fromJson)
              .toList() ??
          const <Complaint>[],
    );
  }

  final bool err;
  final String message;
  final int total;
  final List<Complaint> data;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': data.map((x) => x.toJson()).toList(),
  };
}

@immutable
class ComplaintCategory {
  const ComplaintCategory({required this.id, required this.name});

  factory ComplaintCategory.fromJson(Map<String, dynamic> json) =>
      ComplaintCategory(
        id: json['Id'] as int? ?? 0,
        name: json['Name'] as String? ?? '',
      );

  final int id;
  final String name;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplaintCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class ComplaintCategoriesResponse {
  const ComplaintCategoriesResponse({
    this.err = false,
    this.message = '',
    this.data = const <ComplaintCategory>[],
  });

  factory ComplaintCategoriesResponse.fromJson(Map<String, dynamic> json) =>
      ComplaintCategoriesResponse(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        data:
            (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ComplaintCategory.fromJson)
                .toList() ??
            const <ComplaintCategory>[],
      );

  final bool err;
  final String message;
  final List<ComplaintCategory> data;
}
