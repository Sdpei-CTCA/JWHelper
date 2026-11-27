import 'dart:io';

import 'package:flutter/material.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';

/// 课表外观自定义页顶部的双布局（列表/网格）手机预览组件。
///
/// 壁纸使用 [ResizeImage] 按缩略框物理宽度降采样，避免 12MP 原图全量解码，
/// 并通过 [RepaintBoundary] 隔离预览区域重绘。
class WallpaperPreviewSection extends StatelessWidget {
  const WallpaperPreviewSection({super.key, required this.provider});

  final WallpaperProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final frameWidth = ((screenWidth - 32 - 12) / 2).clamp(140.0, 200.0);
    final frameHeight = frameWidth * (19.5 / 9);
    final decodeWidth = (frameWidth * dpr).round().clamp(180, 720);

    final bgImage = provider.wallpaperPath != null
        ? DecorationImage(
            image: ResizeImage(
              FileImage(File(provider.wallpaperPath!)),
              width: decodeWidth,
            ),
            fit: BoxFit.cover,
            alignment: provider.wallpaperAlignment,
            onError: (_, __) {},
          )
        : null;
    final overlayColor = provider.wallpaperPath != null
        ? theme.scaffoldBackgroundColor.withValues(alpha: provider.opacity)
        : theme.scaffoldBackgroundColor;
    final listCardBg = (isDark ? const Color(0xFF1E1E1E) : Colors.white)
        .withValues(alpha: provider.listCardOpacity);
    final gridCardBg = (isDark ? const Color(0xFF1E1E1E) : Colors.white)
        .withValues(alpha: provider.gridCardOpacity);
    final accent = provider.primaryColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final tabBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final appBarBg = isDark ? const Color(0xFF252525) : Colors.white;
    final dividerColor = Colors.grey.withValues(alpha: 0.15);

    Widget phoneShell({
      required String label,
      required IconData icon,
      required Widget child,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RepaintBoundary(
            child: Container(
              width: frameWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        image: bgImage,
                        color: bgImage == null
                            ? (theme.cardTheme.color ?? theme.cardColor)
                            : null,
                      ),
                      child: ColoredBox(color: overlayColor),
                    ),
                  ),
                  Positioned.fill(child: child),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                      color: appBarBg.withValues(alpha: 0.85),
                      child: Text(
                        '第1周 · 周一',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget listContent() {
      final mockCourses = [
        _MockCourse('高等数学', '张老师', 'A301', '1-2节', accent),
        _MockCourse('大学英语', '李老师', 'B205', '3-4节', accent),
        _MockCourse('数据结构', '王老师', 'C102', '5-6节', accent),
        const _MockCourse('', '', '', '', Colors.grey),
        _MockCourse('体育', '', '操场', '9-10节', accent),
      ];
      const days = ['一', '二', '三', '四', '五', '六', '日'];

      return Column(
        children: [
          const SizedBox(height: 26),
          Container(
            height: 24,
            color: tabBg.withValues(alpha: 0.9),
            child: Row(
              children: List.generate(7, (i) {
                final isSelected = i == 0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        days[i],
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? accent : subTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (isSelected)
                        Container(
                          width: 12,
                          height: 1.5,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(6),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mockCourses.length,
              itemBuilder: (context, index) {
                final c = mockCourses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: c.name.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? const Color(0xFF252525)
                                    : Colors.grey[50]!)
                                .withValues(alpha: provider.listCardOpacity),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: dividerColor),
                          ),
                          child: const Text(
                            '暂无课程',
                            style: TextStyle(fontSize: 7, color: Colors.grey),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 5),
                          decoration: BoxDecoration(
                            color: listCardBg,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 2,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: c.color,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    if (c.teacher.isNotEmpty ||
                                        c.location.isNotEmpty)
                                      Text(
                                        [c.teacher, c.location]
                                            .where((s) => s.isNotEmpty)
                                            .join(' · '),
                                        style: TextStyle(
                                          fontSize: 6,
                                          color: subTextColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.time,
                                  style: TextStyle(
                                    fontSize: 6,
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      );
    }

    Widget gridContent() {
      const days = ['一', '二', '三', '四', '五', '六', '日'];
      final gridData = <int, Map<int, _MockCourse>>{
        0: {
          0: _MockCourse('高等数学', '张老师', 'A301', '', accent),
          2: _MockCourse('大学英语', '李老师', 'B205', '', accent),
        },
        1: {
          1: _MockCourse('数据结构', '王老师', 'C102', '', accent),
          4: _MockCourse('选修课', '', 'D401', '', accent),
        },
        2: {
          0: _MockCourse('高等数学', '张老师', 'A301', '', accent),
          3: _MockCourse('体育', '', '操场', '', accent),
        },
        3: {},
      };

      return Column(
        children: [
          const SizedBox(height: 26),
          Container(
            height: 22,
            color: tabBg.withValues(alpha: 0.9),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Center(
                    child: Text('节',
                        style: TextStyle(fontSize: 6, color: subTextColor)),
                  ),
                ),
                ...List.generate(7, (i) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        days[i],
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: i == 0 ? accent : subTextColor,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Column(
                    children: List.generate(4, (row) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            '${row + 1}',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: subTextColor,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                ...List.generate(7, (dayIdx) {
                  return Expanded(
                    child: Column(
                      children: List.generate(4, (row) {
                        final course = gridData[row]?[dayIdx];
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(0.5),
                            decoration: BoxDecoration(
                              color: course != null
                                  ? gridCardBg
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: course != null
                                    ? accent.withValues(alpha: 0.25)
                                    : Colors.grey.withValues(alpha: 0.06),
                              ),
                            ),
                            child: course != null && course.name.isNotEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(1),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          course.name,
                                          style: TextStyle(
                                            fontSize: 6,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                        if (course.location.isNotEmpty)
                                          Text(
                                            course.location,
                                            style: TextStyle(
                                              fontSize: 5,
                                              color: subTextColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '效果预览',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '以下预览为预设示例课表，用于展示外观调整效果',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            phoneShell(
              label: '列表布局',
              icon: Icons.view_agenda_rounded,
              child: listContent(),
            ),
            const SizedBox(width: 12),
            phoneShell(
              label: '网格布局',
              icon: Icons.grid_view_rounded,
              child: gridContent(),
            ),
          ],
        ),
      ],
    );
  }
}

class _MockCourse {
  const _MockCourse(
    this.name,
    this.teacher,
    this.location,
    this.time,
    this.color,
  );

  final String name;
  final String teacher;
  final String location;
  final String time;
  final Color color;
}
