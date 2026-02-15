import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../services/api_service.dart';

/// 课表状态管理
class ScheduleProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  ScheduleData? _scheduleData;
  bool _loading = false;
  String? _error;
  int _currentWeek = 1;
  int _selectedYear = 2025;
  int _selectedSemester = 1;

  ScheduleData? get scheduleData => _scheduleData;
  bool get loading => _loading;
  String? get error => _error;
  int get currentWeek => _currentWeek;
  int get selectedYear => _selectedYear;
  int get selectedSemester => _selectedSemester;

  /// 当前周课表
  List<ScheduleSlot> get currentWeekSlots {
    return _scheduleData?.getSlotsForWeek(_currentWeek) ?? [];
  }

  /// 切换周次
  void setWeek(int week) {
    _currentWeek = week.clamp(1, 20);
    notifyListeners();
  }

  /// 加载课表
  Future<void> fetchSchedule({int? year, int? semester}) async {
    if (year != null) _selectedYear = year;
    if (semester != null) _selectedSemester = semester;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.getSchedule(
        year: _selectedYear,
        semester: _selectedSemester,
      );
      _scheduleData = ScheduleData.fromJson(data);

      // 自动计算当前周次
      _calculateCurrentWeek();

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = '获取课表失败';
      _loading = false;
      notifyListeners();
    }
  }

  /// 根据日期估算当前教学周
  void _calculateCurrentWeek() {
    // 简单估算：春季学期一般 2 月底开学，秋季学期 9 月初开学
    final now = DateTime.now();
    DateTime semesterStart;

    if (_selectedSemester == 1) {
      // 春季学期
      semesterStart = DateTime(_selectedYear + 1, 2, 24);
    } else {
      // 秋季学期
      semesterStart = DateTime(_selectedYear, 9, 1);
    }

    final diff = now.difference(semesterStart).inDays;
    if (diff >= 0) {
      _currentWeek = (diff ~/ 7) + 1;
      _currentWeek = _currentWeek.clamp(1, 20);
    } else {
      _currentWeek = 1;
    }
  }

  /// 清空数据
  void clear() {
    _scheduleData = null;
    _error = null;
    _currentWeek = 1;
    notifyListeners();
  }
}
