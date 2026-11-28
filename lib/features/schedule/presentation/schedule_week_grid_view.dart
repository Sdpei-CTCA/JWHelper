part of 'schedule_screen.dart';

class _WeekScheduleGridView extends StatefulWidget {
  final ValueNotifier<int> selectedWeekNotifier;
  final Map<String, String> primarySelections;
  final Future<void> Function({
    required String groupKey,
    required String itemKey,
  }) onPrimaryChanged;
  final bool isEditing;
  final VoidCallback onEnterEditMode;

  const _WeekScheduleGridView({
    super.key,
    required this.selectedWeekNotifier,
    required this.primarySelections,
    required this.onPrimaryChanged,
    required this.isEditing,
    required this.onEnterEditMode,
  });

  @override
  State<_WeekScheduleGridView> createState() => _WeekScheduleGridViewState();
}

class _WeekScheduleGridViewState extends State<_WeekScheduleGridView> {
  static const List<Color> _courseColors = [
    Color(0xFFE57373), // Red
    Color(0xFFF06292), // Pink
    Color(0xFFBA68C8), // Purple
    Color(0xFF9575CD), // Deep Purple
    Color(0xFF7986CB), // Indigo
    Color(0xFF64B5F6), // Blue
    Color(0xFF4FC3F7), // Light Blue
    Color(0xFF4DD0E1), // Cyan
    Color(0xFF4DB6AC), // Teal
    Color(0xFF81C784), // Green
    Color(0xFFAED581), // Light Green
    Color(0xFFFFB74D), // Lime
    Color(0xFFFFD54F), // Yellow
    Color(0xFFFF8A65), // Deep Orange
    Color(0xFFA1887F), // Brown
  ];

  late PageController _pageController;
  bool _initialized = false;
  final Map<String, Color> _courseColorMap = {};

