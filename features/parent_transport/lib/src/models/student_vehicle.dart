/// A private vehicle a parent registered for the student (`/v2.0/getStudentVehicles`).
class StudentVehicle {
  const StudentVehicle({required this.id, required this.vehicleNumber});

  factory StudentVehicle.fromJson(Map<String, dynamic> json) => StudentVehicle(
    id: (json['Id'] as num).toInt(),
    vehicleNumber: json['VehicleNo'] as String? ?? '',
  );

  final int id;
  final String vehicleNumber;
}
