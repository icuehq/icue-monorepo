import 'package:flutter/foundation.dart';

@immutable
class ExpenseType {
  const ExpenseType({
    required this.expenseType,
    required this.expenseTypeDesc,
    required this.code,
    this.subItems = false,
    this.expenseTypeDetails = const <ExpenseTypeDetail>[],
    this.isMode = false,
    this.modes = const <ExpenseMode>[],
  });

  factory ExpenseType.fromJson(Map<String, dynamic> json) => ExpenseType(
        expenseType: json['ExpenseType'] as int? ?? 0,
        expenseTypeDesc: json['ExpenseTypeDesc'] as String? ?? '',
        code: json['Code'] as String? ?? '',
        subItems: json['SubItems'] as bool? ?? false,
        expenseTypeDetails: (json['ExpenseTypeDetails'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ExpenseTypeDetail.fromJson)
                .toList() ??
            const <ExpenseTypeDetail>[],
        isMode: json['IsMode'] as bool? ?? false,
        modes: (json['Modes'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ExpenseMode.fromJson)
                .toList() ??
            const <ExpenseMode>[],
      );

  final int expenseType;
  final String expenseTypeDesc;
  final String code;
  final bool subItems;
  final List<ExpenseTypeDetail> expenseTypeDetails;
  final bool isMode;
  final List<ExpenseMode> modes;

  Map<String, dynamic> toJson() => {
        'ExpenseType': expenseType,
        'ExpenseTypeDesc': expenseTypeDesc,
        'Code': code,
        'SubItems': subItems,
        'ExpenseTypeDetails':
            expenseTypeDetails.map((x) => x.toJson()).toList(),
        'IsMode': isMode,
        'Modes': modes.map((x) => x.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseType &&
          runtimeType == other.runtimeType &&
          expenseType == other.expenseType &&
          code == other.code;

  @override
  int get hashCode => expenseType.hashCode ^ code.hashCode;
}

@immutable
class ExpenseTypeDetail {
  const ExpenseTypeDetail({
    required this.id,
    required this.name,
    required this.code,
    this.details = const <Detail>[],
    this.type = 'text',
    this.isRequired = false,
    this.regexPattern,
  });

  factory ExpenseTypeDetail.fromJson(Map<String, dynamic> json) =>
      ExpenseTypeDetail(
        id: json['Id'] as int? ?? 0,
        name: json['Name'] as String? ?? '',
        code: json['Code'] as String? ?? '',
        details: (json['Details'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(Detail.fromJson)
                .toList() ??
            const <Detail>[],
        type: json['Type'] as String? ?? 'text',
        isRequired: json['IsRequired'] as bool? ?? false,
        regexPattern: json['RegexPattern'] as String?,
      );

  final int id;
  final String name;
  final String code;
  final List<Detail> details;
  final String type;
  final bool isRequired;
  final String? regexPattern;

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Code': code,
        'Details': details.map((x) => x.toJson()).toList(),
        'Type': type,
        'IsRequired': isRequired,
        'RegexPattern': ?regexPattern,
      };
}

@immutable
class Detail {
  const Detail({
    required this.id,
    required this.name,
  });

  factory Detail.fromJson(Map<String, dynamic> json) => Detail(
        id: json['Id'],
        name: json['Name'] as String? ?? '',
      );

  final dynamic id;
  final String name;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Detail &&
          runtimeType == other.runtimeType &&
          id.toString() == other.id.toString() &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

@immutable
class ExpenseMode {
  const ExpenseMode({
    required this.id,
    required this.name,
    required this.code,
  });

  factory ExpenseMode.fromJson(Map<String, dynamic> json) => ExpenseMode(
        id: json['Id'] as int? ?? 0,
        name: json['Name'] as String? ?? '',
        code: json['Code'] as String? ?? '',
      );

  final int id;
  final String name;
  final String code;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name, 'Code': code};
}
