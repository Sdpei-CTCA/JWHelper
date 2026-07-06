import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/progress/domain/progress_item.dart';

void main() {
  group('Progress domain models', () {
    test('ProgressGroup toJson and fromJson roundtrip', () {
      final group = ProgressGroup(
        id: 'g1',
        name: '专业必修',
        required: 20,
        earned: 15,
        courses: [
          ProgressCourse(
            name: '编译原理',
            credit: '3',
            score: '88',
            isPassed: true,
          ),
        ],
      );

      final restored = ProgressGroup.fromJson(group.toJson());
      expect(restored.id, group.id);
      expect(restored.name, group.name);
      expect(restored.required, group.required);
      expect(restored.earned, group.earned);
      expect(restored.courses, hasLength(1));
      expect(restored.courses!.first.name, '编译原理');
    });

    test('ProgressInfo toJson and fromJson roundtrip', () {
      final info = ProgressInfo(label: '平均绩点', value: '3.6');
      final restored = ProgressInfo.fromJson(info.toJson());

      expect(restored.label, info.label);
      expect(restored.value, info.value);
    });
  });
}
