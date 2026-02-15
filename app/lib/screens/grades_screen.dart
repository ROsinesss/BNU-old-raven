import 'package:flutter/material.dart';import 'package:flutter/services.dart';import 'package:provider/provider.dart';
import '../models/grade_model.dart';
import '../providers/grades_provider.dart';
import '../theme/app_theme.dart';

/// 成绩页面
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  @override
  void initState() {
    super.initState();
    // HomeScreen 已负责并行预取，此处仅在缓存也为空时补发
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GradesProvider>();
      if (provider.gradesData == null && !provider.loadingGrades) {
        provider.fetchGrades();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GradesProvider>();

    return Column(
      children: [
        // 学期筛选栏 — 始终显示
        _buildSemesterFilter(provider),
        // 内容区域
        Expanded(child: _buildContent(provider)),
      ],
    );
  }

  Widget _buildContent(GradesProvider provider) {
    if (provider.loadingGrades) {
      return _buildLoadingShimmer();
    }

    if (provider.gradesError != null) {
      final isSessionExpired = provider.gradesError!.contains('过期') ||
          provider.gradesError!.contains('登录');
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
              child: Icon(
                  isSessionExpired
                      ? Icons.lock_outline_rounded
                      : Icons.wifi_off_rounded,
                  size: 32,
                  color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(provider.gradesError!,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => provider.fetchGrades(),
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

    final data = provider.gradesData;
    if (data == null || data.grades.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.school_outlined,
                  size: 32, color: Colors.blue[300]),
            ),
            const SizedBox(height: 16),
            const Text('教务系统暂无成绩记录',
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('可能成绩尚未录入，请稍后再试',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => provider.fetchGrades(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('刷新'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final bySemester = data.gradesBySemester;
    final semesters = bySemester.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () => provider.fetchGrades(),
      color: AppTheme.primaryColor,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // GPA 概览卡片
          _buildGpaSummary(data),
          // 按学期分组
          ...semesters
              .map((sem) => _buildSemesterSection(sem, bySemester[sem]!)),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 学期标签
  String _semesterLabel(int year, int semester) {
    if (year == 0 && semester == -1) return '全部学期';
    return '$year-${year + 1} ${semester == 0 ? '秋' : '春'}';
  }

  Widget _buildSemesterFilter(GradesProvider provider) {
    final label = _semesterLabel(provider.selectedYear, provider.selectedSemester);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () => _showSemesterPicker(provider),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_rounded,
                        size: 14, color: AppTheme.secondaryColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: AppTheme.secondaryColor),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // 刷新按钮
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                size: 20, color: Colors.grey[400]),
            onPressed: () => provider.fetchGrades(),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  void _showSemesterPicker(GradesProvider provider) {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    // 生成学期选项
    final semesters = <Map<String, int>>[
      {'year': 0, 'yearEnd': 0, 'semester': -1}, // 全部
    ];
    for (int y = now.year; y >= now.year - 3; y--) {
      semesters.add({'year': y, 'yearEnd': y + 1, 'semester': 1}); // 春
      semesters.add({'year': y, 'yearEnd': y + 1, 'semester': 0}); // 秋
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('选择学期',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...semesters.map((s) {
                final isCurrent = s['year'] == provider.selectedYear &&
                    s['semester'] == provider.selectedSemester;
                final label = _semesterLabel(s['year']!, s['semester']!);
                return ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? AppTheme.primaryColor : null,
                    ),
                  ),
                  trailing: isCurrent
                      ? Icon(Icons.check_circle_rounded,
                          color: AppTheme.primaryColor, size: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  tileColor: isCurrent
                      ? AppTheme.primaryColor.withValues(alpha: 0.06)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    provider.fetchGrades(
                      year: s['year']!,
                      yearEnd: s['yearEnd']!,
                      semester: s['semester']!,
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpaSummary(GradesData data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _gpaStat('平均绩点', data.totalGpa.toStringAsFixed(2), Icons.star_rounded),
          _gpaVerticalDivider(),
          _gpaStat('总学分', data.totalCredits.toStringAsFixed(1),
              Icons.school_rounded),
          _gpaVerticalDivider(),
          _gpaStat('课程数', '${data.grades.length}',
              Icons.menu_book_rounded),
        ],
      ),
    );
  }

  Widget _gpaStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _gpaVerticalDivider() {
    return Container(
      width: 1,
      height: 44,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildSemesterSection(String semester, List<Grade> grades) {
    // 计算学期平均绩点（仅计算有 GPA 的课程，排除"合格"类和缺考）
    double semGpa = 0;
    double semCredits = 0;
    for (final g in grades) {
      if (g.gpaPoint > 0 && g.credits > 0) {
        semGpa += g.gpaPoint * g.credits;
        semCredits += g.credits;
      }
    }
    final avgGpa = semCredits > 0 ? semGpa / semCredits : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                semester,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'GPA ${avgGpa.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...grades.map(_buildGradeCard),
      ],
    );
  }

  Widget _buildGradeCard(Grade grade) {
    // 根据数值成绩确定颜色
    final Color scoreColor;
    final num = grade.numericScore;
    if (grade.remark == '缺考') {
      scoreColor = Colors.grey;
    } else if (num != null) {
      if (num >= 90) {
        scoreColor = const Color(0xFF2196F3); // 蓝色 - 优秀
      } else if (num >= 80) {
        scoreColor = AppTheme.successColor;   // 绿色 - 良好
      } else if (num >= 70) {
        scoreColor = const Color(0xFFFF9800); // 橙色 - 中等
      } else if (num >= 60) {
        scoreColor = const Color(0xFFFF5722); // 深橙 - 及格
      } else {
        scoreColor = AppTheme.dangerColor;    // 红色 - 不及格
      }
    } else if (grade.score == '合格' || grade.score == '通过') {
      scoreColor = AppTheme.successColor;
    } else if (grade.score == '不合格' || grade.score == '不通过') {
      scoreColor = AppTheme.dangerColor;
    } else {
      scoreColor = grade.isPassed ? AppTheme.successColor : AppTheme.dangerColor;
    }

    // 显示的分数文本
    String scoreText = grade.score;
    if (num != null && num == num.toInt().toDouble()) {
      scoreText = num.toInt().toString(); // 85.0 → "85"
    }

    // 平时/期末成绩（过滤掉空值和0值，简化小数）
    String formatSubScore(String s) {
      if (s.isEmpty) return '';
      final v = double.tryParse(s);
      if (v == null || v == 0) return '';
      if (v == v.toInt().toDouble()) return v.toInt().toString();
      return s;
    }
    final regularDisplay = formatSubScore(grade.regularScore);
    final finalDisplay = formatSubScore(grade.finalScore);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade.courseName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _miniTag('${grade.credits}学分',
                          AppTheme.accentColor.withValues(alpha: 0.1),
                          AppTheme.accentColor),
                      const SizedBox(width: 6),
                      if (grade.gpaPoint > 0)
                        _miniTag('绩点 ${grade.gpaPoint.toStringAsFixed(1)}',
                            Colors.grey[100]!, Colors.grey[600]!),
                      if (grade.remark.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _miniTag(grade.remark,
                            AppTheme.dangerColor.withValues(alpha: 0.1),
                            AppTheme.dangerColor),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 分数区域：平时 / 期末 / 综合
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    scoreText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
                if (regularDisplay.isNotEmpty || finalDisplay.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (regularDisplay.isNotEmpty)
                          _scoreLabel('平时', regularDisplay, const Color(0xFF5C6BC0)),
                        if (regularDisplay.isNotEmpty && finalDisplay.isNotEmpty)
                          const SizedBox(width: 6),
                        if (finalDisplay.isNotEmpty)
                          _scoreLabel('期末', finalDisplay, const Color(0xFF26A69A)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }

  Widget _scoreLabel(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
