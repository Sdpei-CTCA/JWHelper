import 'package:flutter/foundation.dart';

/// 一条通知公告。
///
/// 学校发布平台（`pubinfo.sdpei.edu.cn`）的列表接口直接给出主键 `ms_id`、
/// 标题、发布部门与发布时间，因此不再需要解析 HTML 去猜。
@immutable
class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.title,
    required this.url,
    this.publishedAt,
    this.department = '',
    this.hasAttachment = false,
    this.isPinned = false,
    this.isRead = false,
  });

  /// 平台主键（`ms_id`）。
  final String id;

  final String title;

  /// 网页版详情地址，用于「查看原文」与解析失败时的兜底。
  final String url;

  final DateTime? publishedAt;

  /// 发布部门名（接口字段 `dwbzmc`）。
  final String department;

  /// 是否带附件（接口字段 `sffj`），列表里给个小回形针提示。
  final bool hasAttachment;

  /// 是否置顶（接口字段 `tjlevel` 大于 0 即视为推荐/置顶）。
  final bool isPinned;

  final bool isRead;

  NoticeItem copyWith({bool? isRead}) {
    return NoticeItem(
      id: id,
      title: title,
      url: url,
      publishedAt: publishedAt,
      department: department,
      hasAttachment: hasAttachment,
      isPinned: isPinned,
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
      'hasAttachment': hasAttachment,
      'isPinned': isPinned,
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
      publishedAt:
          millis is int ? DateTime.fromMillisecondsSinceEpoch(millis) : null,
      department: json['department']?.toString() ?? '',
      hasAttachment: json['hasAttachment'] == true,
      isPinned: json['isPinned'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NoticeItem && other.id == id && other.isRead == isRead;

  @override
  int get hashCode => Object.hash(id, isRead);
}
