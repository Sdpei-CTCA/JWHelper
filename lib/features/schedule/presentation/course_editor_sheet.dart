import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:JWHelper/features/schedule/domain/schedule_editor.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

enum _WeekPattern { all, odd, even }

/// [CourseEditorSheet] 的返回结果。
class CourseEditorResult {
  final ScheduleItem? savedItem;
  final bool deleted;

  const CourseEditorResult.save(ScheduleItem item)
      : savedItem = item,
        deleted = false;

  const CourseEditorResult.delete()
      : savedItem = null,
        deleted = true;
}

/// 新增 / 编辑课程的底部表单。
class CourseEditorSheet extends StatefulWidget {
  final ScheduleItem? initial;
  final int defaultDayIndex;
  final int defaultStartUnit;
  final int defaultEndUnit;
  final int defaultMaxWeek;
  final int maxPeriod;
  final List<ScheduleItem> existingSchedule;

  const CourseEditorSheet({
    super.key,
    this.initial,
    required this.defaultDayIndex,
    required this.defaultStartUnit,
    required this.defaultEndUnit,
    required this.defaultMaxWeek,
    required this.maxPeriod,
    required this.existingSchedule,
  });

  static Future<CourseEditorResult?> show(
    BuildContext context, {
    ScheduleItem? initial,
    int defaultDayIndex = 0,
    int defaultStartUnit = 1,
    int defaultEndUnit = 2,
    int defaultMaxWeek = 16,
    int maxPeriod = 12,
    required List<ScheduleItem> existingSchedule,
  }) {
    return showModalBottomSheet<CourseEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => CourseEditorSheet(
        initial: initial,
        defaultDayIndex: defaultDayIndex,
        defaultStartUnit: defaultStartUnit,
        defaultEndUnit: defaultEndUnit,
        defaultMaxWeek: defaultMaxWeek,
        maxPeriod: maxPeriod,
        existingSchedule: existingSchedule,
      ),
    );
  }

  @override
  State<CourseEditorSheet> createState() => _CourseEditorSheetState();
}

class _CourseEditorSheetState extends State<CourseEditorSheet> {
  static const List<String> _weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _classroomController;

  late int _dayIndex;
  late int _startUnit;
  late int _endUnit;
  late int _rangeStart;
  late int _rangeEnd;
  _WeekPattern _pattern = _WeekPattern.all;
  late Set<int> _selectedWeeks;
  String? _nameError;
  String? _weeksError;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _teacherController = TextEditingController(text: initial?.teacher ?? '');
    _classroomController = TextEditingController(text: initial?.classroom ?? '');

    _dayIndex = (initial?.dayIndex ?? widget.defaultDayIndex).clamp(0, 6);
    final maxP = math.max(widget.maxPeriod, initial?.endUnit ?? 12);
    _startUnit = (initial?.startUnit ?? widget.defaultStartUnit).clamp(1, maxP);
    _endUnit = (initial?.endUnit ?? widget.defaultEndUnit).clamp(_startUnit, maxP);

    if (initial != null && initial.activeWeeks.isNotEmpty) {
      final active = initial.activeWeeks
          .where((w) => w >= 1 && w <= ScheduleItem.maxTeachingWeeks)
          .toList();
      _selectedWeeks = active.toSet();
      _rangeStart = active.isEmpty ? 1 : active.first;
      _rangeEnd = active.isEmpty ? widget.defaultMaxWeek : active.last;
      _pattern = _detectPattern(active);
    } else {
      _rangeStart = 1;
      _rangeEnd = widget.defaultMaxWeek.clamp(1, ScheduleItem.maxTeachingWeeks);
      _pattern = _WeekPattern.all;
      _selectedWeeks = _buildRangeWeeks(_rangeStart, _rangeEnd, _pattern);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _classroomController.dispose();
    super.dispose();
  }

  _WeekPattern _detectPattern(List<int> sortedWeeks) {
    if (sortedWeeks.length >= 2) {
      final allOdd = sortedWeeks.every((w) => w.isOdd);
      if (allOdd) return _WeekPattern.odd;
      final allEven = sortedWeeks.every((w) => w.isEven);
      if (allEven) return _WeekPattern.even;
    }
    return _WeekPattern.all;
  }

  Set<int> _buildRangeWeeks(int start, int end, _WeekPattern pattern) {
    final result = <int>{};
    for (int w = start; w <= end; w++) {
      if (pattern == _WeekPattern.odd && w.isEven) continue;
      if (pattern == _WeekPattern.even && w.isOdd) continue;
      result.add(w);
    }
    return result;
  }

  void _applyRangeAndPattern() {
    setState(() {
      _selectedWeeks = _buildRangeWeeks(_rangeStart, _rangeEnd, _pattern);
      _weeksError = null;
    });
  }

