import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/evaluation/data/evaluation_service.dart';
import 'package:JWHelper/features/evaluation/domain/evaluation.dart';
import 'package:JWHelper/features/evaluation/presentation/evaluation_form_screen.dart';

class _FakeEvaluationService extends EvaluationService {
  _FakeEvaluationService({required this.questionsHandler});

  final Future<List<EvaluationQuestion>> Function(String courseId)
      questionsHandler;
  String? submittedId;
  String? submittedAnswer;
  int getQuestionsCalls = 0;

  @override
  Future<List<EvaluationQuestion>> getQuestions(String courseId) {
    getQuestionsCalls++;
    return questionsHandler(courseId);
  }

  @override
  Future<void> submitEvaluation(String id, String answerString) async {
    submittedId = id;
    submittedAnswer = answerString;
  }
}

void main() {
  final sampleItem = EvaluationItem(
    courseName: '运动解剖学',
    teacherName: '张老师',
    evaluationId: 'eval-42',
  );

  final sampleQuestions = [
    EvaluationQuestion(
      id: 'q1',
      type: 0,
      title: '教师授课准备是否充分？',
    ),
    EvaluationQuestion(
      id: 'q2',
      type: 1,
      title: '请对本课程提出建议',
    ),
  ];

  testWidgets('shows reachable error state on failure and recovers on retry',
      (tester) async {
    var shouldFail = true;
    final service = _FakeEvaluationService(
      questionsHandler: (_) async {
        if (shouldFail) {
          throw Exception('network timeout');
        }
        return sampleQuestions;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationFormScreen(
          item: sampleItem,
          evaluationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('加载问卷失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('提交评价'), findsNothing);

    shouldFail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(service.getQuestionsCalls, 2);
    expect(find.text('教师授课准备是否充分？'), findsOneWidget);
    expect(find.text('提交评价'), findsOneWidget);
  });

  testWidgets(
      'preserves text controller across rebuilds, updates length hint, and submits',
      (tester) async {
    final service = _FakeEvaluationService(
      questionsHandler: (_) async => sampleQuestions,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationFormScreen(
          item: sampleItem,
          evaluationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter short text (< 10 chars) and verify live character hint appears.
    await tester.enterText(find.byType(TextField), '太短了');
    await tester.pump();
    expect(find.text('还需至少 7 字'), findsOneWidget);

    // Selecting a choice triggers setState; text input must remain intact.
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '太短了');
    expect(find.text('还需至少 7 字'), findsOneWidget);

    // Complete text answer (>= 10 chars) so hint disappears and submission works.
    const fullComment = '老师讲解非常清晰细致，课堂氛围很好';
    await tester.enterText(find.byType(TextField), fullComment);
    await tester.pump();
    expect(find.textContaining('还需至少'), findsNothing);

    await tester.tap(find.text('提交评价'));
    await tester.pumpAndSettle();

    expect(service.submittedId, 'eval-42');
    expect(
      service.submittedAnswer,
      'q1,,,,,,,,,,,A||||||||||q2,,,,,,,,,,,$fullComment||||||||||',
    );
  });
}
