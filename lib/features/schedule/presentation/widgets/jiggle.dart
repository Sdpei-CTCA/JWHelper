import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 编辑模式下的抖动效果（类似 iOS 主屏幕卸载 App）。
class Jiggle extends StatefulWidget {
  final bool enabled;
  final Widget child;

  /// 用于错开不同卡片的抖动相位，让整体看起来更自然。
  final int seed;

  const Jiggle({
    super.key,
    required this.enabled,
    required this.child,
    this.seed = 0,
  });

  @override
  State<Jiggle> createState() => _JiggleState();
}

class _JiggleState extends State<Jiggle> with SingleTickerProviderStateMixin {
  static const double _maxAngle = 1.6 * math.pi / 180;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 230 + (widget.seed.abs() % 5) * 12),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant Jiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  void _sync() {
    if (widget.enabled) {
      _controller.value = (widget.seed.abs() % 100) / 100;
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          final angle = (t * 2 - 1) * _maxAngle;
          return Transform.rotate(angle: angle, child: child);
        },
      ),
    );
  }
}

/// 卡片左上角的删除小叉。
class DeleteBadge extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const DeleteBadge({super.key, required this.onTap, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        // 扩大点击热区
        padding: const EdgeInsets.all(2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey.shade700.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.close, size: size * 0.66, color: Colors.white),
        ),
      ),
    );
  }
}

/// 虚线方格 + 中间加号的添加按钮。
class DashedAddCell extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final double radius;
  final double iconSize;
  final String? label;
  final bool highlighted;

  const DashedAddCell({
    super.key,
    required this.onTap,
    required this.color,
    this.radius = 6,
    this.iconSize = 18,
    this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final effective = highlighted ? Theme.of(context).colorScheme.primary : color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: effective.withValues(alpha: highlighted ? 0.9 : 0.55),
          radius: radius,
          fill: highlighted ? effective.withValues(alpha: 0.12) : null,
        ),
        child: Center(
          child: label == null
              ? Icon(Icons.add,
                  size: iconSize, color: effective.withValues(alpha: 0.75))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add,
                        size: iconSize,
                        color: effective.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(
                      label!,
                      style: TextStyle(
                        color: effective.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final Color? fill;

  _DashedRRectPainter({required this.color, required this.radius, this.fill});

  /// 按 (尺寸, 圆角) 缓存计算好的虚线路径：编辑模式下多达 84 个空格尺寸一致，
  /// 复用同一份 Path 可省去每帧上千次 computeMetrics / extractPath 开销。
  static final Map<(int, int, int), Path> _dashedPathCache = {};

  static Path _getOrBuildDashedPath(Size size, double radius) {
    final key = (
      (size.width * 2).round(),
      (size.height * 2).round(),
      (radius * 2).round(),
    );
    final cached = _dashedPathCache[key];
    if (cached != null) return cached;

    const inset = 2.0;
    final rect = Rect.fromLTWH(
        inset, inset, size.width - inset * 2, size.height - inset * 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final source = Path()..addRRect(rrect);
    final dashed = Path();
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gap;
      }
    }

    if (_dashedPathCache.length >= 24) {
      _dashedPathCache.clear();
    }
    _dashedPathCache[key] = dashed;
    return dashed;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 2.0;
    if (size.width <= inset * 2 || size.height <= inset * 2) return;
    if (fill != null) {
      final rect = Rect.fromLTWH(
          inset, inset, size.width - inset * 2, size.height - inset * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..color = fill!,
      );
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(_getOrBuildDashedPath(size, radius), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.fill != fill;
  }
}