  ScheduleItem _buildCandidate() {
    return ScheduleItem.withWeeks(
      name: _nameController.text.trim(),
      teacher: _teacherController.text.trim(),
      classroom: _classroomController.text.trim(),
      dayIndex: _dayIndex,
      startUnit: _startUnit,
      endUnit: _endUnit,
      weeks: _selectedWeeks,
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '请输入课程名');
      return;
    }
    if (_selectedWeeks.isEmpty) {
      setState(() => _weeksError = '请至少选择一个上课周次');
      return;
    }
    Navigator.of(context).pop(CourseEditorResult.save(_buildCandidate()));
  }

  Future<void> _confirmDeleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除整门课程'),
        content: Text('确定删除所有周次的《${widget.initial!.name}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const CourseEditorResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxP = math.max(widget.maxPeriod, _endUnit);
    final candidate = _buildCandidate();
    final conflictWeeks = _selectedWeeks.isEmpty
        ? const <int>[]
        : ScheduleEditor.conflictWeeks(
            widget.existingSchedule,
            candidate,
            ignore: widget.initial,
          );
    final weeksPreview = ScheduleItem.formatWeeks(_selectedWeeks.toList());

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _isEditing ? '编辑课程' : '添加课程',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isEditing)
                  TextButton.icon(
                    onPressed: _confirmDeleteCourse,
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: theme.colorScheme.error),
                    label: Text(
                      '删除整门',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '课程名 *',
                hintText: '例如：高等数学',
                errorText: _nameError,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _teacherController,
                    decoration: const InputDecoration(
                      labelText: '任课老师',
                      hintText: '选填',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _classroomController,
                    decoration: const InputDecoration(
                      labelText: '上课地点',
                      hintText: '例如：A101',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '上课时间',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (index) {
                return ChoiceChip(
                  label: Text(_weekDays[index]),
                  selected: _dayIndex == index,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _dayIndex = index),
                );
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _startUnit,
                    decoration: const InputDecoration(
                      labelText: '开始节次',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(maxP, (i) {
                      final period = i + 1;
                      return DropdownMenuItem(
                        value: period,
                        child: Text('第 $period 节'),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _startUnit = value;
                        if (_endUnit < _startUnit) {
                          _endUnit = math.min(_startUnit + 1, maxP);
                        }
                      });
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('至'),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _endUnit,
                    decoration: const InputDecoration(
                      labelText: '结束节次',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(maxP - _startUnit + 1, (i) {
                      final period = _startUnit + i;
                      return DropdownMenuItem(
                        value: period,
                        child: Text('第 $period 节'),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _endUnit = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '上课周次',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    weeksPreview.isEmpty ? '未选择' : weeksPreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _WeekStepper(
                    label: '起始周',
                    value: _rangeStart,
                    min: 1,
                    max: ScheduleItem.maxTeachingWeeks,
                    onChanged: (v) {
                      _rangeStart = v;
                      if (_rangeEnd < _rangeStart) _rangeEnd = _rangeStart;
                      _applyRangeAndPattern();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WeekStepper(
                    label: '结束周',
                    value: _rangeEnd,
                    min: _rangeStart,
                    max: ScheduleItem.maxTeachingWeeks,
                    onChanged: (v) {
                      _rangeEnd = v;
                      _applyRangeAndPattern();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_WeekPattern>(
                segments: const [
                  ButtonSegment(value: _WeekPattern.all, label: Text('全部')),
                  ButtonSegment(value: _WeekPattern.odd, label: Text('单周')),
                  ButtonSegment(value: _WeekPattern.even, label: Text('双周')),
                ],
                selected: {_pattern},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (selection) {
                  _pattern = selection.first;
                  _applyRangeAndPattern();
                },
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.0,
              ),
              itemCount: ScheduleItem.maxTeachingWeeks,
              itemBuilder: (context, index) {
                final week = index + 1;
                final selected = _selectedWeeks.contains(week);
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedWeeks.remove(week);
                      } else {
                        _selectedWeeks.add(week);
                      }
                      _weeksError = null;
                    });
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      '$week',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_weeksError != null) ...[
              const SizedBox(height: 6),
              Text(
                _weeksError!,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
              ),
            ],
            if (conflictWeeks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer
                      .withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '提示：与第 ${ScheduleItem.formatWeeks(conflictWeeks)} 现有课程时段重叠，保存后将合并显示',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(_isEditing ? '保存修改' : '添加课程'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _WeekStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(26, 28),
      padding: EdgeInsets.zero,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  style: buttonStyle,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 28),
                  onPressed: value > min ? () => onChanged(value - 1) : null,
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '第$value周',
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  style: buttonStyle,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 28),
                  onPressed: value < max ? () => onChanged(value + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
