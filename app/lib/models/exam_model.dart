/// 考试安排模型
class Exam {
  final String courseName;
  final String credits;
  final String category;
  final String examType;
  final String examTime;
  final String examLocation;
  final String seatNumber;
  final String examRound;

  Exam({
    this.courseName = '',
    this.credits = '',
    this.category = '',
    this.examType = '',
    this.examTime = '',
    this.examLocation = '',
    this.seatNumber = '',
    this.examRound = '',
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      courseName: json['course_name'] ?? '',
      credits: json['credits'] ?? '',
      category: json['category'] ?? '',
      examType: json['exam_type'] ?? '',
      examTime: json['exam_time'] ?? '',
      examLocation: json['exam_location'] ?? '',
      seatNumber: json['seat_number'] ?? '',
      examRound: json['exam_round'] ?? '',
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
