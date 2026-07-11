import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:JWHelper/features/evaluation/data/evaluation_service.dart';
import 'package:JWHelper/features/evaluation/domain/evaluation.dart';
import 'package:JWHelper/features/evaluation/presentation/evaluation_form_screen.dart';

class EvaluationHelperScreen extends StatefulWidget {
  const EvaluationHelperScreen({super.key});

  @override
  State<EvaluationHelperScreen> createState() => _EvaluationHelperScreenState();
}

class _EvaluationHelperScreenState extends State<EvaluationHelperScreen> {
  final EvaluationService _evaluationService = EvaluationService();
  List<EvaluationItem> _items = [];
  bool _loading = true;
  String _status = "正在获取评教列表...";
  final Map<String, String> _logs = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _status = "正在获取评教列表...";
    });
    try {
      final items = await _evaluationService.getStudentCourse();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
        if (items.isEmpty) {
          _status = "没有待评价的课程或获取失败";
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "获取列表失败: $e";
          _loading = false;
        });
      }
    }
  }

  Future<void> _openManualEvaluation(EvaluationItem item) async {
    final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EvaluationFormScreen(item: item)));

    if (result == true) {
      setState(() {
        _logs[item.evaluationId!] = "评价成功";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "教学评价",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "刷新",
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              ],
            ))
          : _items.isEmpty
              ? Center(
                  child: Text(
                    _status,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final status = _logs[item.evaluationId] ?? "未评价";
                    final isSuccess = status.contains("成功");

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      color: colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.school_outlined,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.courseName ?? "未知课程",
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${item.teacherName} • ${item.evaluationId}",
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (status != "未评价")
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: colorScheme.tertiary
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      "已评价",
                                      style: textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  )
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: FilledButton.icon(
                                onPressed: () => _openManualEvaluation(item),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: Text(isSuccess ? "重新查看" : "手动评教"),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                  },
                ),
    );
  }
}
