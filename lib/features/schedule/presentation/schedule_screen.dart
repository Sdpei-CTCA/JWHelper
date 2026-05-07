import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class ScheduleScreen extends StatefulWidget {
  final ValueNotifier<bool> isGridViewNotifier;
  const ScheduleScreen({super.key, required this.isGridViewNotifier});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).loadSchedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

    return ValueListenableBuilder<bool>(
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
            ? const _WeekScheduleGridView(key: ValueKey('grid'))
            : DefaultTabController(
                key: const ValueKey('list'),
                length: 7,
                initialIndex: DateTime.now().weekday - 1,
                child: Column(
                  children: [
                    Container(
                      color: theme.cardTheme.color,
                      child: const TabBar(
                        isScrollable: false,
                        labelPadding: EdgeInsets.zero,
                        labelColor: Color(0xFF409EFF),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Color(0xFF409EFF),
                        tabs: [
                          Tab(text: "周一"),
                          Tab(text: "周二"),
                          Tab(text: "周三"),
                          Tab(text: "周四"),
                          Tab(text: "周五"),
                          Tab(text: "周六"),
                          Tab(text: "周日"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: List.generate(7, (dayIndex) {
                          return _DayScheduleView(dayIndex: dayIndex);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }
}

class _DayScheduleView extends StatelessWidget {
  final int dayIndex;

  const _DayScheduleView({required this.dayIndex});

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

    // Group items by start unit to handle overlaps
    Map<int, List<ScheduleItem>> groupedItems = {};
    for (var item in dayItems) {
      if (!groupedItems.containsKey(item.startUnit)) {
        groupedItems[item.startUnit] = [];
      }
      groupedItems[item.startUnit]!.add(item);
    }

    // Sort groups by start unit
    var sortedKeys = groupedItems.keys.toList()..sort();

    // Helper to process a group
    Widget processGroup(int startUnit) {
      var group = groupedItems[startUnit]!;
      return _CourseGroup(items: group, currentWeek: currentWeek);
    }

    List<Widget> morningWidgets = [];
    List<Widget> afternoonWidgets = [];
    List<Widget> eveningWidgets = [];

    for (var key in sortedKeys) {
      var item = groupedItems[key]!.first; // Representative for time check
      var widget = processGroup(key);

      if (item.startPeriod <= 4) {
        morningWidgets.add(widget);
      } else if (item.startPeriod <= 8) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF409EFF),
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

  const _CourseGroup({required this.items, required this.currentWeek});

  @override
  State<_CourseGroup> createState() => _CourseGroupState();
}

class _CourseGroupState extends State<_CourseGroup> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Sort: Current -> Upcoming -> Finished
    var sortedItems = List<ScheduleItem>.from(widget.items);
    sortedItems.sort((a, b) {
      int getScore(ScheduleItem item) {
        if (widget.currentWeek >= item.weekStart &&
            widget.currentWeek <= item.weekEnd) {
          return 0; // Current
        }
        if (widget.currentWeek < item.weekStart) return 1; // Upcoming
        return 2; // Finished
      }

      return getScore(a).compareTo(getScore(b));
    });

    final primaryItem = sortedItems.first;
    final otherItems = sortedItems.skip(1).toList();

    if (otherItems.isEmpty) {
      return _buildCourseCard(primaryItem);
    }

    return Column(
      children: [
        Stack(
          children: [
            _buildCourseCard(primaryItem),
            Positioned(
              right: 8,
              top: 8,
              child: InkWell(
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
                            blurRadius: 2)
                      ]),
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.blue,
                  ),
                ),
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
      accentColor = const Color(0xFF67C23A);
      textColor = isDark ? Colors.white : Colors.black;
    } else if (isFinished) {
      bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;
      accentColor = Colors.grey;
      textColor = Colors.grey;
    } else {
      bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      accentColor = const Color(0xFF409EFF);
      textColor = isDark ? Colors.white : Colors.black;
    }

    if (isSecondary) {
      // Secondary items might override bg slightly if not current
      if (!isCurrent && !isFinished) {
        bgColor = isDark ? const Color(0xFF252525) : Colors.grey[50]!;
      }
    }

    return Card(
      elevation: 0,
      color: bgColor,
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
                        color: isFinished ? Colors.grey : Colors.grey[600]),
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
                    color: isCurrent ? const Color(0xFF67C23A) : Colors.grey,
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
  const _WeekScheduleGridView({super.key});

  @override
  State<_WeekScheduleGridView> createState() => _WeekScheduleGridViewState();
}

class _WeekScheduleGridViewState extends State<_WeekScheduleGridView> {
  late PageController _pageController;
  int _selectedWeek = 1;
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
      _selectedWeek = currentWeek > 0 ? currentWeek : 1;
      // Let's assume max 25 weeks. So initial page is selectedWeek - 1.
      _pageController = PageController(initialPage: _selectedWeek - 1);
      _initialized = true;
    }
  }

  @override
  void dispose() {
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

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF409EFF)),
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

    int maxPeriod = 12;
    for (var item in schedule) {
      if (item.endUnit > maxPeriod) {
        maxPeriod = item.endUnit;
      }
    }

    final double cellWidth = MediaQuery.of(context).size.width / 7.5;
    final double timeColumnWidth = cellWidth * 0.8;
    final double dayCellWidth = (MediaQuery.of(context).size.width - timeColumnWidth) / 7;
    final double cellHeight = 60.0;
    final List<String> weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    return Column(
      children: [
        // Week selector header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: theme.cardTheme.color,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  if (_selectedWeek > 1) {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
              ),
              Text(
                "第 $_selectedWeek 周",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  if (_selectedWeek < 25) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
              ),
            ],
          ),
        ),
        
        // Header Days
        Row(
          children: [
            SizedBox(width: timeColumnWidth),
            ...List.generate(7, (index) {
              final isToday = (DateTime.now().weekday - 1) == index && dataProvider.currentWeek == _selectedWeek;
              return SizedBox(
                width: dayCellWidth,
                height: 40,
                child: Center(
                  child: Text(
                    '周${weekDays[index]}',
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? const Color(0xFF409EFF) : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),

        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: 25, // Assuming max 25 weeks
            onPageChanged: (index) {
              setState(() {
                _selectedWeek = index + 1;
              });
            },
            itemBuilder: (context, pageIndex) {
              final weekNumber = pageIndex + 1;
              
              // Filter schedule for this specific week
              final weekSchedule = schedule.where((item) => 
                weekNumber >= item.weekStart && weekNumber <= item.weekEnd
              ).toList();

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
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            Text(
                              _getTimeForPeriod(index + 1, dataProvider.campus),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.white54 : Colors.black54,
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
                              // Background grid lines
                              for (int i = 1; i < maxPeriod; i++)
                                Positioned(
                                  top: i * cellHeight,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 1,
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                              for (int i = 1; i < 7; i++)
                                Positioned(
                                  top: 0,
                                  bottom: 0,
                                  left: i * dayCellWidth,
                                  child: Container(
                                    width: 1,
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                              // Items
                              ...weekSchedule.map((item) {
                                Color bgColor = _getColorForCourse(item.name, isDark);
                                Color textColor = Colors.white; // Mostly white text on colored bg works well

                                return Positioned(
                                  left: item.dayIndex * dayCellWidth,
                                  top: (item.startUnit - 1) * cellHeight,
                                  width: dayCellWidth,
                                  height: (item.endUnit - item.startUnit + 1) * cellHeight,
                                  child: InkWell(
                                    onTap: () => _showCourseDetails(context, item),
                                    child: Container(
                                      margin: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(
                                        color: bgColor,
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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                                            maxLines: ((item.endUnit - item.startUnit + 1) * 2).toInt(),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "@${item.classroom}",
                                            style: TextStyle(fontSize: 9, color: textColor),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }), // End of map
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
  }
}

