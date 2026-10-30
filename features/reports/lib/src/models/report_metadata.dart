import 'package:flutter/foundation.dart';

/// Common metadata returned in paginated report endpoints.
@immutable
class ReportMetadata {
  const ReportMetadata({
    this.total = 0,
    this.page = 1,
    this.pageSize = 10,
  });

  factory ReportMetadata.fromJson(Map<String, dynamic> json) => ReportMetadata(
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pagesize'] as num?)?.toInt() ?? 10,
      );

  final int total;
  final int page;
  final int pageSize;

  Map<String, dynamic> toJson() => {
        'total': total,
        'page': page,
        'pagesize': pageSize,
      };
}
