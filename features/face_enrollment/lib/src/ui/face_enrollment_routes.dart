import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/ui/screens/embedding_screen.dart';
import 'package:face_enrollment/src/ui/screens/identify_screen.dart';
import 'package:face_enrollment/src/ui/screens/student_list_screen.dart';
import 'package:go_router/go_router.dart';

abstract final class FaceEnrollmentRoutes {
  static const students = '/students';
  static const embedding = '/students/embedding';
  static const identify = '/students/identify';
}

List<RouteBase> faceEnrollmentRoutes() => [
  GoRoute(
    path: FaceEnrollmentRoutes.students,
    builder: (context, state) => const StudentListScreen(),
  ),
  GoRoute(
    path: FaceEnrollmentRoutes.embedding,
    builder: (context, state) =>
        EmbeddingScreen(student: state.extra! as Student),
  ),
  GoRoute(
    path: FaceEnrollmentRoutes.identify,
    builder: (context, state) => const IdentifyScreen(),
  ),
];
