import 'package:flutter/foundation.dart';

@immutable
class FuelStorageResponse {
  const FuelStorageResponse({
    this.err = false,
    this.message = '',
    this.toFill,
    this.data = const <Storage>[],
  });

  factory FuelStorageResponse.fromJson(Map<String, dynamic> json) =>
      FuelStorageResponse(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        toFill: json['toFill'] as bool?,
        data:
            (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(Storage.fromJson)
                .toList() ??
            const <Storage>[],
      );

  final bool err;
  final String message;
  final bool? toFill;
  final List<Storage> data;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'toFill': ?toFill,
    'data': data.map((x) => x.toJson()).toList(),
  };
}

@immutable
class Storage {
  const Storage({required this.type, this.items = const <StorageItem>[]});

  factory Storage.fromJson(Map<String, dynamic> json) => Storage(
    type: json['Type'] as String? ?? '',
    items:
        (json['Items'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(StorageItem.fromJson)
            .toList() ??
        const <StorageItem>[],
  );

  final String type;
  final List<StorageItem> items;

  Map<String, dynamic> toJson() => {
    'Type': type,
    'Items': items.map((x) => x.toJson()).toList(),
  };
}

@immutable
class StorageItem {
  const StorageItem({
    required this.name,
    this.capacity = 0,
    this.fuelType,
    this.fuelPrice,
    this.type,
  });

  factory StorageItem.fromJson(Map<String, dynamic> json) => StorageItem(
    name: json['Name'] as String? ?? '',
    capacity: json['Capacity'] as int? ?? 0,
    fuelType: json['FuelType'] as String?,
    fuelPrice: json['FuelPrice'] as String?,
    type: json['Type'] as String?,
  );

  final String name;
  final int capacity;
  final String? fuelType;
  final String? fuelPrice;
  final String? type;

  Map<String, dynamic> toJson() => {
    'Name': name,
    'Capacity': capacity,
    'FuelType': ?fuelType,
    'FuelPrice': ?fuelPrice,
    'Type': ?type,
  };
}
