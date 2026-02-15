import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

/// 课表状态管理
class ScheduleProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final CacheService _cache = CacheService();

  ScheduleData? _scheduleData;
  bool _loading = false;
  String? _error;
  int _currentWeek = 1;
  int _selectedYear = 0;
  int _selectedSemester = -1;

  /// 动态获取的学期开始日期（第一周周一）
  DateTime? _semesterStart;

  ScheduleData? get scheduleData => _scheduleData;
  bool get loading => _loading;
  String? get error => _error;
  int get currentWeek => _currentWeek;
  int get selectedYear => _selectedYear;
  int get selectedSemester => _selectedSemester;
  DateTime? get semesterStart => _semesterStart;

  ScheduleProvider() {
    _initDefaultSemester();
    _loadFromCache(); // 立即从本地缓存恢复
  }

  /// 从本地缓存恢复上次数据（瞬间完成）
  void _loadFromCache() {
    final key = CacheService.scheduleKey(_selectedYear, _selectedSemester);
    final cached = _cache.get(key);
    if (cached != null) {
      _scheduleData = ScheduleData.fromJson(cached);
      debugPrint('[ScheduleProvider] 从缓存恢复 ${_scheduleData?.courses.length} 门课');
    }
    // 同时恢复学期信息
    final semKey = CacheService.semesterInfoKey(_selectedYear, _selectedSemester);
    final semCached = _cache.get(semKey);
    if (semCached != null) {
      final startStr = semCached['semester_start'] as String? ?? '';
      if (startStr.isNotEmpty) {
        _semesterStart = DateTime.parse(startStr);
      }
      final week = semCached['current_week'] as int? ?? 0;
      if (week > 0) _currentWeek = week.clamp(1, 25);
    }
  }

  /// 根据当前日期自动选择学期
  /// 如果不在学期内（假期），自动切到下一学期
  void _initDefaultSemester() {
    final now = DateTime.now();
    if (now.month >= 9) {
      _selectedYear = now.year;
      _selectedSemester = 0; // 秋季
    } else if (now.month <= 2) {
      // 寒假：秋季已结束，先尝试秋季判断周次
      // 如果秋季周次>20，直接显示下学期（春季）
      _selectedYear = now.year - 1;
      _selectedSemester = 1; // 直接显示即将到来的春季
      _currentWeek = 1;
    } else if (now.month <= 6) {
      _selectedYear = now.year - 1;
      _selectedSemester = 1; // 春季
    } else {
      // 7-8月暑假：春季已结束，显示即将到来的秋季
      _selectedYear = now.year;
      _selectedSemester = 0; // 秋季
      _currentWeek = 1;
    }
  }

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

      // 保存到本地缓存
      _cache.put(CacheService.scheduleKey(_selectedYear, _selectedSemester), data);

      // 从后端动态获取学期信息
      await _fetchSemesterInfo();

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = '获取课表失败';
      _loading = false;
      notifyListeners();
    }
  }

  /// 从后端获取学期信息（当前周次、学期开始日期）
  Future<void> _fetchSemesterInfo() async {
    try {
      final info = await _api.getSemesterInfo(
        year: _selectedYear,
        semester: _selectedSemester,
      );
      final startStr = info['semester_start'] as String? ?? '';
      final serverWeek = info['current_week'] as int? ?? 0;

      if (startStr.isNotEmpty) {
        _semesterStart = DateTime.parse(startStr);
        debugPrint('[ScheduleProvider] 学期开始日期: $startStr');
      }

      if (serverWeek > 0) {
        _currentWeek = serverWeek.clamp(1, 25);
        debugPrint('[ScheduleProvider] 当前教学周: $_currentWeek');
      } else {
        _calculateCurrentWeek();
      }

      // 缓存学期信息
      _cache.put(CacheService.semesterInfoKey(_selectedYear, _selectedSemester), info);
    } catch (e) {
      debugPrint('[ScheduleProvider] 获取学期信息失败: $e, 使用本地估算');
      _calculateCurrentWeek();
    }
  }

  /// 本地估算当前教学周（仅在服务器获取失败时使用）
  void _calculateCurrentWeek() {
    final now = DateTime.now();
    if (_semesterStart != null) {
      final diff = now.difference(_semesterStart!).inDays;
      if (diff >= 0) {
        _currentWeek = (diff ~/ 7) + 1;
        _currentWeek = _currentWeek.clamp(1, 20);
      } else {
        _currentWeek = 1;
      }
      return;
    }
    // 回退硬编码: 秋季9月1日附近周一, 春季次年3月第一个周一
    DateTime semesterStart;
    if (_selectedSemester == 1) {
      // 春季: 次年3月第一个周一
      final mar1 = DateTime(_selectedYear + 1, 3, 1);
      if (mar1.weekday == DateTime.monday) {
        semesterStart = mar1;
      } else {
        semesterStart = mar1.add(
            Duration(days: (8 - mar1.weekday) % 7));
      }
    } else {
      // 秋季: 9月15日附近的周一
      final sep15 = DateTime(_selectedYear, 9, 15);
      if (sep15.weekday == 1) {
        semesterStart = sep15;
      } else if (sep15.weekday <= 3) {
        semesterStart = sep15.subtract(Duration(days: sep15.weekday - 1));
      } else {
        semesterStart = sep15.add(Duration(days: 8 - sep15.weekday));
      }
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
