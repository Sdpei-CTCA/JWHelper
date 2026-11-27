import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:JWHelper/features/schedule/domain/schedule_editor.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

/// 调课目标位置（仅移动某一周的这一次课）。
class CourseMoveTarget {
  final int toWeek;
  final int toDay;
  final int toStartUnit;

  const CourseMoveTarget({
    required this.toWeek,
    required this.toDay,
    required this.toStartUnit,
  });
}

/// 调课面板：选择目标教学周、星期和节次（仅影响当前周）。
class CourseMoveSheet extends StatefulWidget {
  final ScheduleItem item;
  final int fromWeek;
  final int maxPeriod;
  final List<ScheduleItem> allSchedule;

  const CourseMoveSheet({
    super.key,
    required this.item,
    required this.fromWeek,
    required this.maxPeriod,
    required this.allSchedule,
  });

  static Future<CourseMoveTarget?> show(
    BuildContext context, {
    required ScheduleItem item,
    required int fromWeek,
    required int maxPeriod,
    required List<ScheduleItem> allSchedule,
  }) {
    return showModalBottomSheet<CourseMoveTarget>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => CourseMoveSheet(
        item: item,
        fromWeek: fromWeek,
        maxPeriod: maxPeriod,
        allSchedule: allSchedule,
      ),
    );
  }

  @override
  State<CourseMoveSheet> createState() => _CourseMoveSheetState();
}

class _CourseMoveSheetState extends State<CourseMoveSheet> {
  static const List<String> _weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  late int _toWeek;
  late int _toDay;
  late int _toStartUnit;

  @override
  void initState() {
    super.initState();
    _toWeek = widget.fromWeek.clamp(1, ScheduleItem.maxTeachingWeeks);
    _toDay = widget.item.dayIndex.clamp(0, 6);
    _toStartUnit = widget.item.startUnit;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final span = widget.item.unitSpan;
    final maxP = math.max(widget.maxPeriod, widget.item.endUnit);
    final maxStart = math.max(1, maxP - span + 1);
    final isSameSlot = _toWeek == widget.fromWeek &&
        _toDay == widget.item.dayIndex &&
        _toStartUnit == widget.item.startUnit;
    final canMove = !isSameSlot &&
        ScheduleEditor.canMoveOccurrence(
          widget.allSchedule,
          widget.item,
          fromWeek: widget.fromWeek,
          toWeek: _toWeek,
          toDay: _toDay,
          toStartUnit: _toStartUnit,
          maxUnit: maxP,
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '调课（仅第 ${widget.fromWeek} 周）',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.item.name} · 原时间：${_weekDays[widget.item.dayIndex]} ${widget.item.periodString}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '目标教学周',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.chevron_left),
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      _toWeek > 1 ? () => setState(() => _toWeek--) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _toWeek,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(ScheduleItem.maxTeachingWeeks, (i) {
                      final w = i + 1;
                      return DropdownMenuItem(
                        value: w,
                        child: Text(w == widget.fromWeek ? '第 $w 周（当前周）' : '第 $w 周'),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) setState(() => _toWeek = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(Icons.chevron_right),
                  visualDensity: VisualDensity.compact,
                  onPressed: _toWeek < ScheduleItem.maxTeachingWeeks
                      ? () => setState(() => _toWeek++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '目标星期',
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
                  selected: _toDay == index,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _toDay = index),
                );
              }),
            ),
            const SizedBox(height: 14),
            Text(
              '目标节次（共 $span 节）',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _toStartUnit.clamp(1, maxStart),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: List.generate(maxStart, (i) {
                final start = i + 1;
                final end = start + span - 1;
                return DropdownMenuItem(
                  value: start,
                  child: Text('第 $start-$end 节'),
                );
              }),
              onChanged: (v) {
                if (v != null) setState(() => _toStartUnit = v);
              },
            ),
            const SizedBox(height: 12),
            if (isSameSlot)
              Text(
                '请选择新的教学周或上课时间',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (!canMove)
              Text(
                '目标时段已有其他课程，请选择其他时间',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.error,
                ),
              ),
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
                    onPressed: canMove
                        ? () => Navigator.of(context).pop(
                              CourseMoveTarget(
                                toWeek: _toWeek,
                                toDay: _toDay,
                                toStartUnit: _toStartUnit,
                              ),
                            )
                        : null,
                    child: const Text('确认调课'),
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
