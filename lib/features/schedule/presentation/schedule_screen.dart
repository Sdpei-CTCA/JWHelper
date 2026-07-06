import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/features/schedule/data/schedule_conflict_store.dart';
import 'package:JWHelper/features/schedule/domain/schedule_conflict.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';

class ScheduleScreen extends StatefulWidget {
  final ValueNotifier<bool> isGridViewNotifier;
  final ValueNotifier<int> selectedWeekNotifier;
  const ScheduleScreen({super.key, required this.isGridViewNotifier, required this.selectedWeekNotifier});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Map<String, String> _primarySelections = {};

  @override
  void initState() {
    super.initState();
    _loadConflictSelections();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).loadSchedule();
    });
  }

  Future<void> _loadConflictSelections() async {
    final saved = await ScheduleConflictStore.loadAll();
    if (!mounted) return;
    setState(() => _primarySelections = saved);
  }

  Future<void> _updatePrimarySelection({
    required String groupKey,
    required String itemKey,
  }) async {
    await ScheduleConflictStore.savePrimary(
      groupKey: groupKey,
      itemKey: itemKey,
    );
    if (!mounted) return;
    setState(() {
      _primarySelections = Map<String, String>.from(_primarySelections)
        ..[groupKey] = itemKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallpaperProvider = context.watch<WallpaperProvider>();

    // Only rebuild when these specific properties change, avoiding unnecessary rebuilds when other data points (grades, exam etc.) change.
    final scheduleLoading = context.select<DataProvider, bool>((d) => d.scheduleLoading);
    final scheduleIsEmpty = context.select<DataProvider, bool>((d) => d.schedule.isEmpty);

    if (scheduleLoading && scheduleIsEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Simple Grid View for Schedule
    // 7 days x 6 slots (approx)
    // For mobile, maybe a list grouped by day is better?
    // Let's do a TabView for each day.

    return Stack(
      children: [
        // Wallpaper Background
        if (wallpaperProvider.wallpaperPath != null)
          Positioned.fill(
            child: Opacity(
              opacity: 1.0 - wallpaperProvider.opacity,
              child: Image.file(
                File(wallpaperProvider.wallpaperPath!),
                fit: BoxFit.cover,
                alignment: wallpaperProvider.wallpaperAlignment,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        
        // Main Content
        ValueListenableBuilder<bool>(
          valueListenable: widget.isGridViewNotifier,
          builder: (context, isGrid, child) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInBack,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: isGrid 
                ? _WeekScheduleGridView(
                    key: const ValueKey('grid'),
                    selectedWeekNotifier: widget.selectedWeekNotifier,
                    primarySelections: _primarySelections,
                    onPrimaryChanged: _updatePrimarySelection,
                  )
                : DefaultTabController(
                    key: const ValueKey('list'),
                    length: 7,
                    initialIndex: DateTime.now().weekday - 1,
                    child: Column(
                      children: [
                        Container(
                          color: theme.cardTheme.color?.withValues(alpha: 0.9),
                          child: TabBar(
                            isScrollable: false,
                            labelPadding: EdgeInsets.zero,
                            labelColor: theme.colorScheme.primary,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: theme.colorScheme.primary,
                            tabs: List.generate(7, (index) {
                              String dateStr = '';
                              final dpStartDay = context.read<DataProvider>().scheduleStartDay;
                              if (dpStartDay != null) {
                                try {
                                  final startDay = DateTime.parse(dpStartDay);
                                  final currentWeek = context.read<DataProvider>().currentWeek;
                                  final weekOffset = (currentWeek - 1) * 7;
                                  final dayDate = startDay.add(Duration(days: weekOffset + index));
                                  dateStr = '${dayDate.month}/${dayDate.day}';
                                } catch (_) {}
                              }
                              return Tab(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][index],
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    if (dateStr.isNotEmpty)
                                      Text(
                                        dateStr,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: List.generate(7, (dayIndex) {
                              return _DayScheduleView(
                                dayIndex: dayIndex,
                                primarySelections: _primarySelections,
                                onPrimaryChanged: _updatePrimarySelection,
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
            );
          },
        ),
      ],
    );
  }
}

Future<ScheduleItem?> _showConflictCoursePicker(
  BuildContext context, {
  required List<ScheduleItem> group,
  required ScheduleItem primary,
  required String subtitle,
}) {
  final currentPrimaryKey = ScheduleConflict.itemKey(primary);
  return showModalBottomSheet<ScheduleItem>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '该时段有 ${group.length} 门课程',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ...group.map((item) {
                final itemKey = ScheduleConflict.itemKey(item);
                final isSelected = itemKey == currentPrimaryKey;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${item.teacher} · ${item.classroom} · 第${item.startUnit}-${item.endUnit}节',
                  ),
                  onTap: () => Navigator.of(context).pop(item),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

class _DayScheduleView extends StatelessWidget {
  final int dayIndex;
  final Map<String, String> primarySelections;
  final Future<void> Function({
    required String groupKey,
    required String itemKey,
  }) onPrimaryChanged;

  const _DayScheduleView({
    required this.dayIndex,
    required this.primarySelections,
    required this.onPrimaryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.read<DataProvider>();
    // Listen to changes in the schedule precisely
    final groupedSchedule = context.select<DataProvider, Map<int, List<ScheduleItem>>>((d) => d.scheduleGroupedByDay);
    final currentWeek = context.select<DataProvider, int>((d) => d.currentWeek);

    final dayItems = groupedSchedule[dayIndex] ?? [];

    if (dayItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => dataProvider.loadSchedule(forceRefresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(
              child: Text("今天没有课哦 ~",
                  style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    // Group overlapping courses on this day
    final conflictGroups = ScheduleConflict.groupOverlapping(dayItems);
    conflictGroups.sort((a, b) {
      final aPrimary = ScheduleConflict.resolvePrimary(
        group: a,
        weekNumber: currentWeek,
        savedItemKey: primarySelections[ScheduleConflict.groupKey(a)],
      );
      final bPrimary = ScheduleConflict.resolvePrimary(
        group: b,
        weekNumber: currentWeek,
        savedItemKey: primarySelections[ScheduleConflict.groupKey(b)],
      );
      return aPrimary.startUnit.compareTo(bPrimary.startUnit);
    });

    List<Widget> morningWidgets = [];
    List<Widget> afternoonWidgets = [];
    List<Widget> eveningWidgets = [];

    for (final group in conflictGroups) {
      final primary = ScheduleConflict.resolvePrimary(
        group: group,
        weekNumber: currentWeek,
        savedItemKey: primarySelections[ScheduleConflict.groupKey(group)],
      );
      final widget = _CourseGroup(
        items: group,
        currentWeek: currentWeek,
        primarySelections: primarySelections,
        onPrimaryChanged: onPrimaryChanged,
      );

      if (primary.startPeriod <= 4) {
        morningWidgets.add(widget);
      } else if (primary.startPeriod <= 8) {
        afternoonWidgets.add(widget);
      } else {
        eveningWidgets.add(widget);
      }
    }

    return RefreshIndicator(
      onRefresh: () => dataProvider.loadSchedule(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (morningWidgets.isNotEmpty) ...[
            _buildSectionHeader(context, "上午"),
            ...morningWidgets,
            const SizedBox(height: 16),
          ],
          if (afternoonWidgets.isNotEmpty) ...[
            _buildSectionHeader(context, "下午"),
            ...afternoonWidgets,
            const SizedBox(height: 16),
          ],
          if (eveningWidgets.isNotEmpty) ...[
            _buildSectionHeader(context, "晚上"),
            ...eveningWidgets,
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final primaryColor = Theme.of(context).colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseGroup extends StatefulWidget {
  final List<ScheduleItem> items;
  final int currentWeek;
  final Map<String, String> primarySelections;
  final Future<void> Function({
    required String groupKey,
    required String itemKey,
  }) onPrimaryChanged;

  const _CourseGroup({
    required this.items,
    required this.currentWeek,
    required this.primarySelections,
    required this.onPrimaryChanged,
  });

  @override
  State<_CourseGroup> createState() => _CourseGroupState();
}

class _CourseGroupState extends State<_CourseGroup> {
  bool _isExpanded = false;

  Future<void> _pickPrimaryCourse() async {
    final groupKey = ScheduleConflict.groupKey(widget.items);
    final primary = ScheduleConflict.resolvePrimary(
      group: widget.items,
      weekNumber: widget.currentWeek,
      savedItemKey: widget.primarySelections[groupKey],
    );
    final picked = await _showConflictCoursePicker(
      context,
      group: widget.items,
      primary: primary,
      subtitle: '选择要在每日课表中默认显示的课程',
    );
    if (picked == null || !mounted) return;
    await widget.onPrimaryChanged(
      groupKey: groupKey,
      itemKey: ScheduleConflict.itemKey(picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupKey = ScheduleConflict.groupKey(widget.items);
    final primaryItem = ScheduleConflict.resolvePrimary(
      group: widget.items,
      weekNumber: widget.currentWeek,
      savedItemKey: widget.primarySelections[groupKey],
    );
    final otherItems = widget.items
        .where((item) => ScheduleConflict.itemKey(item) != ScheduleConflict.itemKey(primaryItem))
        .toList()
      ..sort((a, b) {
        int score(ScheduleItem item) {
          if (widget.currentWeek >= item.weekStart &&
              widget.currentWeek <= item.weekEnd) {
            return 0;
          }
          if (widget.currentWeek < item.weekStart) return 1;
          return 2;
        }

        final scoreCompare = score(a).compareTo(score(b));
        if (scoreCompare != 0) return scoreCompare;
        return ScheduleConflict.itemKey(a).compareTo(ScheduleConflict.itemKey(b));
      });

    if (otherItems.isEmpty) {
      return _buildCourseCard(primaryItem);
    }

    return Column(
      children: [
        Stack(
          children: [
            InkWell(
              onTap: _pickPrimaryCourse,
              borderRadius: BorderRadius.circular(12),
              child: _buildCourseCard(primaryItem),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _pickPrimaryCourse,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                                .cardTheme
                                .color
                                ?.withValues(alpha: 0.8) ??
                            Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_isExpanded)
          ...otherItems.map((item) => Padding(
                padding:
                    const EdgeInsets.only(left: 16.0), // Indent secondary items
                child: _buildCourseCard(item, isSecondary: true),
              )),
      ],
    );
  }

  Widget _buildCourseCard(ScheduleItem item, {bool isSecondary = false}) {
    bool isCurrent = widget.currentWeek >= item.weekStart &&
        widget.currentWeek <= item.weekEnd;
    bool isFinished = widget.currentWeek > item.weekEnd;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color accentColor;
    Color textColor;

    if (isCurrent) {
      bgColor = isDark ? const Color(0xFF1B2E1B) : const Color(0xFFF0F9EB);
      accentColor = Theme.of(context).colorScheme.secondary;
      textColor = isDark ? Colors.white : Colors.black;
    } else if (isFinished) {
      bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;
      accentColor = Colors.grey;
      textColor = Colors.grey;
    } else {
      bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      accentColor = Theme.of(context).colorScheme.tertiary;
      textColor = isDark ? Colors.white : Colors.black;
    }

    if (isSecondary) {
      // Secondary items might override bg slightly if not current
      if (!isCurrent && !isFinished) {
        bgColor = isDark ? const Color(0xFF252525) : Colors.grey[50]!;
      }
    }

    final cardOpacity = context.read<WallpaperProvider>().listCardOpacity;

    return Card(
      elevation: 0,
      color: bgColor.withValues(alpha: cardOpacity),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isCurrent
                ? accentColor.withValues(alpha: .3)
                : Colors.grey.withValues(alpha: .1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item.teacher} #${item.classroom}${item.weekStart > 0 && item.weekEnd > 0 ? ' @${item.weekStart}-${item.weekEnd}周' : ''}",
                    style: TextStyle(
                        color: isFinished
                            ? (isDark ? Colors.grey[500] : Colors.grey)
                            : (isDark ? Colors.white70 : Colors.grey[600])),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent
                    ? (isDark
                        ? const Color(0xFF1B2E1B)
                        : const Color(0xFFF0F9EB))
                    : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.periodString,
                style: TextStyle(
                    color: isCurrent ? Theme.of(context).colorScheme.secondary : Colors.grey,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekScheduleGridView extends StatefulWidget {
  final ValueNotifier<int> selectedWeekNotifier;
  final Map<String, String> primarySelections;
  final Future<void> Function({
    required String groupKey,
    required String itemKey,
  }) onPrimaryChanged;

  const _WeekScheduleGridView({
    super.key,
    required this.selectedWeekNotifier,
    required this.primarySelections,
    required this.onPrimaryChanged,
  });

  @override
  State<_WeekScheduleGridView> createState() => _WeekScheduleGridViewState();
}

class _WeekScheduleGridViewState extends State<_WeekScheduleGridView> {
  late PageController _pageController;
  bool _initialized = false;

  final List<Color> _courseColors = [
    const Color(0xFFE57373), // Red
    const Color(0xFFF06292), // Pink
    const Color(0xFFBA68C8), // Purple
    const Color(0xFF9575CD), // Deep Purple
    const Color(0xFF7986CB), // Indigo
    const Color(0xFF64B5F6), // Blue
    const Color(0xFF4FC3F7), // Light Blue
    const Color(0xFF4DD0E1), // Cyan
    const Color(0xFF4DB6AC), // Teal
    const Color(0xFF81C784), // Green
    const Color(0xFFAED581), // Light Green
    const Color(0xFFFFB74D), // Lime
    const Color(0xFFFFD54F), // Yellow
    const Color(0xFFFF8A65), // Deep Orange
    const Color(0xFFA1887F), // Brown
  ];

  final Map<String, Color> _courseColorMap = {};

  Color _getColorForCourse(String courseName, bool isDark) {
    if (!_courseColorMap.containsKey(courseName)) {
      int colorIndex = _courseColorMap.length % _courseColors.length;
      _courseColorMap[courseName] = _courseColors[colorIndex];
    }
    Color baseColor = _courseColorMap[courseName]!;
    
    if (isDark) {
      // Darken the colors a bit for dark mode to be less harsh
      return Color.fromARGB(
        255, 
        (baseColor.r * 255 * 0.55).toInt(), 
        (baseColor.g * 255 * 0.55).toInt(), 
        (baseColor.b * 255 * 0.55).toInt()
      );
    }
    
    return baseColor.withValues(alpha: 0.85); // Light mode slightly transparent
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final currentWeek = context.read<DataProvider>().currentWeek;
      final initialWeek = currentWeek > 0 ? currentWeek : 1;
      widget.selectedWeekNotifier.value = initialWeek;
      _pageController = PageController(initialPage: initialWeek - 1);
      widget.selectedWeekNotifier.addListener(_onWeekChanged);
      _initialized = true;
    }
  }

  void _onWeekChanged() {
    final target = widget.selectedWeekNotifier.value - 1;
    if (_pageController.hasClients && _pageController.page?.round() != target) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    widget.selectedWeekNotifier.removeListener(_onWeekChanged);
    _pageController.dispose();
    super.dispose();
  }

  String _getTimeForPeriod(int period, String campus) {
    if (campus == '济南') {
      switch (period) {
        case 1: return "8:00\n8:45";
        case 2: return "8:50\n9:35";
        case 3: return "10:00\n10:45";
        case 4: return "10:50\n11:35";
        case 5: return "13:30\n14:15";
        case 6: return "14:20\n15:05";
        case 7: return "15:30\n16:15";
        case 8: return "16:20\n17:05";
        case 9: return "18:00\n18:45";
        case 10: return "18:50\n19:35";
        case 11: return "20:00\n20:45";
        case 12: return "20:50\n21:35";
        default: return "";
      }
    } else {
      // 日照校区
      final now = DateTime.now();
      // 判断是否夏令时: 5月1日至10月1日
      bool isSummer = false;
      if (now.month > 5 && now.month < 10) {
        isSummer = true;
      } else if (now.month == 5 || now.month == 10) {
        isSummer = now.month == 5; // 5月1日及之后，10月1日也是最后一天，粗略按月份即可：5,6,7,8,9是夏季
      }

      switch (period) {
        case 1: return "8:00\n8:45";
        case 2: return "8:50\n9:35";
        case 3: return "10:00\n10:45";
        case 4: return "10:50\n11:35";
        case 5: return isSummer ? "14:30\n15:15" : "14:00\n14:45";
        case 6: return isSummer ? "15:20\n16:05" : "14:50\n15:35";
        case 7: return isSummer ? "16:30\n17:15" : "16:00\n16:45";
        case 8: return isSummer ? "17:20\n18:05" : "16:50\n17:35";
        case 9: return "19:00\n19:45";
        case 10: return "19:50\n20:35";
        case 11: return "20:40\n21:25";
        case 12: return "21:30\n22:15";
        default: return "";
      }
    }
  }

  void _showCourseDetails(BuildContext context, ScheduleItem item) {
    final List<String> weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(Icons.calendar_month, "上课周次: 第${item.weekStart}周 - 第${item.weekEnd}周"),
              const SizedBox(height: 8),
              _detailRow(Icons.access_time, "上课时间: 周${weekDays[item.dayIndex]} 第${item.startUnit}-${item.endUnit}节"),
              const SizedBox(height: 8),
              _detailRow(Icons.person, "任课老师: ${item.teacher}"),
              const SizedBox(height: 8),
              _detailRow(Icons.location_on, "上课地点: ${item.classroom}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("关闭"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGridCellTap({
    required BuildContext context,
    required List<ScheduleItem> group,
    required ScheduleItem primary,
  }) async {
    if (group.length == 1) {
      _showCourseDetails(context, primary);
      return;
    }

    final groupKey = ScheduleConflict.groupKey(group);
    final picked = await _showConflictCoursePicker(
      context,
      group: group,
      primary: primary,
      subtitle: '选择要在每周课表格子中显示的课程',
    );
    if (picked == null || !mounted) return;

    await widget.onPrimaryChanged(
      groupKey: groupKey,
      itemKey: ScheduleConflict.itemKey(picked),
    );
    if (!context.mounted) return;
    _showCourseDetails(context, picked);
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.tertiary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final schedule = dataProvider.schedule;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final wallpaperProvider = context.read<WallpaperProvider>();

    // Compute effective background brightness accounting for wallpaper overlay
    final bool effectiveIsDark;
    if (wallpaperProvider.wallpaperPath != null) {
      // Blend: overlay opacity = wallpaperProvider.opacity, rest is wallpaper (assume dark-ish)
      final overlayLuminance = theme.scaffoldBackgroundColor.computeLuminance();
      final wallpaperLuminance = wallpaperProvider.primaryColor.computeLuminance();
      final effectiveLuminance = wallpaperLuminance * (1 - wallpaperProvider.opacity) + overlayLuminance * wallpaperProvider.opacity;
      effectiveIsDark = effectiveLuminance < 0.5;
    } else {
      effectiveIsDark = isDark;
    }

    // Helper for adaptive text color
    Color primaryTextColor({double lightAlpha = 1.0, double darkAlpha = 1.0}) =>
        effectiveIsDark ? Colors.white.withValues(alpha: darkAlpha) : Colors.black.withValues(alpha: lightAlpha);
    Color secondaryTextColor({double lightAlpha = 0.85, double darkAlpha = 0.7}) =>
        effectiveIsDark ? Colors.white.withValues(alpha: darkAlpha) : Colors.black.withValues(alpha: lightAlpha);
    Color tertiaryTextColor({double lightAlpha = 0.55, double darkAlpha = 0.5}) =>
        effectiveIsDark ? Colors.white.withValues(alpha: darkAlpha) : Colors.black.withValues(alpha: lightAlpha);

    int maxPeriod = 12;
    for (var item in schedule) {
      if (item.endUnit > maxPeriod) {
        maxPeriod = item.endUnit;
      }
    }

    final double cellWidth = MediaQuery.of(context).size.width / 7.5;
    final double timeColumnWidth = cellWidth * 0.8;
    final double dayCellWidth = (MediaQuery.of(context).size.width - timeColumnWidth) / 7;
    const double cellHeight = 60.0;
    const List<String> weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    return ValueListenableBuilder<int>(
      valueListenable: widget.selectedWeekNotifier,
      builder: (context, selectedWeek, _) {
    return Column(
      children: [
        // Header Days
        Row(
          children: [
            SizedBox(width: timeColumnWidth),
            ...List.generate(7, (index) {
              final isToday = (DateTime.now().weekday - 1) == index && dataProvider.currentWeek == selectedWeek;
              
              // Calculate date for this weekday in the selected week
              String dateStr = '';
              final startDayStr = dataProvider.scheduleStartDay;
              if (startDayStr != null) {
                try {
                  final startDay = DateTime.parse(startDayStr);
                  final weekOffset = (selectedWeek - 1) * 7;
                  final dayDate = startDay.add(Duration(days: weekOffset + index));
                  dateStr = '${dayDate.month}/${dayDate.day}';
                } catch (_) {}
              }
              
              return SizedBox(
                width: dayCellWidth,
                height: 56,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '周${weekDays[index]}',
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? Theme.of(context).colorScheme.primary : primaryTextColor(),
                          fontSize: 13,
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                                : tertiaryTextColor(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),

        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: 25,
            onPageChanged: (index) {
              final newWeek = index + 1;
              if (widget.selectedWeekNotifier.value != newWeek) {
                widget.selectedWeekNotifier.value = newWeek;
              }
            },
            itemBuilder: (context, pageIndex) {
                  final weekNumber = pageIndex + 1;
                  final weekSchedule = schedule.where((item) => 
                    weekNumber >= item.weekStart && weekNumber <= item.weekEnd
                  ).toList();
                  final conflictGroups = ScheduleConflict.groupOverlapping(weekSchedule);

                  return SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sidebar (Periods and Times)
                        Column(
                          children: List.generate(maxPeriod, (index) => SizedBox(
                            width: timeColumnWidth,
                            height: cellHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: secondaryTextColor(),
                                  ),
                                ),
                                Text(
                                  _getTimeForPeriod(index + 1, dataProvider.campus),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: tertiaryTextColor(),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ),
                        // Schedule Stack
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: dayCellWidth * 7,
                              height: cellHeight * maxPeriod,
                              child: Stack(
                                children: [
                                  for (int i = 1; i < maxPeriod; i++)
                                    Positioned(
                                      top: i * cellHeight,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 1,
                                        color: effectiveIsDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      ),
                                    ),
                                  for (int i = 1; i < 7; i++)
                                    Positioned(
                                      top: 0,
                                      bottom: 0,
                                      left: i * dayCellWidth,
                                      child: Container(
                                        width: 1,
                                        color: effectiveIsDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      ),
                                    ),
                                  ...conflictGroups.map((group) {
                                    final groupKey = ScheduleConflict.groupKey(group);
                                    final primary = ScheduleConflict.resolvePrimary(
                                      group: group,
                                      weekNumber: weekNumber,
                                      savedItemKey: widget.primarySelections[groupKey],
                                    );
                                    Color bgColor = _getColorForCourse(primary.name, isDark);
                                    const textColor = Colors.white;
                                    final cardOpacity = context.read<WallpaperProvider>().gridCardOpacity;
                                    final hasConflict = group.length > 1;

                                    return Positioned(
                                      left: primary.dayIndex * dayCellWidth,
                                      top: (primary.startUnit - 1) * cellHeight,
                                      width: dayCellWidth,
                                      height: (primary.endUnit - primary.startUnit + 1) * cellHeight,
                                      child: InkWell(
                                        onTap: () => _handleGridCellTap(
                                          context: context,
                                          group: group,
                                          primary: primary,
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.all(1),
                                          decoration: BoxDecoration(
                                            color: bgColor.withValues(alpha: cardOpacity),
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              )
                                            ],
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                          child: Stack(
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    primary.name,
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                                                    maxLines: ((primary.endUnit - primary.startUnit + 1) * 2).toInt(),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "@${primary.classroom}",
                                                    style: const TextStyle(fontSize: 9, color: textColor),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                              if (hasConflict)
                                                Positioned(
                                                  right: 0,
                                                  top: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.35),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '${group.length}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
    },
    );
  }
}

