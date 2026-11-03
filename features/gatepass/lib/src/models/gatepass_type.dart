import 'package:flutter/foundation.dart';

@immutable
class GatePassType {
  const GatePassType({
    required this.id,
    required this.category,
    required this.displayName,
  });

  factory GatePassType.fromJson(Map<String, dynamic> json) => GatePassType(
    id: (json['Id'] as num?)?.toInt() ?? 0,
    category: json['Category'] as String? ?? '',
    displayName: json['DisplayName'] as String? ?? '',
  );

  final String category;
  final String displayName;
  final int id;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Category': category,
    'DisplayName': displayName,
  };
}

@immutable
class GatePassTypesResponse {
  const GatePassTypesResponse({
    this.err = false,
    this.message = '',
    this.data = const <GatePassType>[],
  });

  factory GatePassTypesResponse.fromJson(Map<String, dynamic> json) =>
      GatePassTypesResponse(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        data:
            (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(GatePassType.fromJson)
                .toList() ??
            const <GatePassType>[],
      );

  final List<GatePassType> data;
  final bool err;
  final String message;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': data.map((x) => x.toJson()).toList(),
  };
}
