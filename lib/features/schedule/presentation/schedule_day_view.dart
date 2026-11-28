part of 'schedule_screen.dart';

class _DayScheduleView extends StatelessWidget {
  final int dayIndex;
  final Map<String, String> primarySelections;
  final Future<void> Function({
    required String groupKey,
    required String itemKey,
  }) onPrimaryChanged;
  final bool isEditing;
  final VoidCallback onEnterEditMode;

  const _DayScheduleView({
    required this.dayIndex,
    required this.primarySelections,
    required this.onPrimaryChanged,
    required this.isEditing,
    required this.onEnterEditMode,
  });

  (int, int) _firstFreeSlot(
    List<ScheduleItem> dayItems,
    int week,
    ClassSession session,
  ) {
    final candidates = switch (session) {
      ClassSession.morning => const [(1, 2), (3, 4), (5, 5)],
      ClassSession.afternoon => const [(6, 7), (8, 9), (10, 10)],
      ClassSession.evening => const [(11, 12)],
    };
    final active = dayItems.where((e) => e.occursInWeek(week)).toList();
    for (final slot in candidates) {
      final busy = active.any(
        (e) => e.startUnit <= slot.$2 && slot.$1 <= e.endUnit,
      );
      if (!busy) return slot;
    }
    return candidates.first;
  }

