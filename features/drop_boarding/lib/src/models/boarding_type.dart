class BoardingType {
  const BoardingType({
    required this.id,
    required this.name,
  });

  factory BoardingType.fromJson(Map<String, dynamic> json) => BoardingType(
        id: json['Id']?.toString() ?? '',
        name: json['Name'] as String? ?? '',
      );

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
      };
}

class BoardingTypesResponse {
  const BoardingTypesResponse({
    required this.err,
    required this.message,
    this.data = const <BoardingType>[],
  });

  factory BoardingTypesResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'];
    return BoardingTypesResponse(
      err: json['err'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(BoardingType.fromJson)
              .toList()
          : const <BoardingType>[],
    );
  }

  final bool err;
  final String message;
  final List<BoardingType> data;

  Map<String, dynamic> toJson() => {
        'err': err,
        'message': message,
        'data': data.map((x) => x.toJson()).toList(),
      };
}
