import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/core/constants/period_time_table.dart';
import 'package:JWHelper/features/auth/presentation/auth_provider.dart';
import 'package:JWHelper/features/schedule/data/schedule_conflict_store.dart';
import 'package:JWHelper/features/schedule/domain/schedule_conflict.dart';
import 'package:JWHelper/features/schedule/domain/schedule_editor.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/features/schedule/presentation/course_editor_sheet.dart';
import 'package:JWHelper/features/schedule/presentation/course_move_sheet.dart';
import 'package:JWHelper/features/schedule/presentation/widgets/jiggle.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';

part 'schedule_day_view.dart';
part 'schedule_week_grid_view.dart';

const List<String> _kScheduleWeekDayLabels = ['一', '二', '三', '四', '五', '六', '日'];
const List<String> _kScheduleWeekDayTabs = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 弹窗确认后，从教务网站重新拉取最新课表并覆盖本地自定义课表。
///
/// 设置页「恢复课表」、标题栏本地模式小图标、本地模式下的下拉刷新三处共用。
Future<void> confirmAndRestoreSchedule(
  BuildContext context,
  DataProvider dataProvider,
) async {
  final isLocal = dataProvider.isScheduleLocalMode;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('恢复课表'),
      content: Text(
        isLocal
            ? '将从教务网站重新获取最新课表，当前的调课和自定义课程将被覆盖，确定继续吗？'
            : '确定从教务网站重新获取最新课表吗？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('确认恢复'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final message = await dataProvider.restoreScheduleFromServer();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

Future<void> refreshScheduleWithFeedback(
  BuildContext context,
  DataProvider dataProvider,
) async {
  if (dataProvider.isScheduleLocalMode) {
    await confirmAndRestoreSchedule(context, dataProvider);
    return;
  }
  final message = await dataProvider.loadSchedule(forceRefresh: true);
  if (message != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

int _defaultMaxWeekFor(List<ScheduleItem> schedule) {
  int maxW = 0;
  for (final item in schedule) {
    if (item.weekEnd > maxW) maxW = item.weekEnd;
  }
  if (maxW <= 0) return 16;
  return maxW.clamp(1, ScheduleItem.maxTeachingWeeks);
}

int _maxPeriodFor(List<ScheduleItem> schedule) {
  int maxPeriod = 12;
  for (final item in schedule) {
    if (item.endUnit > maxPeriod) maxPeriod = item.endUnit;
  }
  return maxPeriod;
}

Future<void> _confirmDeleteOccurrence(
  BuildContext context,
  DataProvider dataProvider,
  ScheduleItem item,
  int week,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除本周课程'),
      content: Text('确定删除第 $week 周的《${item.name}》吗？其他周次不受影响。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await dataProvider.deleteScheduleOccurrence(item, week);
  }
}

Future<void> _openAddCourseSheet(
  BuildContext context,
  DataProvider dataProvider, {
  required int dayIndex,
  required int startUnit,
  required int endUnit,
}) async {
  final schedule = dataProvider.schedule;
  final result = await CourseEditorSheet.show(
    context,
    defaultDayIndex: dayIndex,
    defaultStartUnit: startUnit,
    defaultEndUnit: endUnit,
    defaultMaxWeek: _defaultMaxWeekFor(schedule),
    maxPeriod: _maxPeriodFor(schedule),
    existingSchedule: schedule,
  );
  if (result?.savedItem != null) {
    await dataProvider.addCustomCourse(result!.savedItem!);
  }
}

Future<void> _openEditCourseSheet(
  BuildContext context,
  DataProvider dataProvider,
  ScheduleItem item,
) async {
  final schedule = dataProvider.schedule;
  final result = await CourseEditorSheet.show(
    context,
    initial: item,
    defaultMaxWeek: _defaultMaxWeekFor(schedule),
    maxPeriod: _maxPeriodFor(schedule),
    existingSchedule: schedule,
  );
  if (result == null) return;
  if (result.deleted) {
    await dataProvider.removeCourse(item);
  } else if (result.savedItem != null) {
    await dataProvider.updateCourse(item, result.savedItem!);
  }
}

Future<void> _openMoveCourseSheet(
  BuildContext context,
  DataProvider dataProvider,
  ScheduleItem item,
  int fromWeek,
) async {
  final schedule = dataProvider.schedule;
  final target = await CourseMoveSheet.show(
    context,
    item: item,
    fromWeek: fromWeek,
    maxPeriod: _maxPeriodFor(schedule),
    allSchedule: schedule,
  );
  if (target == null) return;
  await dataProvider.moveScheduleOccurrence(
    item,
    fromWeek: fromWeek,
    toWeek: target.toWeek,
    toDay: target.toDay,
    toStartUnit: target.toStartUnit,
  );
}

Future<void> _showCourseEditActions(
  BuildContext context,
  DataProvider dataProvider, {
  required ScheduleItem item,
  required int week,
  required bool canAffectThisWeek,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '周${_kScheduleWeekDayLabels[item.dayIndex]} ${item.periodString}'
                '${item.weeksLabel.isNotEmpty ? ' · ${item.weeksLabel}' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (canAffectThisWeek)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.swap_horiz,
                      color: theme.colorScheme.primary),
                  title: Text('调课（仅第 $week 周）'),
                  subtitle: const Text('移动到其他教学周或时间段'),
                  onTap: () => Navigator.of(sheetContext).pop('move'),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined,
                    color: theme.colorScheme.primary),
                title: const Text('编辑课程（所有周）'),
                subtitle: const Text('修改课程名、老师、地点、时间或周次'),
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
              if (canAffectThisWeek)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  title: Text(
                    '删除第 $week 周课程',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text('仅删除本周这一次课'),
                  onTap: () => Navigator.of(sheetContext).pop('delete_week'),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'move':
      await _openMoveCourseSheet(context, dataProvider, item, week);
    case 'edit':
      await _openEditCourseSheet(context, dataProvider, item);
    case 'delete_week':
      await _confirmDeleteOccurrence(context, dataProvider, item, week);
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
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
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
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

class ScheduleScreen extends StatefulWidget {
  final ValueNotifier<bool> isGridViewNotifier;
  final ValueNotifier<int> selectedWeekNotifier;
  final ValueNotifier<bool> editingNotifier;

  const ScheduleScreen({
    super.key,
    required this.isGridViewNotifier,
    required this.selectedWeekNotifier,
    required this.editingNotifier,
  });

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
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final data = Provider.of<DataProvider>(context, listen: false);
      if (auth.isLoggedIn && !data.scheduleLoaded && !data.scheduleLoading) {
        data.loadSchedule();
      }
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

  void _enterEditMode() {
    if (!widget.editingNotifier.value) {
      HapticFeedback.mediumImpact();
      widget.editingNotifier.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final status = context.select<
        DataProvider,
        ({
          bool loading,
          bool isEmpty,
          bool termUnavailable,
          String? termHint,
          bool keptStale,
          String? keptStaleHint,
        })>(
      (d) => (
        loading: d.scheduleLoading,
        isEmpty: d.schedule.isEmpty,
        termUnavailable: d.isScheduleTermUnavailable,
        termHint: d.scheduleTermHint,
        keptStale: d.isScheduleKeptStaleCache,
        keptStaleHint: d.scheduleKeptStaleHint,
      ),
    );

    if (status.loading && status.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status.termUnavailable && status.termHint != null) {
      return RefreshIndicator(
        onRefresh: () => refreshScheduleWithFeedback(
          context,
          Provider.of<DataProvider>(context, listen: false),
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.event_busy_outlined,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                status.termHint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (status.keptStale && status.keptStaleHint != null)
          Material(
            color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: theme.colorScheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status.keptStaleHint!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              const _ScheduleWallpaperLayer(),
              ValueListenableBuilder<bool>(
                valueListenable: widget.editingNotifier,
                builder: (context, isEditing, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.isGridViewNotifier,
                    builder: (context, isGrid, _) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: Tween<double>(begin: 0.94, end: 1.0)
                                .animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: isGrid
                            ? _WeekScheduleGridView(
                                key: const ValueKey('grid'),
                                selectedWeekNotifier:
                                    widget.selectedWeekNotifier,
                                primarySelections: _primarySelections,
                                onPrimaryChanged: _updatePrimarySelection,
                                isEditing: isEditing,
                                onEnterEditMode: _enterEditMode,
                              )
                            : _ScheduleListTabView(
                                key: const ValueKey('list'),
                                primarySelections: _primarySelections,
                                onPrimaryChanged: _updatePrimarySelection,
                                isEditing: isEditing,
                                onEnterEditMode: _enterEditMode,
                              ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 独立壁纸背景层：精准订阅壁纸路径/不透明度/对齐，用 Image 原生 opacity + RepaintBoundary
/// 彻底消除全屏 Opacity saveLayer() 与滚动/抖动触发的背景重绘。
class _ScheduleWallpaperLayer extends StatelessWidget {
  const _ScheduleWallpaperLayer();

  @override
  Widget build(BuildContext context) {
    final wp = context.select<
        WallpaperProvider,
        ({String? path, double opacity, Alignment alignment})>(
      (w) => (
        path: w.wallpaperPath,
        opacity: w.opacity,
        alignment: w.wallpaperAlignment,
      ),
    );
    if (wp.path == null) return const SizedBox.shrink();

    final cacheWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round();

    return Positioned.fill(
      child: RepaintBoundary(
        child: Image.file(
          File(wp.path!),
          fit: BoxFit.cover,
          alignment: wp.alignment,
          opacity: AlwaysStoppedAnimation<double>(
            (1.0 - wp.opacity).clamp(0.0, 1.0),
          ),
          gaplessPlayback: true,
          cacheWidth: cacheWidth,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ScheduleListTabView extends StatelessWidget {
  const _ScheduleListTabView({
    super.key,
    required this.primarySelections,
    required this.onPrimaryChanged,
    required this.isEditing,
    required this.onEnterEditMode,
  });

  final Map<String, String> primarySelections;
  final Future<void> Function({
    required String groupKey,
    required String itemKey,
  }) onPrimaryChanged;
  final bool isEditing;
  final VoidCallback onEnterEditMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 7,
      initialIndex: DateTime.now().weekday - 1,
      child: Column(
        children: [
          Selector<DataProvider, ({String? startDay, int currentWeek})>(
            selector: (_, d) =>
                (startDay: d.scheduleStartDay, currentWeek: d.currentWeek),
            builder: (context, info, _) {
              final startDay = info.startDay != null
                  ? DateTime.tryParse(info.startDay!)
                  : null;
              final weekOffset = (info.currentWeek - 1) * 7;

              return Container(
                color: theme.cardTheme.color?.withValues(alpha: 0.9),
                child: TabBar(
                  isScrollable: false,
                  labelPadding: EdgeInsets.zero,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: theme.colorScheme.primary,
                  tabs: List.generate(7, (index) {
                    String dateStr = '';
                    if (startDay != null) {
                      final dayDate =
                          startDay.add(Duration(days: weekOffset + index));
                      dateStr = '${dayDate.month}/${dayDate.day}';
                    }
                    return Tab(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _kScheduleWeekDayTabs[index],
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
              );
            },
          ),
          Expanded(
            child: TabBarView(
              children: List.generate(7, (dayIndex) {
                return _DayScheduleView(
                  dayIndex: dayIndex,
                  primarySelections: primarySelections,
                  onPrimaryChanged: onPrimaryChanged,
                  isEditing: isEditing,
                  onEnterEditMode: onEnterEditMode,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
