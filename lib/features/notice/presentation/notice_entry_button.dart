import 'package:flutter/material.dart';
import 'package:JWHelper/features/notice/presentation/notice_entry_style.dart';

/// 首页标题栏的通知入口。
///
/// 两种形态：只有铃铛，或「铃铛 + 公告」的胶囊。抽成独立组件是为了让
/// 「课表外观自定义」里能直接复用同一个控件做预览，避免两处样式走偏。
class NoticeEntryButton extends StatelessWidget {
  const NoticeEntryButton({
    super.key,
    required this.unread,
    required this.mode,
    required this.fill,
    required this.onTap,
    this.compact = false,
  });

  final int unread;
  final NoticeEntryMode mode;
  final NoticeEntryFill fill;
  final VoidCallback? onTap;

  /// 预览用的小号尺寸。
  final bool compact;

  String get _tooltip => unread > 0 ? '通知公告（$unread 条未读）' : '通知公告';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final solid = mode == NoticeEntryMode.capsule && fill == NoticeEntryFill.solid;

    Widget bell({required Color color, required double size}) {
      return Badge(
        isLabelVisible: unread > 0,
        backgroundColor: solid ? Colors.white : null,
        textColor: solid ? scheme.primary : null,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(Icons.notifications_none, size: size, color: color),
      );
    }

    if (mode == NoticeEntryMode.icon) {
      return IconButton(
        tooltip: _tooltip,
        onPressed: onTap,
        icon: bell(color: scheme.primary, size: compact ? 20 : 24),
      );
    }

    final foreground = solid ? scheme.onPrimary : scheme.primary;

    return Tooltip(
      message: _tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: compact
                ? const EdgeInsets.fromLTRB(8, 3, 9, 3)
                : const EdgeInsets.fromLTRB(9, 5, 11, 5),
            decoration: BoxDecoration(
              color: solid
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.primary.withValues(alpha: solid ? 0 : 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                bell(color: foreground, size: compact ? 15 : 17),
                SizedBox(width: compact ? 4 : 5),
                Text(
                  '公告',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
