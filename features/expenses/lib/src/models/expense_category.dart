import 'package:expenses/src/models/expense_type.dart';
import 'package:flutter/foundation.dart';

@immutable
class ExpenseCategoryResponse {
  const ExpenseCategoryResponse({
    this.err = false,
    this.message = '',
    this.record = const <Detail>[],
  });

  factory ExpenseCategoryResponse.fromJson(Map<String, dynamic> json) =>
      ExpenseCategoryResponse(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        record:
            (json['Record'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(Detail.fromJson)
                .toList() ??
            const <Detail>[],
      );

  final bool err;
  final String message;
  final List<Detail> record;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'Record': record.map((x) => x.toJson()).toList(),
  };
}
