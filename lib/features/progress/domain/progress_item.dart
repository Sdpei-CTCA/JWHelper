class ProgressGroup {
  final String id;
  final String name;
  double required;
  final double earned;
  List<ProgressCourse>? courses;

  ProgressGroup({
    required this.id,
    required this.name,
    required this.required,
    required this.earned,
    this.courses,
  });

  factory ProgressGroup.fromJson(Map<String, dynamic> json) {
    return ProgressGroup(
      id: json['id'],
      name: json['name'],
      required: (json['required'] as num).toDouble(),
      earned: (json['earned'] as num).toDouble(),
      courses: json['courses'] != null
          ? (json['courses'] as List)
              .map((i) => ProgressCourse.fromJson(i))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'required': required,
      'earned': earned,
      'courses': courses?.map((e) => e.toJson()).toList(),
    };
  }
}

class ProgressInfo {
  static final RegExp _gpaNumberRe = RegExp(r'\d+(\.\d+)?');

  final String label;
  final String value;

  ProgressInfo({required this.label, required this.value});

  static String valueContaining(
    List<ProgressInfo> items,
    String keyword, {
    String fallback = '-',
  }) {
    for (final item in items) {
      if (item.label.contains(keyword)) return item.value;
    }
    return fallback;
  }

  static String extractGpaValue(List<ProgressInfo> items) {
    final raw = valueContaining(items, '学位课程绩点');
    final match = _gpaNumberRe.firstMatch(raw);
    if (match != null) return match.group(0)!;
    return raw.length > 4 ? raw.substring(0, 4) : raw;
  }

  factory ProgressInfo.fromJson(Map<String, dynamic> json) {
    return ProgressInfo(
      label: json['label'],
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
    };
  }
}

class ProgressCourse {
  final String name;
  final String credit;
  final String score;
  final bool isPassed;

  ProgressCourse({
    required this.name,
    required this.credit,
    required this.score,
    required this.isPassed,
  });

  factory ProgressCourse.fromJson(Map<String, dynamic> json) {
    return ProgressCourse(
      name: json['name'],
      credit: json['credit'],
      score: json['score'],
      isPassed: json['isPassed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'credit': credit,
      'score': score,
      'isPassed': isPassed,
    };
  }
}
