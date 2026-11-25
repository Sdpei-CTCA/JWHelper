import 'package:flutter/foundation.dart';

/// 一条通知公告。
///
/// [id] 直接使用归一化后的详情页地址：学校发布平台没有稳定的对外主键，
/// 但同一条通知的链接在多次抓取之间是稳定的，用它做已读标记与去重最可靠。
@immutable
class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.title,
    required this.url,
    this.publishedAt,
    this.department = '',
    this.isRead = false,
  });

  final String id;
  final String title;
  final String url;
  final DateTime? publishedAt;

  /// 发布部门；列表页没给就留空，界面上不占位。
  final String department;

  final bool isRead;

  NoticeItem copyWith({bool? isRead}) {
    return NoticeItem(
      id: id,
      title: title,
      url: url,
      publishedAt: publishedAt,
      department: department,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'publishedAt': publishedAt?.millisecondsSinceEpoch,
      'department': department,
    };
  }

  static NoticeItem? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';
    final url = json['url']?.toString() ?? '';
    if (id.isEmpty || title.isEmpty || url.isEmpty) {
      return null;
    }

    final millis = json['publishedAt'];
    return NoticeItem(
      id: id,
      title: title,
      url: url,
      publishedAt: millis is int
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : null,
      department: json['department']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NoticeItem && other.id == id && other.isRead == isRead;

  @override
  int get hashCode => Object.hash(id, isRead);
}
