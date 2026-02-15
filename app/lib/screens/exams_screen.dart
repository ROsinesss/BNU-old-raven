import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exam_model.dart';
import '../providers/grades_provider.dart';
import '../theme/app_theme.dart';

/// 考试安排页面
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  @override
  void initState() {
    super.initState();
    // HomeScreen 已负责并行预取，此处仅在缓存也为空时补发
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GradesProvider>();
      if (provider.examsData == null && !provider.loadingExams) {
        provider.fetchExams();
      }
    });
  }

  /// 学期选项列表
  static final List<Map<String, dynamic>> _semesterOptions = [
    {'label': '当前学期', 'year': 0, 'semester': -1},
    {'label': '2025秋', 'year': 2025, 'semester': 0},
    {'label': '2025春', 'year': 2025, 'semester': 1},
    {'label': '2024秋', 'year': 2024, 'semester': 0},
    {'label': '2024春', 'year': 2024, 'semester': 1},
    {'label': '2023秋', 'year': 2023, 'semester': 0},
  ];

  String _currentLabel(GradesProvider provider) {
    for (final opt in _semesterOptions) {
      if (opt['year'] == provider.examYear &&
          opt['semester'] == provider.examSemester) {
        return opt['label'] as String;
      }
    }
    return '当前学期';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GradesProvider>();

    return Column(
      children: [
        // 学期选择栏
        _buildSemesterBar(provider),
        // 内容区域
        Expanded(child: _buildContent(provider)),
      ],
    );
  }

  Widget _buildSemesterBar(GradesProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded,
              size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _showSemesterPicker(provider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentLabel(provider),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSemesterPicker(GradesProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择学期',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ..._semesterOptions.map((opt) {
              final active = opt['year'] == provider.examYear &&
                  opt['semester'] == provider.examSemester;
              return ListTile(
                title: Text(opt['label'] as String,
                    style: TextStyle(
                      color: active ? AppTheme.primaryColor : null,
                      fontWeight: active ? FontWeight.w700 : null,
                    )),
                trailing: active
                    ? Icon(Icons.check_rounded,
                        color: AppTheme.primaryColor, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  provider.fetchExams(
                    year: opt['year'] as int,
                    semester: opt['semester'] as int,
                  );
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(GradesProvider provider) {
    if (provider.loadingExams) {
      return _buildLoadingShimmer();
    }

    if (provider.examsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 32, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(provider.examsError!,
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => provider.fetchExams(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final data = provider.examsData;
    if (data == null || data.exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.event_available_rounded,
                  size: 32, color: AppTheme.successColor),
            ),
            const SizedBox(height: 16),
            const Text('暂无考试安排',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('当前学期没有待考科目',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      );
    }

    // 分组：即将到来 / 已结束
    final now = DateTime.now();
    final upcoming = <Exam>[];
    final past = <Exam>[];

    // 判断所选学期是否明确是过去的学期
    final isPastSemester = _isSelectedSemesterInPast(provider, now);

    for (final e in data.exams) {
      final examDate = _parseExamDate(e.examTime);
      if (examDate != null) {
        // 日期解析成功，按实际日期判断
        if (examDate.isBefore(now)) {
          past.add(e);
        } else {
          upcoming.add(e);
        }
      } else if (isPastSemester) {
        // 选了过去的学期，解析不出日期也归为已结束
        past.add(e);
      } else {
        upcoming.add(e);
      }
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchExams(),
      color: AppTheme.primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          // 统计概览
          _buildExamSummary(data.exams.length, upcoming.length),
          if (upcoming.isNotEmpty) ...[
            _sectionTitle('即将到来', upcoming.length, AppTheme.warningColor),
            ...upcoming.map((e) => _buildExamCard(e, isUpcoming: true)),
          ],
          if (past.isNotEmpty) ...[
            _sectionTitle('已结束', past.length, Colors.grey),
            ...past.map((e) => _buildExamCard(e, isUpcoming: false)),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          4,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamSummary(int total, int upcomingCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.edit_calendar_rounded,
                size: 22, color: AppTheme.accentColor),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('共 $total 场考试',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                upcomingCount > 0
                    ? '还有 $upcomingCount 场待考'
                    : '所有考试已结束',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Exam exam, {required bool isUpcoming}) {
    final daysLeft = _calcDaysLeft(exam.examTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isUpcoming
            ? Border(
                left: BorderSide(
                    color: daysLeft != null && daysLeft <= 3
                        ? AppTheme.dangerColor
                        : AppTheme.warningColor,
                    width: 3),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exam.courseName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isUpcoming ? null : Colors.grey[500],
                    ),
                  ),
                ),
                if (isUpcoming && daysLeft != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: daysLeft <= 3
                          ? AppTheme.dangerColor.withValues(alpha: 0.1)
                          : AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      daysLeft == 0
                          ? '今天'
                          : daysLeft == 1
                              ? '明天'
                              : '$daysLeft天后',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: daysLeft <= 3
                            ? AppTheme.dangerColor
                            : AppTheme.warningColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _infoChip(Icons.access_time_rounded,
                    exam.examTime.isNotEmpty ? exam.examTime : '待定',
                    isUpcoming: isUpcoming),
                _infoChip(Icons.location_on_outlined,
                    exam.examLocation.isNotEmpty ? exam.examLocation : '待定',
                    isUpcoming: isUpcoming),
                if (exam.seatNumber.isNotEmpty)
                  _infoChip(Icons.event_seat_rounded, '座位 ${exam.seatNumber}',
                      isUpcoming: isUpcoming),
                if (exam.examType.isNotEmpty)
                  _infoChip(Icons.category_outlined, exam.examType,
                      isUpcoming: isUpcoming),
                if (exam.credits.isNotEmpty)
                  _infoChip(Icons.star_outline_rounded, '${exam.credits}学分',
                      isUpcoming: isUpcoming),
                if (exam.category.isNotEmpty)
                  _infoChip(Icons.label_outline_rounded, exam.category,
                      isUpcoming: isUpcoming),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, {required bool isUpcoming}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14,
            color: isUpcoming ? AppTheme.accentColor : Colors.grey[400]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isUpcoming ? Colors.grey[700] : Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 简单解析考试时间字符串中的日期
  DateTime? _parseExamDate(String examTime) {
    if (examTime.isEmpty) return null;

    // 格式1: 2026-01-15 或 2026/01/15
    var match = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(examTime);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }

    // 格式2: 2026年1月15日 或 2026年01月15日
    match = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日?').firstMatch(examTime);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }

    // 格式3: 01月15日（无年份，用当前年）
    match = RegExp(r'(\d{1,2})月(\d{1,2})日').firstMatch(examTime);
    if (match != null) {
      return DateTime(
        DateTime.now().year,
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
      );
    }

    // 格式4: 纯数字 20260115
    match = RegExp(r'(\d{4})(\d{2})(\d{2})').firstMatch(examTime);
    if (match != null) {
      final y = int.parse(match.group(1)!);
      if (y > 2000 && y < 2100) {
        return DateTime(
          y,
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        );
      }
    }

    return null;
  }

  /// 判断当前选中的学期是否已经过去
  bool _isSelectedSemesterInPast(GradesProvider provider, DateTime now) {
    final year = provider.examYear;
    final sem = provider.examSemester;
    if (year <= 0 || sem < 0) return false; // 当前学期，不确定

    // 春季学期: year+1年的上半年; 秋季学期: year年的下半年
    if (sem == 1) {
      // 春季: 大约 year+1 年 3-7 月, 到 8 月肯定结束
      return now.isAfter(DateTime(year + 1, 8, 1));
    } else {
      // 秋季: 大约 year 年 9 月 - year+1 年 2 月, 到 3 月肯定结束
      return now.isAfter(DateTime(year + 1, 3, 1));
    }
  }

  int? _calcDaysLeft(String examTime) {
    final date = _parseExamDate(examTime);
    if (date == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(date.year, date.month, date.day);
    final diff = examDay.difference(today).inDays;
    return diff >= 0 ? diff : null;
  }
}
