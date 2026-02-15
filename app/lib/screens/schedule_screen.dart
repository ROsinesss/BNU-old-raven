import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/schedule_model.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

/// 课表页面 — 周视图网格
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    // HomeScreen 已负责并行预取，此处仅在缓存也为空时补发
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScheduleProvider>();
      if (provider.scheduleData == null && !provider.loading) {
        provider.fetchSchedule();
      }
    });
  }

  int get _todayDay {
    final wd = DateTime.now().weekday; // 1=Mon ... 7=Sun
    return wd;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();

    return Column(
      children: [
        // 学期选择 + 周次选择
        _buildSemesterAndWeekBar(provider),
        // 星期标题行（含日期）
        _buildDayHeader(provider),
        // 课表网格（自适应满屏）
        Expanded(
          child: provider.loading
              ? _buildShimmerLoading()
              : provider.error != null
                  ? _buildError(provider)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildGrid(provider, constraints.maxHeight);
                      },
                    ),
        ),
      ],
    );
  }

  /// 学期标签
  String _semesterLabel(int year, int semester) {
    return '$year-${year + 1} ${semester == 0 ? '秋' : '春'}';
  }

  Widget _buildSemesterAndWeekBar(ScheduleProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        children: [
          // 学期选择行
          Row(
            children: [
              GestureDetector(
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
                      Text(
                        _semesterLabel(provider.selectedYear, provider.selectedSemester),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: AppTheme.secondaryColor),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // 周次选择
              _weekArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: provider.currentWeek > 1
                    ? () {
                        HapticFeedback.selectionClick();
                        provider.setWeek(provider.currentWeek - 1);
                      }
                    : null,
              ),
              GestureDetector(
                onTap: () => _showWeekPicker(provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '第${provider.currentWeek}周',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              ),
              _weekArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: provider.currentWeek < 20
                    ? () {
                        HapticFeedback.selectionClick();
                        provider.setWeek(provider.currentWeek + 1);
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showSemesterPicker(ScheduleProvider provider) {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    // 生成最近几个学期
    final semesters = <Map<String, int>>[];
    for (int y = now.year; y >= now.year - 3; y--) {
      semesters.add({'year': y, 'semester': 1}); // 春季
      semesters.add({'year': y, 'semester': 0}); // 秋季
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
                    provider.fetchSchedule(
                        year: s['year']!, semester: s['semester']!);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekArrowButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon,
              size: 24,
              color: onTap != null ? AppTheme.primaryColor : Colors.grey[300]),
        ),
      ),
    );
  }

  void _showWeekPicker(ScheduleProvider provider) {
    HapticFeedback.mediumImpact();
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
              const Text('选择周次',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 20,
                itemBuilder: (_, i) {
                  final week = i + 1;
                  final isCurrent = week == provider.currentWeek;
                  return Material(
                    color: isCurrent
                        ? AppTheme.primaryColor
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        provider.setWeek(week);
                        Navigator.pop(context);
                      },
                      child: Center(
                        child: Text(
                          '$week',
                          style: TextStyle(
                            fontSize: 15,
                            color: isCurrent ? Colors.white : Colors.grey[700],
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayHeader(ScheduleProvider provider) {
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final todayWeekday = DateTime.now().weekday; // 1=Mon ... 7=Sun

    return Container(
      padding: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          ...List.generate(7, (i) {
            final isToday = (i + 1) == todayWeekday;
            return Expanded(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: isToday
                      ? BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(
                    days[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday
                          ? AppTheme.primaryColor
                          : Colors.grey[500],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          5,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(ScheduleProvider provider) {
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
            child: Icon(Icons.wifi_off_rounded, size: 32, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(provider.error!,
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => provider.fetchSchedule(),
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

  Widget _buildGrid(ScheduleProvider provider, double availableHeight) {
    final slots = provider.currentWeekSlots;
    const totalSections = 12;
    final sectionHeight = availableHeight / totalSections;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧节次标签
        SizedBox(
          width: 28,
          child: Column(
            children: List.generate(totalSections, (i) {
              return Container(
                height: sectionHeight,
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
          ),
        ),
        // 7 天的列
        ...List.generate(7, (dayIndex) {
          final day = dayIndex + 1;
          final isToday = day == _todayDay;
          final daySlots = slots.where((s) => s.dayOfWeek == day).toList();
          return Expanded(
            child: Container(
              height: totalSections * sectionHeight,
              decoration: BoxDecoration(
                color: isToday
                    ? AppTheme.primaryColor.withValues(alpha: 0.03)
                    : null,
              ),
              child: Stack(
                children: [
                  // 网格线
                  ...List.generate(totalSections, (i) {
                    return Positioned(
                      top: i * sectionHeight,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: sectionHeight,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                                color: Colors.grey[100]!, width: 0.5),
                            right: BorderSide(
                                color: Colors.grey[100]!, width: 0.5),
                          ),
                        ),
                      ),
                    );
                  }),
                  // 课程卡片
                  ...daySlots.map(
                      (slot) => _buildCourseCard(slot, sectionHeight)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCourseCard(ScheduleSlot slot, double sectionHeight) {
    final top = (slot.startSection - 1) * sectionHeight;
    final height = (slot.endSection - slot.startSection + 1) * sectionHeight;
    final color = AppTheme.getCourseColor(slot.colorIndex);

    return Positioned(
      top: top + 1.5,
      left: 1.5,
      right: 1.5,
      height: height - 3,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showCourseDetail(slot);
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.courseName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.95),
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (slot.classroom.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 8, color: color.withValues(alpha: 0.6)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        slot.classroom,
                        style: TextStyle(
                          fontSize: 9,
                          color: color.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseDetail(ScheduleSlot slot) {
    final color = AppTheme.getCourseColor(slot.colorIndex);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽指示条
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 课程名标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${slot.startSection}-${slot.endSection}节',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                slot.courseName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _detailRow(Icons.access_time_rounded,
                  '第 ${slot.startSection}-${slot.endSection} 节'),
              _detailRow(Icons.location_on_outlined,
                  slot.classroom.isNotEmpty ? slot.classroom : '未安排'),
              if (slot.teachers.isNotEmpty)
                _detailRow(Icons.person_outline, slot.teachers.join('、')),
              _detailRow(
                  Icons.date_range_rounded, '周次：${_formatWeeks(slot.weeks)}'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final parts = <String>[];
    int start = weeks[0], prev = weeks[0];
    for (int i = 1; i < weeks.length; i++) {
      if (weeks[i] == prev + 1) {
        prev = weeks[i];
      } else {
        parts.add(start == prev ? '$start' : '$start-$prev');
        start = weeks[i];
        prev = weeks[i];
      }
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    return parts.join(', ');
  }
}
