import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:JWHelper/features/evaluation/data/evaluation_service.dart';
import 'package:JWHelper/features/evaluation/domain/evaluation.dart';

class EvaluationFormScreen extends StatefulWidget {
  final EvaluationItem item;
  final EvaluationService? evaluationService;

  const EvaluationFormScreen({
    super.key,
    required this.item,
    this.evaluationService,
  });

  @override
  State<EvaluationFormScreen> createState() => _EvaluationFormScreenState();
}

class _EvaluationFormScreenState extends State<EvaluationFormScreen> {
  static const int _minTextAnswerLength = 10;
  static const Map<String, String> _optionLabels = {
    'A': '好',
    'B': '较好',
    'C': '一般',
    'D': '较差',
    'E': '差',
  };

  late final EvaluationService _evaluationService;
  bool _loading = true;
  bool _submitting = false;
  String _error = '';
  List<EvaluationQuestion> _questions = [];
  final Map<String, String> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _evaluationService = widget.evaluationService ?? EvaluationService();
    _loadQuestions();
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String questionId) {
    return _textControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: _answers[questionId] ?? ''),
    );
  }

  Future<void> _loadQuestions() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final questions =
          await _evaluationService.getQuestions(widget.item.evaluationId!);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载问卷失败: $e';
        _loading = false;
      });
    }
  }

  bool _isTextQuestion(EvaluationQuestion question) => question.type != 0;

  Future<void> _submit() async {
    final hasIncompleteAnswers = _questions.any((q) {
      final value = (_answers[q.id] ?? '').trim();
      if (value.isEmpty) return true;
      if (_isTextQuestion(q) && value.length < _minTextAnswerLength) {
        return true;
      }
      return false;
    });

    if (hasIncompleteAnswers) {
      final hasShortText = _questions.any((q) {
        if (!_isTextQuestion(q)) return false;
        final value = (_answers[q.id] ?? '').trim();
        return value.isNotEmpty && value.length < _minTextAnswerLength;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasShortText
                ? '文字评价至少需要$_minTextAnswerLength个字符'
                : '请先完成所有题目后再提交',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final answerBuffer = StringBuffer();
      for (final q in _questions) {
        final val = _answers[q.id] ?? '';
        // Format: ID + 11 commas + Val + 10 pipes
        answerBuffer.write('${q.id},,,,,,,,,,,$val||||||||||');
      }

      await _evaluationService.submitEvaluation(
          widget.item.evaluationId!, answerBuffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('评价提交成功')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('提交失败: $e')));
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildQuestion(EvaluationQuestion q, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (q.type == 0)
              _buildChoiceRow(q, colorScheme)
            else
              _buildTextQuestionInput(q, colorScheme),
          ],
        ),
      ),
    );

    if (index >= 6) return card;
    return card
        .animate()
        .fadeIn(duration: 300.ms, delay: (45 * index).ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildChoiceRow(EvaluationQuestion q, ColorScheme colorScheme) {
    final options = q.options.isNotEmpty
        ? q.options
        : _optionLabels.entries
            .map((e) => EvaluationOption(code: e.key, content: e.value))
            .toList(growable: false);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: options.map((opt) {
        final isSelected = _answers[q.id] == opt.code;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _answers[q.id] = opt.code;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.28),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    opt.code,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    opt.content,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimary.withValues(alpha: 0.9)
                          : colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextQuestionInput(
    EvaluationQuestion q,
    ColorScheme colorScheme,
  ) {
    final controller = _controllerFor(q.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            onChanged: (val) => _answers[q.id] = val,
            style: const TextStyle(fontSize: 14, height: 1.4),
            decoration: InputDecoration(
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              enabledBorder: InputBorder.none,
              hintText: '请输入评价内容（至少$_minTextAnswerLength字）...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final len = value.text.trim().length;
            if (len == 0 || len >= _minTextAnswerLength) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '还需至少 ${_minTextAnswerLength - len} 字',
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadQuestions,
                label: const Text('重试'),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _questions.length + 1,
      itemBuilder: (context, index) {
        if (index == _questions.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '到底啦~ 记得提交哦',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }
        return _buildQuestion(_questions[index], index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showSubmitButton = !_loading && _error.isEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '课程评价',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            Text(
              widget.item.courseName ?? '未知课程',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: _buildBody(colorScheme),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: !showSubmitButton
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 4,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _submitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _submitting ? '正在提交...' : '提交评价',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.4, end: 0),
              ),
            ),
    );
  }
}
