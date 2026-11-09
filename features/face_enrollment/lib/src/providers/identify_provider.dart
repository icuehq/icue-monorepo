import 'package:face_enrollment/src/models/student.dart';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:injectable/injectable.dart';

@injectable
class IdentifyProvider extends ChangeNotifier {
  AttendanceResult? _attendanceResult;
  AttendanceResult? get attendanceResult => _attendanceResult;

  List<Student> _presentStudents = [];
  List<Student> get presentStudents => _presentStudents;

  void setAttendanceResult(AttendanceResult result, List<Student> candidates) {
    _attendanceResult = result;
    final presentIds = result.present.map((e) => e.personId).toSet();
    _presentStudents = candidates
        .where((student) => presentIds.contains(student.id.toString()))
        .toList();
    notifyListeners();
  }
}
