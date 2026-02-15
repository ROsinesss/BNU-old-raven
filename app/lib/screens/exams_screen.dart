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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GradesProvider>();
      if (provider.examsData == null) {
        provider.fetchExams();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GradesProvider>();

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
    for (final e in data.exams) {
      final examDate = _parseExamDate(e.examTime);
      if (examDate != null && examDate.isBefore(now)) {
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
    // 尝试匹配 "2026-01-15" 或 "2026年1月15日" 等格式
    final regExp = RegExp(r'(\d{4})[-年/](\d{1,2})[-月/](\d{1,2})');
    final match = regExp.firstMatch(examTime);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
    return null;
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
