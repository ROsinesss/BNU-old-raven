/// 考试安排模型
class Exam {
  final String courseName;
  final String examTime;
  final String examLocation;
  final String seatNumber;
  final String examType;

  Exam({
    this.courseName = '',
    this.examTime = '',
    this.examLocation = '',
    this.seatNumber = '',
    this.examType = '',
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      courseName: json['course_name'] ?? '',
      examTime: json['exam_time'] ?? '',
      examLocation: json['exam_location'] ?? '',
      seatNumber: json['seat_number'] ?? '',
      examType: json['exam_type'] ?? '',
    );
  }
}

/// 考试响应模型
class ExamsData {
  final List<Exam> exams;

  ExamsData({this.exams = const []});

  factory ExamsData.fromJson(Map<String, dynamic> json) {
    return ExamsData(
      exams: (json['exams'] as List<dynamic>?)
              ?.map((e) => Exam.fromJson(e))
              .toList() ??
          [],
    );
  }
}