  Widget _buildAddButton(
    BuildContext context,
    DataProvider dataProvider,
    List<ScheduleItem> dayItems,
    int currentWeek,
    ClassSession session,
    String label,
  ) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 54,
        child: DashedAddCell(
          color: color,
          radius: 12,
          iconSize: 20,
          label: label,
          onTap: () {
            final slot = _firstFreeSlot(dayItems, currentWeek, session);
            _openAddCourseSheet(
              context,
              dataProvider,
              dayIndex: dayIndex,
              startUnit: slot.$1,
              endUnit: slot.$2,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.read<DataProvider>();
    final groupedSchedule = context
        .select<DataProvider, Map<int, List<ScheduleItem>>>(
            (d) => d.scheduleGroupedByDay);
    final currentWeek = context.select<DataProvider, int>((d) => d.currentWeek);
    final effectiveWeek = currentWeek > 0 ? currentWeek : 1;

    final dayItems = groupedSchedule[dayIndex] ?? const [];

    if (!isEditing && dayItems.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onEnterEditMode,
        child: RefreshIndicator(
          onRefresh: () => refreshScheduleWithFeedback(context, dataProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 100),
              Center(
                child: Text('今天没有课哦 ~', style: TextStyle(color: Colors.grey)),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  '长按空白处可编辑或添加课程',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final conflictGroups = ScheduleConflict.groupOverlapping(dayItems);
    final resolvedGroups = conflictGroups.map((group) {
      final primary = ScheduleConflict.resolvePrimary(
        group: group,
        weekNumber: currentWeek,
        savedItemKey: primarySelections[ScheduleConflict.groupKey(group)],
      );
      return (group: group, primary: primary);
    }).toList()
      ..sort((a, b) => a.primary.startUnit.compareTo(b.primary.startUnit));

    final morningWidgets = <Widget>[];
    final afternoonWidgets = <Widget>[];
    final eveningWidgets = <Widget>[];

    for (final entry in resolvedGroups) {
      final widget = _CourseGroup(
        items: entry.group,
        currentWeek: currentWeek,
        primarySelections: primarySelections,
        onPrimaryChanged: onPrimaryChanged,
        isEditing: isEditing,
        onEnterEditMode: onEnterEditMode,
      );

      switch (PeriodTimeTable.sessionForPeriod(entry.primary.startPeriod)) {
        case ClassSession.morning:
          morningWidgets.add(widget);
        case ClassSession.afternoon:
          afternoonWidgets.add(widget);
        case ClassSession.evening:
          eveningWidgets.add(widget);
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: isEditing ? null : onEnterEditMode,
      child: RefreshIndicator(
        onRefresh: () => refreshScheduleWithFeedback(context, dataProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (isEditing || morningWidgets.isNotEmpty) ...[
              _buildSectionHeader(context, '上午'),
              ...morningWidgets,
              if (isEditing)
                _buildAddButton(
                  context,
                  dataProvider,
                  dayItems,
                  effectiveWeek,
                  ClassSession.morning,
                  '添加上午课程',
                ),
              const SizedBox(height: 16),
            ],
            if (isEditing || afternoonWidgets.isNotEmpty) ...[
              _buildSectionHeader(context, '下午'),
              ...afternoonWidgets,
              if (isEditing)
                _buildAddButton(
                  context,
                  dataProvider,
                  dayItems,
                  effectiveWeek,
                  ClassSession.afternoon,
                  '添加下午课程',
                ),
              const SizedBox(height: 16),
            ],
            if (isEditing || eveningWidgets.isNotEmpty) ...[
              _buildSectionHeader(context, '晚上'),
              ...eveningWidgets,
              if (isEditing)
                _buildAddButton(
                  context,
                  dataProvider,
                  dayItems,
                  effectiveWeek,
                  ClassSession.evening,
                  '添加晚上课程',
                ),
            ],
          ],
        ),
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
  final bool isEditing;
  final VoidCallback onEnterEditMode;

  const _CourseGroup({
    required this.items,
    required this.currentWeek,
    required this.primarySelections,
    required this.onPrimaryChanged,
    required this.isEditing,
    required this.onEnterEditMode,
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
    final cardOpacity =
        context.select<WallpaperProvider, double>((w) => w.listCardOpacity);
    final groupKey = ScheduleConflict.groupKey(widget.items);
    final primaryItem = ScheduleConflict.resolvePrimary(
      group: widget.items,
      weekNumber: widget.currentWeek,
      savedItemKey: widget.primarySelections[groupKey],
    );
    final primaryKey = ScheduleConflict.itemKey(primaryItem);
    final otherItems = widget.items
        .where((item) => ScheduleConflict.itemKey(item) != primaryKey)
        .toList()
      ..sort((a, b) {
        int score(ScheduleItem item) {
          if (item.occursInWeek(widget.currentWeek)) return 0;
          if (widget.currentWeek < item.weekStart) return 1;
          return 2;
        }

        final scoreCompare = score(a).compareTo(score(b));
        if (scoreCompare != 0) return scoreCompare;
        return ScheduleConflict.itemKey(a)
            .compareTo(ScheduleConflict.itemKey(b));
      });

    if (otherItems.isEmpty) {
      return _buildCourseCard(primaryItem, cardOpacity: cardOpacity);
    }

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildCourseCard(
              primaryItem,
              cardOpacity: cardOpacity,
              onNormalTap: _pickPrimaryCourse,
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isEditing) ...[
                    InkWell(
                      onTap: _pickPrimaryCourse,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                  ],
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
                padding: const EdgeInsets.only(left: 16.0),
                child: _buildCourseCard(
                  item,
                  cardOpacity: cardOpacity,
                  isSecondary: true,
                ),
              )),
      ],
    );
  }

  Widget _buildCourseCard(
    ScheduleItem item, {
    required double cardOpacity,
    bool isSecondary = false,
    VoidCallback? onNormalTap,
  }) {
    final effectiveWeek = widget.currentWeek > 0 ? widget.currentWeek : 1;
    final bool isCurrent = item.occursInWeek(effectiveWeek);
    final bool isFinished = item.weekEnd > 0 && effectiveWeek > item.weekEnd;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color accentColor;
    Color textColor;

    if (isCurrent) {
      bgColor = isDark ? const Color(0xFF1B2E1B) : const Color(0xFFF0F9EB);
      accentColor = theme.colorScheme.secondary;
      textColor = isDark ? Colors.white : Colors.black;
    } else if (isFinished) {
      bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;
      accentColor = Colors.grey;
      textColor = Colors.grey;
    } else {
      bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      accentColor = theme.colorScheme.tertiary;
      textColor = isDark ? Colors.white : Colors.black;
    }

    if (isSecondary && !isCurrent && !isFinished) {
      bgColor = isDark ? const Color(0xFF252525) : Colors.grey[50]!;
    }

    final dataProvider = context.read<DataProvider>();
    final weeksText = item.weeksLabel;

    final card = Card(
      elevation: 0,
      color: bgColor.withValues(alpha: cardOpacity),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent
              ? accentColor.withValues(alpha: .3)
              : Colors.grey.withValues(alpha: .1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: widget.onEnterEditMode,
        onTap: widget.isEditing
            ? () => _showCourseEditActions(
                  context,
                  dataProvider,
                  item: item,
                  week: effectiveWeek,
                  canAffectThisWeek: isCurrent,
                )
            : onNormalTap,
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
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.teacher} #${item.classroom}${weeksText.isNotEmpty ? ' @$weeksText' : ''}',
                      style: TextStyle(
                        color: isFinished
                            ? (isDark ? Colors.grey[500] : Colors.grey)
                            : (isDark ? Colors.white70 : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    color: isCurrent ? theme.colorScheme.secondary : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.isEditing) return card;

    return Jiggle(
      enabled: true,
      seed: item.name.hashCode ^ item.startUnit,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (isCurrent)
            Positioned(
              left: -4,
              top: -4,
              child: DeleteBadge(
                size: 20,
                onTap: () => _confirmDeleteOccurrence(
                  context,
                  dataProvider,
                  item,
                  effectiveWeek,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
