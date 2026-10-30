import 'package:flutter/foundation.dart';

@immutable
class AnnouncementTitlesResponse {
  const AnnouncementTitlesResponse({
    this.err = false,
    this.message = '',
    this.data = const <AnnouncementTitle>[],
  });

  factory AnnouncementTitlesResponse.fromJson(Map<String, dynamic> json) {
    return AnnouncementTitlesResponse(
      err: json['err'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AnnouncementTitle.fromJson)
              .toList() ??
          const <AnnouncementTitle>[],
    );
  }

  final bool err;
  final String message;
  final List<AnnouncementTitle> data;

  Map<String, dynamic> toJson() => {
        'err': err,
        'message': message,
        'data': data.map((x) => x.toJson()).toList(),
      };
}

@immutable
class AnnouncementTitle {
  const AnnouncementTitle({
    this.type = 0,
    required this.title,
    this.descHeader = '',
    this.descBody = '',
    this.descFooter = '',
    this.vars = const <String>[],
    this.isActive = true,
  });

  factory AnnouncementTitle.fromJson(Map<String, dynamic> json) {
    return AnnouncementTitle(
      type: json['Type'] as int? ?? 0,
      title: json['Title'] as String? ?? '',
      descHeader: json['DescHeader'] as String? ?? '',
      descBody: json['DescBody'] as String? ?? '',
      descFooter: json['DescFooter'] as String? ?? '',
      vars: (json['Vars'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      isActive: json['IsActive'] as bool? ?? true,
    );
  }

  final int type;
  final String title;
  final String descHeader;
  final String descBody;
  final String descFooter;
  final List<String> vars;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'Type': type,
        'Title': title,
        'DescHeader': descHeader,
        'DescBody': descBody,
        'DescFooter': descFooter,
        'Vars': vars,
        'IsActive': isActive,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementTitle &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          title == other.title;

  @override
  int get hashCode => type.hashCode ^ title.hashCode;
}