  Color _getColorForCourse(String courseName, bool isDark) {
    final baseColor = _courseColorMap.putIfAbsent(
      courseName,
      () => _courseColors[_courseColorMap.length % _courseColors.length],
    );

    if (isDark) {
      return Color.fromARGB(
        255,
        (baseColor.r * 255 * 0.55).toInt(),
        (baseColor.g * 255 * 0.55).toInt(),
        (baseColor.b * 255 * 0.55).toInt(),
      );
    }

    return baseColor.withValues(alpha: 0.85);
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

  void _showCourseDetails(BuildContext context, ScheduleItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(
                Icons.calendar_month,
                '上课周次: ${item.weeksLabel.isNotEmpty ? item.weeksLabel : '未知'}',
              ),
              const SizedBox(height: 8),
              _detailRow(
                Icons.access_time,
                '上课时间: 周${_kScheduleWeekDayLabels[item.dayIndex]} 第${item.startUnit}-${item.endUnit}节',
              ),
              const SizedBox(height: 8),
              _detailRow(Icons.person, '任课老师: ${item.teacher}'),
              const SizedBox(height: 8),
              _detailRow(Icons.location_on, '上课地点: ${item.classroom}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
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

  Future<void> _handleEditCellTap({
    required BuildContext context,
    required DataProvider dataProvider,
    required List<ScheduleItem> group,
    required ScheduleItem primary,
    required int weekNumber,
  }) async {
    ScheduleItem target = primary;
    if (group.length > 1) {
      final picked = await _showConflictCoursePicker(
        context,
        group: group,
        primary: primary,
        subtitle: '选择要编辑或调课的课程',
      );
      if (picked == null || !context.mounted) return;
      target = picked;
    }
    if (!context.mounted) return;
    await _showCourseEditActions(
      context,
      dataProvider,
      item: target,
      week: weekNumber,
      canAffectThisWeek: true,
    );
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

  Widget _buildGridCourseContent({
    required ScheduleItem primary,
    required Color bgColor,
    required double cardOpacity,
    required int groupLength,
  }) {
    const textColor = Colors.white;
    final hasConflict = groupLength > 1;
    return Container(
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
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: ((primary.endUnit - primary.startUnit + 1) * 2).toInt(),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '@${primary.classroom}',
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
                  '$groupLength',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.read<DataProvider>();
    final dataState = context.select<
        DataProvider,
        ({
          List<ScheduleItem> schedule,
          int currentWeek,
          String? startDay,
          String campus,
        })>(
      (d) => (
        schedule: d.schedule,
        currentWeek: d.currentWeek,
        startDay: d.scheduleStartDay,
        campus: d.campus,
      ),
    );
    final wpState = context.select<
        WallpaperProvider,
        ({
          bool hasWallpaper,
          double opacity,
          Color primaryColor,
          double gridCardOpacity,
        })>(
      (w) => (
        hasWallpaper: w.wallpaperPath != null,
        opacity: w.opacity,
        primaryColor: w.primaryColor,
        gridCardOpacity: w.gridCardOpacity,
      ),
    );

    final schedule = dataState.schedule;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool effectiveIsDark;
    if (wpState.hasWallpaper) {
      final overlayLuminance = theme.scaffoldBackgroundColor.computeLuminance();
      final wallpaperLuminance = wpState.primaryColor.computeLuminance();
      final effectiveLuminance =
          wallpaperLuminance * (1 - wpState.opacity) +
              overlayLuminance * wpState.opacity;
      effectiveIsDark = effectiveLuminance < 0.5;
    } else {
      effectiveIsDark = isDark;
    }

    Color primaryTextColor({double lightAlpha = 1.0, double darkAlpha = 1.0}) =>
        effectiveIsDark
            ? Colors.white.withValues(alpha: darkAlpha)
            : Colors.black.withValues(alpha: lightAlpha);
    Color secondaryTextColor(
            {double lightAlpha = 0.85, double darkAlpha = 0.7}) =>
        effectiveIsDark
            ? Colors.white.withValues(alpha: darkAlpha)
            : Colors.black.withValues(alpha: lightAlpha);
    Color tertiaryTextColor(
            {double lightAlpha = 0.55, double darkAlpha = 0.5}) =>
        effectiveIsDark
            ? Colors.white.withValues(alpha: darkAlpha)
            : Colors.black.withValues(alpha: lightAlpha);

    final maxPeriod = _maxPeriodFor(schedule);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final double cellWidth = screenWidth / 7.5;
    final double timeColumnWidth = cellWidth * 0.8;
    final double dayCellWidth = (screenWidth - timeColumnWidth) / 7;
    const double cellHeight = 60.0;
    final startDay =
        dataState.startDay != null ? DateTime.tryParse(dataState.startDay!) : null;
    final todayWeekdayIndex = DateTime.now().weekday - 1;
    final gridLineColor =
        effectiveIsDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

    return Column(
      children: [
        // 顶部星期与日期行：仅此行监听 selectedWeekNotifier，翻周时不触发下方 PageView 重建。
        ValueListenableBuilder<int>(
          valueListenable: widget.selectedWeekNotifier,
          builder: (context, selectedWeek, _) {
            final weekOffset = (selectedWeek - 1) * 7;
            return Row(
              children: [
                SizedBox(width: timeColumnWidth),
                ...List.generate(7, (index) {
                  final isToday = todayWeekdayIndex == index &&
                      dataState.currentWeek == selectedWeek;
                  String dateStr = '';
                  if (startDay != null) {
                    final dayDate =
                        startDay.add(Duration(days: weekOffset + index));
                    dateStr = '${dayDate.month}/${dayDate.day}';
                  }
                  return SizedBox(
                    width: dayCellWidth,
                    height: 56,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '周${_kScheduleWeekDayLabels[index]}',
                            style: TextStyle(
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : primaryTextColor(),
                              fontSize: 13,
                            ),
                          ),
                          if (dateStr.isNotEmpty)
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isToday
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.8)
                                    : tertiaryTextColor(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: widget.isEditing ? null : widget.onEnterEditMode,
            child: PageView.builder(
              controller: _pageController,
              itemCount: ScheduleItem.maxTeachingWeeks,
              onPageChanged: (index) {
                final newWeek = index + 1;
                if (widget.selectedWeekNotifier.value != newWeek) {
                  widget.selectedWeekNotifier.value = newWeek;
                }
              },
              itemBuilder: (context, pageIndex) {
              final weekNumber = pageIndex + 1;
              final weekSchedule = schedule
                  .where((item) => item.occursInWeek(weekNumber))
                  .toList();
              final conflictGroups =
                  ScheduleConflict.groupOverlapping(weekSchedule);
              final occupied = <(int, int)>{};
              if (widget.isEditing) {
                for (final item in weekSchedule) {
                  for (int p = item.startUnit; p <= item.endUnit; p++) {
                    occupied.add((item.dayIndex, p));
                  }
                }
              }

              return SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧节次与作息时间栏
                    Column(
                      children: List.generate(maxPeriod, (index) {
                        final period = index + 1;
                        return SizedBox(
                          width: timeColumnWidth,
                          height: cellHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$period',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryTextColor(),
                                ),
                              ),
                              Text(
                                PeriodTimeTable.formatScheduleCell(
                                  period,
                                  campus: dataState.campus,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: tertiaryTextColor(),
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    // 7 列课表网格（去掉多余的横向 SingleChildScrollView，消除与 PageView 的手势竞争）
                    Expanded(
                      child: SizedBox(
                        width: dayCellWidth * 7,
                        height: cellHeight * maxPeriod,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _ScheduleGridLinesPainter(
                                    maxPeriod: maxPeriod,
                                    cellHeight: cellHeight,
                                    dayCellWidth: dayCellWidth,
                                    lineColor: gridLineColor,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.isEditing)
                              for (int day = 0; day < 7; day++)
                                for (int period = 1;
                                    period <= maxPeriod;
                                    period++)
                                  if (!occupied.contains((day, period)))
                                    Positioned(
                                      left: day * dayCellWidth,
                                      top: (period - 1) * cellHeight,
                                      width: dayCellWidth,
                                      height: cellHeight,
                                      child: DragTarget<ScheduleItem>(
                                        onWillAcceptWithDetails: (details) =>
                                            ScheduleEditor.canMoveOccurrence(
                                          schedule,
                                          details.data,
                                          fromWeek: weekNumber,
                                          toWeek: weekNumber,
                                          toDay: day,
                                          toStartUnit: period,
                                          maxUnit: maxPeriod,
                                        ),
                                        onAcceptWithDetails: (details) {
                                          dataProvider.moveScheduleOccurrence(
                                            details.data,
                                            fromWeek: weekNumber,
                                            toWeek: weekNumber,
                                            toDay: day,
                                            toStartUnit: period,
                                          );
                                        },
                                        builder: (context, candidateData,
                                            rejectedData) {
                                          if (rejectedData.isNotEmpty) {
                                            return Container(
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.error
                                                    .withValues(alpha: 0.18),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color:
                                                      theme.colorScheme.error,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.block,
                                                size: 16,
                                                color: theme.colorScheme.error,
                                              ),
                                            );
                                          }
                                          return DashedAddCell(
                                            color: tertiaryTextColor(
                                              lightAlpha: 0.5,
                                              darkAlpha: 0.5,
                                            ),
                                            radius: 4,
                                            iconSize: 16,
                                            highlighted:
                                                candidateData.isNotEmpty,
                                            onTap: () => _openAddCourseSheet(
                                              context,
                                              dataProvider,
                                              dayIndex: day,
                                              startUnit: period,
                                              endUnit: math.min(
                                                  period + 1, maxPeriod),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ...conflictGroups.map((group) {
                              final groupKey = ScheduleConflict.groupKey(group);
                              final primary = ScheduleConflict.resolvePrimary(
                                group: group,
                                weekNumber: weekNumber,
                                savedItemKey:
                                    widget.primarySelections[groupKey],
                              );
                              final bgColor =
                                  _getColorForCourse(primary.name, isDark);
                              final cellBoxHeight =
                                  (primary.endUnit - primary.startUnit + 1) *
                                      cellHeight;

                              final courseBox = _buildGridCourseContent(
                                primary: primary,
                                bgColor: bgColor,
                                cardOpacity: wpState.gridCardOpacity,
                                groupLength: group.length,
                              );

                              if (!widget.isEditing) {
                                return Positioned(
                                  left: primary.dayIndex * dayCellWidth,
                                  top: (primary.startUnit - 1) * cellHeight,
                                  width: dayCellWidth,
                                  height: cellBoxHeight,
                                  child: InkWell(
                                    onLongPress: widget.onEnterEditMode,
                                    onTap: () => _handleGridCellTap(
                                      context: context,
                                      group: group,
                                      primary: primary,
                                    ),
                                    child: courseBox,
                                  ),
                                );
                              }

                              final editableCard = Jiggle(
                                enabled: true,
                                seed: primary.name.hashCode ^
                                    primary.dayIndex ^
                                    primary.startUnit,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () => _handleEditCellTap(
                                          context: context,
                                          dataProvider: dataProvider,
                                          group: group,
                                          primary: primary,
                                          weekNumber: weekNumber,
                                        ),
                                        child: courseBox,
                                      ),
                                    ),
                                    Positioned(
                                      left: -4,
                                      top: -4,
                                      child: DeleteBadge(
                                        size: 16,
                                        onTap: () => _confirmDeleteOccurrence(
                                          context,
                                          dataProvider,
                                          primary,
                                          weekNumber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              return Positioned(
                                left: primary.dayIndex * dayCellWidth,
                                top: (primary.startUnit - 1) * cellHeight,
                                width: dayCellWidth,
                                height: cellBoxHeight,
                                child: Draggable<ScheduleItem>(
                                  data: primary,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Opacity(
                                      opacity: 0.85,
                                      child: SizedBox(
                                        width: dayCellWidth,
                                        height: cellBoxHeight,
                                        child: courseBox,
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.25,
                                    child: courseBox,
                                  ),
                                  child: editableCard,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleGridLinesPainter extends CustomPainter {
  const _ScheduleGridLinesPainter({
    required this.maxPeriod,
    required this.cellHeight,
    required this.dayCellWidth,
    required this.lineColor,
  });

  final int maxPeriod;
  final double cellHeight;
  final double dayCellWidth;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    for (int i = 1; i < maxPeriod; i++) {
      final y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (int i = 1; i < 7; i++) {
      final x = i * dayCellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScheduleGridLinesPainter oldDelegate) {
    return oldDelegate.maxPeriod != maxPeriod ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.dayCellWidth != dayCellWidth ||
        oldDelegate.lineColor != lineColor;
  }
}
