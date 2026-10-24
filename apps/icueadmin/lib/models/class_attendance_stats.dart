import 'meta_data.dart';

class ClassAttendanceStatsResponse {
  const ClassAttendanceStatsResponse({
    this.metadata,
    this.data = const [],
    this.err = false,
    this.message = '',
  });

  factory ClassAttendanceStatsResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawMetadata = json['metadata'];

    return ClassAttendanceStatsResponse(
      metadata: rawMetadata is Map<String, dynamic>
          ? Metadata.fromJson(rawMetadata)
          : null,
      data: rawData is List
          ? rawData
                .whereType<Map<String, dynamic>>()
                .map(ClassAttendanceStatItem.fromJson)
                .toList()
          : const [],
      err: json['err'] == true,
      message: json['message']?.toString() ?? '',
    );
  }

  final List<ClassAttendanceStatItem> data;
  final bool err;
  final String message;
  final Metadata? metadata;

  Map<String, dynamic> toJson() => {
    if (metadata != null) 'metadata': metadata!.toJson(),
    'data': data.map((e) => e.toJson()).toList(),
    'err': err,
    'message': message,
  };
}

class ClassAttendanceStatItem {
  const ClassAttendanceStatItem({
    required this.standard,
    required this.section,
    required this.period,
    required this.total,
    required this.date,
    required this.presentees,
    required this.absentees,
    required this.attdPercent,
    this.classId,
  });

  factory ClassAttendanceStatItem.fromJson(Map<String, dynamic> json) {
    return ClassAttendanceStatItem(
      standard: json['Standard']?.toString() ?? '',
      section: json['Section']?.toString() ?? '',
      period: json['Period']?.toString() ?? '',
      total: (json['Total'] as num?)?.toInt() ?? 0,
      date: json['Date']?.toString() ?? '',
      presentees: (json['Presentees'] as num?)?.toInt() ?? 0,
      absentees: (json['Absentees'] as num?)?.toInt() ?? 0,
      attdPercent: (json['AttdPercent'] as num?)?.toDouble() ?? 0.0,
      classId: (json['ClassId'] as num?)?.toInt(),
    );
  }

  final int absentees;
  final double attdPercent;
  final int? classId;
  final String date;
  final String period;
  final int presentees;
  final String section;
  final String standard;
  final int total;

  ClassAttendanceStatItem copyWith({
    String? standard,
    String? section,
    String? period,
    int? total,
    String? date,
    int? presentees,
    int? absentees,
    double? attdPercent,
    int? classId,
  }) {
    return ClassAttendanceStatItem(
      standard: standard ?? this.standard,
      section: section ?? this.section,
      period: period ?? this.period,
      total: total ?? this.total,
      date: date ?? this.date,
      presentees: presentees ?? this.presentees,
      absentees: absentees ?? this.absentees,
      attdPercent: attdPercent ?? this.attdPercent,
      classId: classId ?? this.classId,
    );
  }

  Map<String, dynamic> toJson() => {
    'Standard': standard,
    'Section': section,
    'Period': period,
    'Total': total,
    'Date': date,
    'Presentees': presentees,
    'Absentees': absentees,
    'AttdPercent': attdPercent,
    if (classId != null) 'ClassId': classId,
  };
}
