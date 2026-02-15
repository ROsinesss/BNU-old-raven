import 'package:flutter/material.dart';
import '../models/grade_model.dart';
import '../models/exam_model.dart';
import '../services/api_service.dart';

/// 成绩与考试状态管理
class GradesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  GradesData? _gradesData;
  ExamsData? _examsData;
  bool _loadingGrades = false;
  bool _loadingExams = false;
  String? _gradesError;
  String? _examsError;

  // 成绩筛选：学期（-1=全部, 0=秋季, 1=春季）
  int _selectedYear = 0;
  int _selectedYearEnd = 0;
  int _selectedSemester = -1;

  GradesData? get gradesData => _gradesData;
  ExamsData? get examsData => _examsData;
  bool get loadingGrades => _loadingGrades;
  bool get loadingExams => _loadingExams;
  String? get gradesError => _gradesError;
  String? get examsError => _examsError;
  int get selectedYear => _selectedYear;
  int get selectedYearEnd => _selectedYearEnd;
  int get selectedSemester => _selectedSemester;

  /// 加载成绩
  Future<void> fetchGrades({int? year, int? yearEnd, int? semester}) async {
    if (year != null) _selectedYear = year;
    if (yearEnd != null) _selectedYearEnd = yearEnd;
    if (semester != null) _selectedSemester = semester;

    _loadingGrades = true;
    _gradesError = null;
    notifyListeners();

    try {
      debugPrint('[GradesProvider] fetchGrades: year=$_selectedYear, yearEnd=$_selectedYearEnd, semester=$_selectedSemester');
      final data = await _api.getGrades(
        year: _selectedYear,
        yearEnd: _selectedYearEnd,
        semester: _selectedSemester,
      );
      debugPrint('[GradesProvider] API response keys: ${data.keys.toList()}');
      debugPrint('[GradesProvider] grades count in response: ${(data['grades'] as List?)?.length ?? 'null'}');
      _gradesData = GradesData.fromJson(data);
      debugPrint('[GradesProvider] parsed grades count: ${_gradesData?.grades.length}');
      _loadingGrades = false;
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[GradesProvider] fetchGrades error: $e');
      debugPrint('[GradesProvider] stack: $stack');
      // 友好错误信息
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('过期') || msg.contains('重新登录')) {
        _gradesError = '会话已过期，请重新登录';
      } else if (msg.contains('Connection') || msg.contains('timeout') || msg.contains('SocketException')) {
        _gradesError = '网络连接失败，请检查后端服务';
      } else {
        _gradesError = '获取成绩失败';
      }
      _loadingGrades = false;
      notifyListeners();
    }
  }

  /// 加载考试安排
  Future<void> fetchExams() async {
    _loadingExams = true;
    _examsError = null;
    notifyListeners();

    try {
      final data = await _api.getExams();
      _examsData = ExamsData.fromJson(data);
      _loadingExams = false;
      notifyListeners();
    } catch (e) {
      _examsError = '获取考试安排失败';
      _loadingExams = false;
      notifyListeners();
    }
  }

  /// 清空数据
  void clear() {
    _gradesData = null;
    _examsData = null;
    _gradesError = null;
    _examsError = null;
    _selectedYear = 0;
    _selectedYearEnd = 0;
    _selectedSemester = -1;
    notifyListeners();
  }
}
