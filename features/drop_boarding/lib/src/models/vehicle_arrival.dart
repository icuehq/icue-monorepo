class VehicleArrival {
  const VehicleArrival({
    required this.id,
    required this.routeNo,
    required this.vehicleNumber,
    required this.status,
    this.boardingType,
  });

  factory VehicleArrival.fromJson(Map<String, dynamic> json) => VehicleArrival(
    id: json['RouteId'] as int? ?? 0,
    routeNo: json['RouteNo'] as String? ?? '',
    vehicleNumber: json['VehicleNumber'] as String? ?? '',
    status: json['Status'] as String? ?? '',
    boardingType: json['BoardingType'] as String?,
  );

  final int id;
  final String routeNo;
  final String vehicleNumber;
  final String status;
  final String? boardingType;

  Map<String, dynamic> toJson() => {
    'RouteId': id,
    'RouteNo': routeNo,
    'VehicleNumber': vehicleNumber,
    'Status': status,
    if (boardingType != null) 'BoardingType': boardingType,
  };
}

class VehicleArrivalsResponse {
  const VehicleArrivalsResponse({
    required this.err,
    required this.message,
    this.data = const <VehicleArrival>[],
  });

  factory VehicleArrivalsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'];
    return VehicleArrivalsResponse(
      err: json['err'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: list is List
          ? list
                .whereType<Map<String, dynamic>>()
                .map(VehicleArrival.fromJson)
                .toList()
          : const <VehicleArrival>[],
    );
  }

  final bool err;
  final String message;
  final List<VehicleArrival> data;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': data.map((x) => x.toJson()).toList(),
  };
}
