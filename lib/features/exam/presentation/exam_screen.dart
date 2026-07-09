import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/app/coordinators/exam_selection_coordinator.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  Semester? _selectedSemester;
  ExamRound? _selectedRound;
  bool _initLoading = false;
  bool _roundsLoading = false;
  bool _refreshingFilters = false;
  DataProvider? _dataProvider;
  String? _trackedCampus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dataProvider = context.read<DataProvider>();
      _trackedCampus = _dataProvider!.campus;
      _dataProvider!.addListener(_onProviderUpdate);
      _initData();
    });
  }

  @override
  void dispose() {
    _dataProvider?.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted || _dataProvider == null) return;
    final campus = _dataProvider!.campus;
    if (campus == _trackedCampus) return;
    _trackedCampus = campus;
    _applyCampusSelection();
  }

  Future<void> _applyCampusSelection() async {
    final provider = _dataProvider;
    if (provider == null || provider.examRounds.isEmpty) return;
    setState(() {
      _autoSelectRound(provider.examRounds, provider.campus);
    });
    await _loadExams();
  }

  Future<void> _initData() async {
    setState(() => _initLoading = true);
    await _loadSemesters();
    setState(() => _initLoading = false);
  }

  Future<void> _loadSemesters() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.loadExamSemesters();

    if (mounted && provider.examSemesters.isNotEmpty) {
      if (_selectedSemester == null ||
          !provider.examSemesters.contains(_selectedSemester)) {
        setState(() {
          _selectedSemester = provider.examSemesters.first;
        });
        await _loadRounds();
      }
    }
  }

  List<ExamRound> _getSortedRounds(List<ExamRound> rounds, String campus) {
    return ExamSelectionCoordinator.sortRounds(rounds, campus);
  }

  void _autoSelectRound(List<ExamRound> rounds, String campus) {
    _selectedRound = ExamSelectionCoordinator.selectRound(rounds, campus);
  }

  Future<void> _loadRounds() async {
    if (_selectedSemester == null) return;
    setState(() {
      _roundsLoading = true;
      _selectedRound = null;
    });
    final provider = Provider.of<DataProvider>(context, listen: false);

    await provider.loadExamRounds(_selectedSemester!.id);

    if (mounted) {
      setState(() => _roundsLoading = false);
      if (provider.examRounds.isNotEmpty) {
        setState(() {
          _autoSelectRound(provider.examRounds, provider.campus);
        });
        _loadExams();
      } else {
        setState(() {
          _selectedRound = null;
        });
      }
    }
  }

  Future<void> _loadExams() async {
    if (_selectedRound == null || _selectedSemester == null) return;
    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.loadExams(_selectedSemester!.id, _selectedRound!.id);
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshingFilters = true);
    final provider = Provider.of<DataProvider>(context, listen: false);

    try {
      // 1. Refresh Semesters
      await provider.loadExamSemesters(forceRefresh: true);

      if (mounted) {
        if (provider.examSemesters.isNotEmpty) {
          if (_selectedSemester == null ||
              !provider.examSemesters.contains(_selectedSemester)) {
            _selectedSemester = provider.examSemesters.first;
          }
        } else {
          _selectedSemester = null;
        }
      }

      // 2. Refresh Rounds
      if (_selectedSemester != null) {
        await provider.loadExamRounds(_selectedSemester!.id,
            forceRefresh: true);

        if (mounted) {
          if (provider.examRounds.isNotEmpty) {
            if (_selectedRound == null ||
                !provider.examRounds.contains(_selectedRound)) {
              _autoSelectRound(provider.examRounds, provider.campus);
            }
          } else {
            _selectedRound = null;
          }
        }
      } else {
        _selectedRound = null;
      }

      // 3. Refresh Exams
      if (_selectedSemester != null && _selectedRound != null) {
        await provider.loadExams(_selectedSemester!.id, _selectedRound!.id,
            forceRefresh: true);
      }
    } catch (e) {
      debugPrint("Refresh failed: $e");
    } finally {
      if (mounted) {
        setState(() => _refreshingFilters = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.cardTheme.color,
          child: Column(
            children: [
                // Semester Dropdown
                Selector<DataProvider, List<Semester>>(
                    selector: (_, p) => p.examSemesters,
                    builder: (context, semesters, _) {
                      final effectiveSelectedSemester =
                          semesters.contains(_selectedSemester)
                              ? _selectedSemester
                              : null;
                      return DropdownButtonFormField<Semester>(
                        initialValue: effectiveSelectedSemester,
                        menuMaxHeight: 300,
                        hint: Text("请选择学期",
                            style: TextStyle(color: theme.hintColor)),
                        decoration: InputDecoration(
                          labelText: "学期",
                          labelStyle: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7)),
                          prefixIcon: Icon(Icons.calendar_today_outlined,
                              size: 20, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            borderSide:
                                BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        icon: Icon(Icons.arrow_drop_down_circle_outlined,
                            color: theme.colorScheme.primary),
                        dropdownColor: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        style: TextStyle(
                            color: theme.colorScheme.onSurface, fontSize: 15),
                        items: (semesters.isEmpty ||
                                _initLoading ||
                                _refreshingFilters)
                            ? null
                            : semesters.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                        onChanged: (semesters.isEmpty ||
                                _initLoading ||
                                _refreshingFilters)
                            ? null
                            : (value) {
                                if (value != null &&
                                    value != _selectedSemester) {
                                  setState(() => _selectedSemester = value);
                                  _loadRounds();
                                }
                              },
                        disabledHint: (_initLoading || _refreshingFilters)
                            ? const Text("正在加载学期...")
                            : const Text("暂无学期数据"),
                      );
                    }),

                const SizedBox(height: 12),

                // Round Dropdown
                Selector<DataProvider, (List<ExamRound>, String)>(
                    selector: (_, p) => (p.examRounds, p.campus),
                    builder: (context, data, _) {
                      final roundsRaw = data.$1;
                      final campus = data.$2;
                      final rounds = _getSortedRounds(roundsRaw, campus);
                      final effectiveSelectedRound =
                          rounds.contains(_selectedRound)
                              ? _selectedRound
                              : null;

                      return DropdownButtonFormField<ExamRound>(
                        key: ValueKey('rounds_$campus'),
                        initialValue: effectiveSelectedRound,
                        menuMaxHeight: 300,
                        hint: Text("请选择考试批次",
                            style: TextStyle(color: theme.hintColor)),
                        decoration: InputDecoration(
                          labelText: "考试批次",
                          labelStyle: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7)),
                          prefixIcon: Icon(Icons.layers_outlined,
                              size: 20, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            borderSide:
                                BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        icon: Icon(Icons.arrow_drop_down_circle_outlined,
                            color: theme.colorScheme.primary),
                        dropdownColor: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        style: TextStyle(
                            color: theme.colorScheme.onSurface, fontSize: 15),
                        items: (rounds.isEmpty ||
                                _roundsLoading ||
                                _refreshingFilters)
                            ? null
                            : rounds.map((r) {
                                return DropdownMenuItem(
                                  value: r,
                                  child: Text(r.name),
                                );
                              }).toList(),
                        onChanged: (rounds.isEmpty ||
                                _roundsLoading ||
                                _refreshingFilters)
                            ? null
                            : (value) {
                                if (value != null && value != _selectedRound) {
                                  setState(() => _selectedRound = value);
                                  _loadExams();
                                }
                              },
                        disabledHint: _selectedSemester == null
                            ? const Text("请先选择学期")
                            : ((_roundsLoading || _refreshingFilters)
                                ? const Text("正在加载批次...")
                                : const Text("暂无考试批次")),
                      );
                    }),
              ],
            ),
          ),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Consumer<DataProvider>(builder: (context, provider, _) {
                final isLoading =
                    (provider.examsLoading && !_refreshingFilters) ||
                        _initLoading;
                return _buildContent(provider, isLoading);
              }),
            ),
          ),
        ],
    );
  }

  Future<void> _handleFallbackLoad() async {
    if (_selectedSemester == null || _selectedRound == null) return;

    try {
      final provider = Provider.of<DataProvider>(context, listen: false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("正在尝试通过导出文件获取，这可能需要1-3分钟，请耐心等待..."),
          duration: Duration(seconds: 5),
        ),
      );

      await provider.loadExamsFallback(
        semId: _selectedSemester!.id,
        etId: _selectedRound!.id,
        semName: _selectedSemester!.name,
        etName: _selectedRound!.name,
      );

      if (mounted) {
        if (provider.exams.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("未找到考试信息")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("获取成功")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("获取失败: $e")),
        );
      }
    }
  }

  Widget _buildContent(DataProvider provider, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Helper to make empty states scrollable for RefreshIndicator
    Widget buildScrollableState(Widget child) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      );
    }

    if (provider.examSemesters.isEmpty) {
      return buildScrollableState(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text("无法获取学期信息", style: TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initData,
                child: const Text("重试"),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.examRounds.isEmpty && _selectedSemester != null) {
      return buildScrollableState(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text("该学期暂无考试安排", style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    if (provider.exams.isEmpty) {
      return buildScrollableState(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_turned_in_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text("未找到考试记录", style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _handleFallbackLoad,
                icon: const Icon(Icons.download_outlined),
                label: const Text("尝试另一种获取方式"),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: provider.exams.length,
      itemBuilder: (context, index) {
        final exam = provider.exams[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exam.courseName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        exam.type,
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "课程号: ${exam.courseNo}",
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                ),
                const Divider(height: 24),
                _buildInfoRow(Icons.access_time, "时间", exam.time),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on_outlined, "地点", exam.location),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.numbers, "课序号", exam.classNo),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.info_outline, "缓考状态", exam.applyStatus),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text("$label: ",
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8),
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
