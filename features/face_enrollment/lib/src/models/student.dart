/// A student row from `/v1.0/getStudentPhotos`.
class Student {
  const Student({
    required this.id,
    required this.name,
    required this.admissionNumber,
    required this.standard,
    required this.section,
    this.photoUrl,
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['Id'] as int,
    name: json['Name'] as String,
    admissionNumber: json['AdmissionNumber'] as String,
    standard: json['Standard'] as String,
    section: json['Section'] as String,
    photoUrl: json['PhotoUrl'] as String?,
  );

  final int id;
  final String name;
  final String admissionNumber;
  final String standard;
  final String section;
  final String? photoUrl;
}

/// One page of students plus the total across all pages.
class StudentPage {
  const StudentPage({required this.students, required this.total});

  factory StudentPage.fromJson(Map<String, dynamic> json) {
    final students = ((json['data'] as List<dynamic>?) ?? const [])
        .map((e) => Student.fromJson(e as Map<String, dynamic>))
        .toList();
    final metadata = json['metadata'] as Map<String, dynamic>?;
    return StudentPage(
      students: students,
      total: (metadata?['total'] as num?)?.toInt() ?? students.length,
    );
  }

  final List<Student> students;
  final int total;
}

/// A class/standard returned by `/v1.0/getStandards`.
class Standard {
  const Standard({required this.id, required this.name});

  factory Standard.fromJson(Map<String, dynamic> json) =>
      Standard(id: json['Id'] as int, name: json['Name'] as String);

  final int id;
  final String name;
}
