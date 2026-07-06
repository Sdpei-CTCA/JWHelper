import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/errors/exceptions.dart';

void main() {
  group('EvaluationRequiredException', () {
    test('uses default message', () {
      final error = EvaluationRequiredException();
      expect(error.message, '需要进行教学评价');
      expect(error.toString(), '需要进行教学评价');
    });

    test('uses custom message', () {
      final error = EvaluationRequiredException('请先完成评教');
      expect(error.message, '请先完成评教');
    });
  });
}
