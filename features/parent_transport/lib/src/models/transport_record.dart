/// One bus pickup/drop event of the student (`/getStuTransportInfo`).
class TransportRecord {
  const TransportRecord({
    required this.id,
    required this.routeNo,
    required this.mode,
    required this.date,
    required this.time,
    required this.message,
  });

  factory TransportRecord.fromJson(Map<String, dynamic> json) =>
      TransportRecord(
        id: (json['Id'] as num).toInt(),
        routeNo: json['RouteNo'] as String? ?? '',
        mode: json['Mode'] as String? ?? '',
        date: json['Date'] as String? ?? '',
        time: json['Time'] as String? ?? '',
        message: json['Msg'] as String? ?? '',
      );

  final int id;
  final String routeNo;
  final String mode;
  final String date;
  final String time;
  final String message;

  bool get isPickup => mode.toLowerCase().contains('pickup');
}
