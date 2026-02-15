/// 成绩模型
class Grade {
  final String semester;
  final String courseId;
  final String courseName;
  final String score;         // 综合成绩
  final double credits;
  final int totalHours;
  final double gpaPoint;
  final String examType;       // 考核方式
  final String courseCategory;  // 课程类别
  final String courseNature;    // 课程性质（选修/必修）
  final String regularScore;   // 平时成绩
  final String finalScore;     // 期末成绩
  final String studyType;      // 修读性质（初修/重修）
  final String remark;         // 备注（缺考 等）

  Grade({
    this.semester = '',
    this.courseId = '',
    this.courseName = '',
    this.score = '',
    this.credits = 0.0,
    this.totalHours = 0,
    this.gpaPoint = 0.0,
    this.examType = '',
    this.courseCategory = '',
    this.courseNature = '',
    this.regularScore = '',
    this.finalScore = '',
    this.studyType = '',
    this.remark = '',
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      semester: json['semester'] ?? '',
      courseId: json['course_id'] ?? '',
      courseName: json['course_name'] ?? '',
      score: json['score'] ?? '',
      credits: (json['credits'] ?? 0).toDouble(),
      totalHours: json['total_hours'] ?? 0,
      gpaPoint: (json['gpa_point'] ?? 0).toDouble(),
      examType: json['exam_type'] ?? '',
      courseCategory: json['course_category'] ?? '',
      courseNature: json['course_nature'] ?? '',
      regularScore: json['regular_score'] ?? '',
      finalScore: json['final_score'] ?? '',
      studyType: json['study_type'] ?? '',
      remark: json['remark'] ?? '',
    );
  }

  /// 数值分数（用于颜色判断）
  double? get numericScore => double.tryParse(score);

  /// 是否通过
  bool get isPassed {
    if (remark == '缺考') return false;
    final num = numericScore;
    if (num != null) return num >= 60;
    return !['不及格', '不通过', '不合格', 'F', 'D'].contains(score);
  }

  /// 是否为"合格"类成绩（不计入 GPA）
  bool get isPassFail => score == '合格' || score == '不合格' || score == '通过' || score == '不通过';
}

/// 成绩响应模型
class GradesData {
  final List<Grade> grades;
  final double semesterGpa;
  final double totalGpa;
  final double totalCredits;

  GradesData({
    this.grades = const [],
    this.semesterGpa = 0.0,
    this.totalGpa = 0.0,
    this.totalCredits = 0.0,
  });

  factory GradesData.fromJson(Map<String, dynamic> json) {
    return GradesData(
      grades: (json['grades'] as List<dynamic>?)
              ?.map((g) => Grade.fromJson(g))
              .toList() ??
          [],
      semesterGpa: (json['semester_gpa'] ?? 0).toDouble(),
      totalGpa: (json['total_gpa'] ?? 0).toDouble(),
      totalCredits: (json['total_credits'] ?? 0).toDouble(),
    );
  }

  /// 按学期分组
  Map<String, List<Grade>> get gradesBySemester {
    final map = <String, List<Grade>>{};
    for (final g in grades) {
      final key = g.semester.isNotEmpty ? g.semester : '未知学期';
      map.putIfAbsent(key, () => []).add(g);
    }
    return map;
  }
}
