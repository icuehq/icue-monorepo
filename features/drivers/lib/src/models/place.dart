import 'package:flutter/foundation.dart';

/// A country or one of its child places (state), from the places API.
@immutable
class Place {
  const Place({required this.id, required this.name});

  factory Place.fromJson(Map<String, dynamic> json) =>
      Place(id: '${json['_id'] ?? ''}', name: json['Name'] as String? ?? '');

  final String id;
  final String name;
}
