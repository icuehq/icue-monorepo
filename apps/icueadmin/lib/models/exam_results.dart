class ExamResult {
  ExamResult({
    required this.studentId,
    required this.studentName,
    this.rollNo,
    this.admissionNumber,
    this.totalMarks,
    this.maximumMarks,
    this.percentage,
    this.percentageRaw,
    this.grade,
    this.rank,
    this.status,
    this.result,
    this.passed,
    this.subjectMarks,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    final rawSubjects = json['Subjects'] ?? json['SubjectMarks'];

    num? parsedTotal;
    if (json['TotalMarks'] is num) {
      parsedTotal = json['TotalMarks'] as num;
    } else if (json['Total'] is num) {
      parsedTotal = json['Total'] as num;
    } else {
      parsedTotal = num.tryParse(
        json['TotalMarks']?.toString() ?? json['Total']?.toString() ?? '',
      );
    }

    num? parsedMax;
    if (json['MaximumMarks'] is num) {
      parsedMax = json['MaximumMarks'] as num;
    } else if (json['Maximum'] is num) {
      parsedMax = json['Maximum'] as num;
    } else {
      parsedMax = num.tryParse(
        json['MaximumMarks']?.toString() ?? json['Maximum']?.toString() ?? '',
      );
    }

    final rawPercentage = json['Percentage']?.toString();
    final parsedPercentage = json['Percentage'] is num
        ? json['Percentage'] as num
        : num.tryParse(rawPercentage ?? '');

    return ExamResult(
      studentId: json['StudentId'] is int
          ? json['StudentId'] as int
          : int.tryParse(json['StudentId']?.toString() ?? '') ?? 0,
      studentName:
          json['StudentName']?.toString() ?? json['Name']?.toString() ?? '',
      rollNo: json['RollNo']?.toString(),
      admissionNumber:
          json['AdmissionNumber']?.toString() ??
          json['AdmissionNo']?.toString(),
      totalMarks: parsedTotal,
      maximumMarks: parsedMax,
      percentage: parsedPercentage,
      percentageRaw: rawPercentage,
      grade: json['Grade']?.toString(),
      rank: json['Rank'] is int
          ? json['Rank'] as int
          : int.tryParse(json['Rank']?.toString() ?? ''),
      status: json['Status']?.toString(),
      result: json['Result']?.toString(),
      passed: json['Passed'] is bool ? json['Passed'] as bool : null,
      subjectMarks: rawSubjects is List
          ? List<SubjectMark>.from(
              rawSubjects.whereType<Map>().map(
                (x) => SubjectMark.fromJson(Map<String, dynamic>.from(x)),
              ),
            )
          : null,
    );
  }

  final int studentId;
  final String studentName;
  final String? rollNo;
  final String? admissionNumber;
  final num? totalMarks;
  final num? maximumMarks;
  final num? percentage;
  final String? percentageRaw;
  final String? grade;
  int? rank;
  final String? status;
  final String? result; // 'PASS', 'FAIL', 'N/A'
  final bool? passed;
  final List<SubjectMark>? subjectMarks;

  String get displayPercentage {
    if (percentage != null) {
      return '${percentage!.toStringAsFixed(percentage! % 1 == 0 ? 0 : 2)}%';
    }
    if (percentageRaw != null && percentageRaw!.isNotEmpty) {
      return percentageRaw!;
    }
    return '-';
  }

  bool get isPassed {
    if (passed != null) return passed!;
    final res = result?.toUpperCase() ?? status?.toUpperCase();
    return res == 'PASS' || res == 'PASSED';
  }

  bool get isFailed {
    final res = result?.toUpperCase() ?? status?.toUpperCase();
    return res == 'FAIL' || res == 'FAILED';
  }

  Map<String, dynamic> toJson() => {
    'StudentId': studentId,
    'StudentName': studentName,
    if (rollNo != null) 'RollNo': rollNo,
    if (admissionNumber != null) 'AdmissionNumber': admissionNumber,
    if (totalMarks != null) 'TotalMarks': totalMarks,
    if (maximumMarks != null) 'MaximumMarks': maximumMarks,
    if (percentage != null) 'Percentage': percentage,
    if (grade != null) 'Grade': grade,
    if (rank != null) 'Rank': rank,
    if (status != null) 'Status': status,
    if (result != null) 'Result': result,
    if (passed != null) 'Passed': passed,
    if (subjectMarks != null)
      'Subjects': subjectMarks!.map((x) => x.toJson()).toList(),
  };
}

class SubjectMark {
  SubjectMark({
    this.examId,
    required this.subjectId,
    required this.subject,
    this.marks,
    this.maximumMarks,
    this.passingMarks,
    this.status,
    this.result,
    this.passed,
  });

  factory SubjectMark.fromJson(Map<String, dynamic> json) => SubjectMark(
    examId: json['ExamId'] is int
        ? json['ExamId'] as int
        : int.tryParse(json['ExamId']?.toString() ?? ''),
    subjectId: json['SubjectId'] is int
        ? json['SubjectId'] as int
        : (json['ExamId'] is int
              ? json['ExamId'] as int
              : int.tryParse(
                      json['SubjectId']?.toString() ??
                          json['ExamId']?.toString() ??
                          '',
                    ) ??
                    0),
    subject: json['Subject']?.toString() ?? '',
    marks: json['Marks'] is num
        ? json['Marks'] as num
        : num.tryParse(json['Marks']?.toString() ?? ''),
    maximumMarks: json['MaximumMarks'] is num
        ? json['MaximumMarks'] as num
        : num.tryParse(json['MaximumMarks']?.toString() ?? ''),
    passingMarks: json['PassingMarks'] is num
        ? json['PassingMarks'] as num
        : num.tryParse(json['PassingMarks']?.toString() ?? ''),
    status: json['Status']?.toString(),
    result: json['Result']?.toString(),
    passed: json['Passed'] is bool ? json['Passed'] as bool : null,
  );

  final int? examId;
  final int subjectId;
  final String subject;
  final num? marks;
  final num? maximumMarks;
  final num? passingMarks;
  final String? status; // 'PRESENT', 'ABSENT', 'NOT_ENTERED', 'NA'
  final String? result; // 'PASS', 'FAIL'
  final bool? passed;

  bool get isPassed {
    if (passed != null) return passed!;
    final res = result?.toUpperCase();
    if (res == 'PASS' || res == 'PASSED') return true;
    if (marks != null && passingMarks != null) return marks! >= passingMarks!;
    return false;
  }

  Map<String, dynamic> toJson() => {
    if (examId != null) 'ExamId': examId,
    'SubjectId': subjectId,
    'Subject': subject,
    if (marks != null) 'Marks': marks,
    if (maximumMarks != null) 'MaximumMarks': maximumMarks,
    if (passingMarks != null) 'PassingMarks': passingMarks,
    if (status != null) 'Status': status,
    if (result != null) 'Result': result,
    if (passed != null) 'Passed': passed,
  };
}
