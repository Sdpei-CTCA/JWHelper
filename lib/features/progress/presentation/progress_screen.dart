import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/features/progress/domain/progress_item.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final Map<String, bool> _showAllMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<DataProvider>(context, listen: false).loadProgress();
    });
  }

  Widget _buildCourseItem(ThemeData theme, ProgressCourse course) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '学分: ${course.credit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: course.isPassed
                  ? (isDark ? const Color(0xFF1B2E1B) : const Color(0xFFF0F9EB))
                  : (isDark
                      ? const Color(0xFF2E1B1B)
                      : const Color(0xFFFEF0F0)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              course.score,
              style: TextStyle(
                fontSize: 12,
                color: course.isPassed
                    ? const Color(0xFF67C23A)
                    : const Color(0xFFF56C6C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, List<ProgressInfo> progressInfo) {
    final gpaValue = ProgressInfo.extractGpaValue(progressInfo);
    final majorExtra = ProgressInfo.valueContaining(progressInfo, '主修与方案外获得学分');
    final earned = ProgressInfo.valueContaining(progressInfo, '已获得学分');
    final required = ProgressInfo.valueContaining(progressInfo, '要求最低学分');

    return Card(
      elevation: 0,
      color: theme.colorScheme.primary,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _buildMetricColumn('学位课程绩点', gpaValue),
                const SizedBox(width: 16),
                _buildMetricColumn('主修与方案外获得学分', majorExtra),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildMetricColumn('已获得学分', earned),
                const SizedBox(width: 16),
                _buildMetricColumn('要求最低学分', required),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildGroupCard(ThemeData theme, ProgressGroup group, int index) {
    double progress = group.required > 0 ? (group.earned / group.required) : 0;
    if (progress > 1) progress = 1;
    if (group.name == '方案外课程') {
      progress = 1.0;
    }

    final courses = group.courses;
    final takenCourses = <ProgressCourse>[];
    final untakenCourses = <ProgressCourse>[];
    if (courses != null) {
      for (final course in courses) {
        if (course.score == '-') {
          untakenCourses.add(course);
        } else {
          takenCourses.add(course);
        }
      }
    }
    final showUntaken = _showAllMap[group.id] == true;

    final card = Card(
      elevation: 0,
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            group.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              if (group.name != '方案外课程' && group.required > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.brightness == Brightness.dark
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFEBEEF5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1
                          ? const Color(0xFF67C23A)
                          : const Color(0xFF409EFF),
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已修: ${group.earned}',
                    style: const TextStyle(
                      color: Color(0xFF409EFF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (group.name != '方案外课程')
                    Text(
                      group.required > 0 ? '要求: ${group.required}' : '要求: -',
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ],
          ),
          onExpansionChanged: (expanded) {
            if (expanded && group.courses == null) {
              context.read<DataProvider>().loadGroupCoursesById(group.id);
            }
          },
          children: [
            if (courses == null)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (courses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '该类别下暂无课程',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              )
            else ...[
              for (final course in takenCourses) _buildCourseItem(theme, course),
              if (untakenCourses.isNotEmpty) ...[
                if (showUntaken)
                  for (final course in untakenCourses)
                    _buildCourseItem(theme, course),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                  ),
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _showAllMap[group.id] = !showUntaken;
                      });
                    },
                    child: Text(
                      showUntaken
                          ? '收起未修课程'
                          : '查看未修课程 (${untakenCourses.length})',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );

    if (index >= 6) return card;
    return card.animate().fadeIn(delay: (45 * index).ms).slideX();
  }

  @override
  Widget build(BuildContext context) {
    final (progressLoading, _, groups, progressInfo) = context.select<
        DataProvider,
        (bool, int, List<ProgressGroup>, List<ProgressInfo>)>(
      (d) => (
        d.progressLoading,
        d.progressRevision,
        d.progressGroups,
        d.progressInfo,
      ),
    );

    final theme = Theme.of(context);

    if (progressLoading && groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasSummary = progressInfo.isNotEmpty;
    final totalCount = (hasSummary ? 1 : 0) + groups.length;

    return RefreshIndicator(
      onRefresh: () =>
          context.read<DataProvider>().loadProgress(forceRefresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (hasSummary && index == 0) {
            return _buildSummaryCard(theme, progressInfo);
          }
          final groupIndex = hasSummary ? index - 1 : index;
          return _buildGroupCard(theme, groups[groupIndex], groupIndex);
        },
      ),
    );
  }
}
