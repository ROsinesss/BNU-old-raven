/// 课表时间段模型
class ScheduleSlot {
  final List<int> weeks;
  final int dayOfWeek;
  final int startSection;
  final int endSection;
  final String classroom;
  final int capacity;
  // 关联的课程信息
  final String courseName;
  final String courseId;
  final List<String> teachers;
  final int colorIndex;

  ScheduleSlot({
    required this.weeks,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.classroom,
    this.capacity = 0,
    this.courseName = '',
    this.courseId = '',
    this.teachers = const [],
    this.colorIndex = 0,
  });

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) {
    return ScheduleSlot(
      weeks: List<int>.from(json['weeks'] ?? []),
      dayOfWeek: json['day_of_week'] ?? 0,
      startSection: json['start_section'] ?? 0,
      endSection: json['end_section'] ?? 0,
      classroom: json['classroom'] ?? '',
      capacity: json['capacity'] ?? 0,
    );
  }

  /// 检查该时间段是否包含指定周次
  bool containsWeek(int week) => weeks.contains(week);
}

/// 课程模型
class Course {
  final String courseId;
  final String courseName;
  final int totalHours;
  final double credits;
  final String classNumber;
  final List<String> teachers;
  final List<ScheduleSlot> slots;
  final String courseType;
  final String isMinor;
  final String rawTimeLocation;

  Course({
    required this.courseId,
    required this.courseName,
    this.totalHours = 0,
    this.credits = 0.0,
    this.classNumber = '',
    this.teachers = const [],
    this.slots = const [],
    this.courseType = '',
    this.isMinor = '',
    this.rawTimeLocation = '',
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      courseId: json['course_id'] ?? '',
      courseName: json['course_name'] ?? '',
      totalHours: json['total_hours'] ?? 0,
      credits: (json['credits'] ?? 0).toDouble(),
      classNumber: json['class_number'] ?? '',
      teachers: List<String>.from(json['teachers'] ?? []),
      slots: (json['slots'] as List<dynamic>?)
              ?.map((s) => ScheduleSlot.fromJson(s))
              .toList() ??
          [],
      courseType: json['course_type'] ?? '',
      isMinor: json['is_minor'] ?? '',
      rawTimeLocation: json['raw_time_location'] ?? '',
    );
  }
}

/// 课表响应模型
class ScheduleData {
  final String semesterLabel;
  final String studentId;
  final String studentName;
  final String className;
  final int totalCourses;
  final double totalCredits;
  final List<Course> courses;

  ScheduleData({
    this.semesterLabel = '',
    this.studentId = '',
    this.studentName = '',
    this.className = '',
    this.totalCourses = 0,
    this.totalCredits = 0.0,
    this.courses = const [],
  });

  factory ScheduleData.fromJson(Map<String, dynamic> json) {
    return ScheduleData(
      semesterLabel: json['semester_label'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? '',
      className: json['class_name'] ?? '',
      totalCourses: json['total_courses'] ?? 0,
      totalCredits: (json['total_credits'] ?? 0).toDouble(),
      courses: (json['courses'] as List<dynamic>?)
              ?.map((c) => Course.fromJson(c))
              .toList() ??
          [],
    );
  }

  /// 获取指定周次的所有时间段（附带课程信息和颜色）
  List<ScheduleSlot> getSlotsForWeek(int week) {
    final slots = <ScheduleSlot>[];
    for (int i = 0; i < courses.length; i++) {
      final course = courses[i];
      for (final slot in course.slots) {
        if (slot.containsWeek(week)) {
          slots.add(ScheduleSlot(
            weeks: slot.weeks,
            dayOfWeek: slot.dayOfWeek,
            startSection: slot.startSection,
            endSection: slot.endSection,
            classroom: slot.classroom,
            capacity: slot.capacity,
            courseName: course.courseName,
            courseId: course.courseId,
            teachers: course.teachers,
            colorIndex: i,
          ));
        }
      }
    }
    return slots;
  }
}
