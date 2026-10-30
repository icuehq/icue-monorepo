import 'package:flutter/foundation.dart';

@immutable
class ComplaintsDashboardResponse {
  const ComplaintsDashboardResponse({
    this.err = false,
    this.message = '',
    this.total = 0,
    this.data = const <ComplaintDashboardItem>[],
  });

  factory ComplaintsDashboardResponse.fromJson(Map<String, dynamic> json) {
    int totalCount = 0;
    if (json['metadata'] is Map) {
      final meta = json['metadata'] as Map<dynamic, dynamic>;
      totalCount = (meta['total'] as num?)?.toInt() ?? 0;
    }

    return ComplaintsDashboardResponse(
      err: json['err'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      total: totalCount,
      data: (json['data'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ComplaintDashboardItem.fromJson)
              .toList() ??
          const <ComplaintDashboardItem>[],
    );
  }

  final bool err;
  final String message;
  final int total;
  final List<ComplaintDashboardItem> data;
}

@immutable
class ComplaintDashboardItem {
  const ComplaintDashboardItem({
    required this.totalCount,
    this.status,
    this.category,
    this.categoryId,
    this.vehicle,
    this.vehicleId,
    this.statuses = const <ComplaintStatusCount>[],
  });

  factory ComplaintDashboardItem.fromJson(Map<String, dynamic> json) =>
      ComplaintDashboardItem(
        totalCount: json['TotalCount'] as int? ?? 0,
        status: json['Status'] as String?,
        category: json['Category'] as String?,
        categoryId: json['CategoryId'] as int?,
        vehicle: json['Vehicle'] as String?,
        vehicleId: json['VehicleId'] as int?,
        statuses: (json['Statuses'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ComplaintStatusCount.fromJson)
                .toList() ??
            const <ComplaintStatusCount>[],
      );

  final int totalCount;
  final String? status;
  final String? category;
  final int? categoryId;
  final String? vehicle;
  final int? vehicleId;
  final List<ComplaintStatusCount> statuses;

  Map<String, dynamic> toJson() => {
        'TotalCount': totalCount,
        'Status': ?status,
        'Category': ?category,
        'CategoryId': ?categoryId,
        'Vehicle': ?vehicle,
        'VehicleId': ?vehicleId,
        'Statuses': statuses.map((x) => x.toJson()).toList(),
      };
}

@immutable
class ComplaintStatusCount {
  const ComplaintStatusCount({
    required this.status,
    required this.count,
  });

  factory ComplaintStatusCount.fromJson(Map<String, dynamic> json) =>
      ComplaintStatusCount(
        status: json['Status'] as String? ?? '',
        count: json['Count'] as int? ?? 0,
      );

  final String status;
  final int count;

  Map<String, dynamic> toJson() => {
        'Status': status,
        'Count': count,
      };
}
