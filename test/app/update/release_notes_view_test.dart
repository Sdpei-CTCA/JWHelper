import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/update/release_notes_view.dart';

void main() {
  testWidgets('ReleaseNotesView renders markdown headings and list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReleaseNotesView(
            markdown: '## 更新亮点\n\n- 修复刷新\n- **考试周**',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('更新亮点'), findsOneWidget);
    expect(find.text('修复刷新'), findsOneWidget);
    expect(find.text('考试周'), findsOneWidget);
    expect(find.textContaining('##'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
  });
}
