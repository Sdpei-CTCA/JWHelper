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
       MaterialPageRoute(builder: (_) => EvaluationFormScreen(item: item))
    );
    
    if (result == true) {
      setState(() {
         _logs[item.evaluationId!] = "评价成功";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("教学评价", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
         ? Center(child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const CircularProgressIndicator(), 
               const SizedBox(height: 16),
               Text(_status, style: TextStyle(color: Theme.of(context).disabledColor))
             ],
           ))
         : _items.isEmpty 
           ? Center(child: Text(_status, style: const TextStyle(fontSize: 16)))
           : ListView.separated(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               itemCount: _items.length,
               separatorBuilder: (context, index) => const SizedBox(height: 12),
               itemBuilder: (context, index) {
                 final item = _items[index];
                 final status = _logs[item.evaluationId] ?? "未评价";
                 final isSuccess = status.contains("成功");
                 
                 return Card(
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
                           children: [
                             Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(
                                 color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               child: Icon(Icons.school_outlined, color: Theme.of(context).primaryColor),
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                      item.courseName ?? "未知课程",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                   ),
                                   const SizedBox(height: 4),
                                   Text(
                                      "${item.teacherName} • ${item.evaluationId}",
                                      style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
                                   ),
                                 ],
                               ),
                             ),
                             if (status != "未评价")
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                 decoration: BoxDecoration(
                                   color: Colors.green.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(8),
                                 ),
                                 child: const Text(
                                   "已评价",
                                   style: TextStyle(
                                     fontSize: 12,
                                     fontWeight: FontWeight.bold,
                                     color: Colors.green,
                                   ),
                                 ),
                               )
                           ],
                         ),

                         const Padding(
                           padding: EdgeInsets.symmetric(vertical: 12),
                           child: Divider(height: 1),
                         ),
                         
                         SizedBox(
                           width: double.infinity,
                           height: 36,
                           child: FilledButton.icon(
                             onPressed: () => _openManualEvaluation(item),
                             icon: const Icon(Icons.edit_note, size: 16),
                             label: Text(isSuccess ? "重新查看" : "手动评教"),
                             style: FilledButton.styleFrom(
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                               backgroundColor: Theme.of(context).primaryColor,
                             ),
                           ),
                         )
                       ],
                     ),
                   ),
                 ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
               },
             ),
    );
  }
}
