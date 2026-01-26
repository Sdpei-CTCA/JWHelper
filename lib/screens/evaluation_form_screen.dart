import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/evaluation.dart';
import '../api/evaluation_service.dart';

class EvaluationFormScreen extends StatefulWidget {
  final EvaluationItem item;

  const EvaluationFormScreen({super.key, required this.item});

  @override
  State<EvaluationFormScreen> createState() => _EvaluationFormScreenState();
}

class _EvaluationFormScreenState extends State<EvaluationFormScreen> {
  final EvaluationService _evaluationService = EvaluationService();
  bool _loading = true;
  bool _submitting = false;
  String _error = "";
  List<EvaluationQuestion> _questions = [];
  final Map<String, String> _answers = {}; // qId -> value

  final List<String> _goodComments = [
    "专业知识和教学技能出众，授课生动有趣。",
    "老师授课认真，课堂气氛活跃，重点突出。",
    "教学严谨，对学生负责，能够从学生实际出发。",
    "备课充分，讲解精辟，善于调动学生积极性。",
    "讲课风趣幽默，深入浅出，让学生容易理解。",
    "治学严谨，要求严格，能深入了解学生的学习和生活状况。",
  ];

  final List<String> _adviceComments = [
    "没有什么需要改进的地方，老师非常优秀。",
    "希望课堂互动更多一些，活跃课堂气氛。",
    "希望能多结合实际案例进行讲解。",
    "建议语速适中，给学生留出更多思考时间。",
    "希望增加一些课外知识的拓展。",
    "暂无建议，对课程非常满意。",
  ];

  void _randomizeComment(String qId, bool isGood) {
    final list = isGood ? _goodComments : _adviceComments;
    final random = Random();
    final text = list[random.nextInt(list.length)];
    setState(() {
      _answers[qId] = text;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _evaluationService.getQuestions(widget.item.evaluationId!);
      setState(() {
        _questions = questions;
        _loading = false;
        // Pre-fill answers (Optional, better UX not to force clicks if logic is standard)
        // Or leave empty. User wants "manual".
        // Let's pre-fill "A" for easier manual editing.
        for (var q in questions) {
           if (q.type == 0) {
             if (q.options.isNotEmpty) {
                _answers[q.id] = q.options.first.code;
             } else {
                _answers[q.id] = "A";
             }
           } else {
              if (q.title.contains("优点")) {
                _answers[q.id] = "专业知识和教学技能出众，授课生动有趣。";
              } else {
                _answers[q.id] = "没有什么需要改进的地方，老师非常优秀。";
              }
           }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "加载问卷失败: $e";
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    
    try {
      StringBuffer answerBuffer = StringBuffer();
      for (var q in _questions) {
        String val = _answers[q.id] ?? "";
        // Format: ID + 11 commas + Val + 10 pipes
        answerBuffer.write("${q.id},,,,,,,,,,,$val||||||||||");
      }
      
      await _evaluationService.submitEvaluation(widget.item.evaluationId!, answerBuffer.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("评价提交成功")));
        Navigator.of(context).pop(true); // Return true for success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("提交失败: $e")));
        setState(() => _submitting = false);
      }
    }
  }

  final Map<String, String> _optionLabels = {
    "A": "好",
    "B": "较好",
    "C": "一般",
    "D": "较差",
    "E": "差",
  };

  Widget _buildQuestion(EvaluationQuestion q, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (q.type == 0) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final options = q.options.isNotEmpty 
                      ? q.options.map((o) => o.code).toList() 
                      : ["A", "B", "C", "D", "E"];
                      
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: options.map((opt) {
                       final isSelected = _answers[q.id] == opt;
                       String label = "";
                       if (q.options.isNotEmpty) {
                          label = q.options.firstWhere((o) => o.code == opt, orElse: () => EvaluationOption(code: "", content: "")).content;
                       } else {
                          label = _optionLabels[opt] ?? "";
                       }

                       return Expanded(
                         child: GestureDetector(
                           onTap: () {
                             setState(() {
                               _answers[q.id] = opt;
                             });
                           },
                           child: AnimatedContainer(
                             duration: const Duration(milliseconds: 200),
                             margin: const EdgeInsets.symmetric(horizontal: 2),
                             padding: const EdgeInsets.symmetric(vertical: 8),
                             decoration: BoxDecoration(
                               color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).scaffoldBackgroundColor,
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(
                                 color: isSelected ? Colors.transparent : Colors.grey.withValues(alpha: 0.2),
                               ),
                             ),
                             child: Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Text(
                                   opt,
                                   style: TextStyle(
                                     color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                     fontWeight: FontWeight.bold,
                                     fontSize: 14,
                                   ),
                                 ),
                                 const SizedBox(height: 2),
                                 Text(
                                   label,
                                   style: TextStyle(
                                     color: isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.grey,
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
              ),
            ] else ...[
               Container(
                 decoration: BoxDecoration(
                   color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                 ),
                 child: Stack(
                   children: [
                     TextField(
                       controller: TextEditingController(text: _answers[q.id])
                         ..selection = TextSelection.fromPosition(
                            TextPosition(offset: _answers[q.id]?.length ?? 0),
                         ),
                       maxLines: 3,
                       onChanged: (val) {
                          _answers[q.id] = val;
                       },
                       style: const TextStyle(fontSize: 14, height: 1.4),
                       decoration: InputDecoration(
                         border: InputBorder.none,
                         focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)
                         ),
                         enabledBorder: InputBorder.none,
                         hintText: "请输入评价内容...",
                         contentPadding: const EdgeInsets.fromLTRB(16, 16, 48, 16),
                       ),
                     ),
                     Positioned(
                       right: 8,
                       bottom: 8,
                       child: Material(
                         color: Colors.transparent,
                         child: IconButton(
                           icon: Icon(Icons.casino_rounded, color: Theme.of(context).primaryColor),
                           tooltip: "随机生成评语",
                           visualDensity: VisualDensity.compact,
                           onPressed: () {
                              final isGood = q.title.contains("优点");
                              _randomizeComment(q.id, isGood);
                           },
                         ),
                       ),
                     ),
                   ],
                 ),
               )
            ]
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (50 * index).ms).slideY(begin: 0.1, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("课程评价", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.item.courseName ?? "未知课程", style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: _loading 
        ? Center(child: _error.isNotEmpty 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(_error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadQuestions, 
                    label: const Text("重试"),
                    icon: const Icon(Icons.refresh),
                  )
                ],
              )
            : const CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: _questions.length + 1,
            itemBuilder: (context, index) {
              if (index == _questions.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      "到底啦~ 记得提交哦",
                      style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
                    ),
                  ),
                );
              }
              return _buildQuestion(_questions[index], index);
            },
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _loading ? null : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              elevation: 4,
              shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _submitting 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
              : const Icon(Icons.check_circle_outline),
            label: Text(
               _submitting ? "正在提交..." : "提交评价",
               style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 1.0, end: 0),
        ),
      ),
    );
  }
}
