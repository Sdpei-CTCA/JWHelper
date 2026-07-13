import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String? _selectedSemester;

  Future<void> _refreshGrades() async {
    try {
      await context.read<DataProvider>().loadGrades(forceRefresh: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('刷新失败，请检查网络后重试')),
        );
      }
    }
  }

  Widget _buildEmptyBody({
    required String message,
    bool showRefreshButton = false,
  }) {
    final gradesLoading =
        context.select<DataProvider, bool>((d) => d.gradesLoading);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.inbox_outlined,
            size: 64, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Center(
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        if (showRefreshButton) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: gradesLoading ? null : _refreshGrades,
            child: gradesLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('刷新'),
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: Text(
            '下拉刷新',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradesLoading = context.select<DataProvider, bool>((d) => d.gradesLoading);
    final grades = context.select<DataProvider, List<dynamic>>((d) => d.grades);
    final rawSemesters = context.select<DataProvider, List<String>>((d) => d.semesterList);

    if (gradesLoading && grades.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (grades.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshGrades,
        child: _buildEmptyBody(
          message: '暂无成绩数据',
          showRefreshButton: true,
        ),
      );
    }

    final allOptions = ['全部', ...rawSemesters];

    if (_selectedSemester == null) {
      if (rawSemesters.isNotEmpty) {
        _selectedSemester = rawSemesters.first;
      } else {
        _selectedSemester = '全部';
      }
    } else if (!allOptions.contains(_selectedSemester)) {
      _selectedSemester = '全部';
    }

    final filteredGrades = _selectedSemester == '全部'
        ? grades
        : grades.where((g) => g.semester == _selectedSemester).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).cardTheme.color,
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '学期筛选: ',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      dropdownColor: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      value: _selectedSemester,
                      items: allOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedSemester = newValue;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshGrades,
            child: filteredGrades.isEmpty
                ? _buildEmptyBody(message: '该学期暂无成绩')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredGrades.length,
                    cacheExtent: 2000,
                    itemBuilder: (context, index) {
                      final grade = filteredGrades[index];
                      return Card(
                        elevation: 0,
                        color: Theme.of(context).cardTheme.color,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      grade.courseName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: double.tryParse(grade.score) !=
                                                  null &&
                                              double.parse(grade.score) < 60
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      grade.score,
                                      style: TextStyle(
                                        color: double.tryParse(grade.score) !=
                                                    null &&
                                                double.parse(grade.score) < 60
                                            ? Colors.red
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  _buildTag(
                                    Icons.calendar_today,
                                    grade.semester,
                                  ),
                                  _buildTag(
                                    Icons.class_,
                                    '${grade.credit} 学分',
                                  ),
                                  _buildTag(
                                    Icons.grade,
                                    '绩点: ${grade.gpa}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
