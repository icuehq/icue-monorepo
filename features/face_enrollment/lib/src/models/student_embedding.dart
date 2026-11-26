/// A student's face embedding together with the identity it belongs to.
class StudentEmbedding {
  const StudentEmbedding({
    required this.studentId,
    required this.name,
    required this.admissionNumber,
    required this.standard,
    required this.classId,
    required this.section,
    required this.embedding,
  });

  factory StudentEmbedding.fromJson(Map<String, dynamic> json) =>
      StudentEmbedding(
        studentId: (json['StudentId'] as num).toInt(),
        name: json['Name'] as String,
        admissionNumber: json['AdmissionNumber'] as String,
        standard: json['Standard'] as String,
        classId: (json['ClassId'] as num).toInt(),
        section: json['Section'] as String,
        embedding: (json['Embedding'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(),
      );

  final int studentId;
  final String name;
  final String admissionNumber;
  final String standard;
  final int classId;
  final String section;
  final List<double> embedding;

  Map<String, dynamic> toJson() => {
    'StudentId': studentId,
    'Name': name,
    'AdmissionNumber': admissionNumber,
    'Standard': standard,
    'ClassId': classId,
    'Section': section,
    'Embedding': embedding,
  };
}
