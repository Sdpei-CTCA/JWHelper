import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';

class WallpaperSettingsScreen extends StatefulWidget {
  const WallpaperSettingsScreen({super.key});

  @override
  State<WallpaperSettingsScreen> createState() =>
      _WallpaperSettingsScreenState();
}

class _WallpaperSettingsScreenState extends State<WallpaperSettingsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null && mounted) {
        setState(() => _isLoading = true);

        final wallpaperProvider = context.read<WallpaperProvider>();
        await wallpaperProvider.setWallpaper(image.path);

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('壁纸设置成功！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择图片失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearWallpaper() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除壁纸吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<WallpaperProvider>().clearWallpaper();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('壁纸已清除'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallpaperProvider = context.watch<WallpaperProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('课表外观自定义'),
        actions: [
          if (wallpaperProvider.wallpaperPath != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearWallpaper,
              tooltip: '清除壁纸',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview at the top
                  _buildPreviewSection(context, wallpaperProvider),
                  const SizedBox(height: 24),

                  // Pan control (only when wallpaper is set)
                  if (wallpaperProvider.wallpaperPath != null) ...[
                    _buildPanControlSection(context, wallpaperProvider),
                    const SizedBox(height: 24),
                  ],

                  // Card Transparency
                  _buildCardOpacitySection(context, wallpaperProvider),
                  const SizedBox(height: 24),

                  // Wallpaper Opacity Slider
                  _buildOpacitySection(context, wallpaperProvider),
                  const SizedBox(height: 24),

                  // Color Preview
                  _buildColorSection(context, wallpaperProvider),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(context),
                  const SizedBox(height: 24),

                  // Default themes at the bottom
                  _buildDefaultThemesSection(context, wallpaperProvider),
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewSection(
      BuildContext context, WallpaperProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    // Each phone frame width: (screen - padding 32 - gap 12) / 2, capped
    final frameWidth = ((screenWidth - 32 - 12) / 2).clamp(140.0, 200.0);
    // Phone aspect ratio ~19.5:9
    final frameHeight = frameWidth * (19.5 / 9);

    final bgImage = provider.wallpaperPath != null
        ? DecorationImage(
            image: FileImage(File(provider.wallpaperPath!)),
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

    Widget phoneShell(
        {required String label,
        required IconData icon,
        required Widget child}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label above the frame
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent)),
            ],
          ),
          const SizedBox(height: 8),
          // Phone frame
          Container(
            width: frameWidth,
            height: frameHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.1),
                  width: 1.5),
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
                // Wallpaper layer
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      image: bgImage,
                      color: bgImage == null
                          ? (theme.cardTheme.color ?? theme.cardColor)
                          : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(color: overlayColor),
                    ),
                  ),
                ),
                // Content
                Positioned.fill(child: child),
                // Status bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                    decoration: BoxDecoration(
                      color: appBarBg.withValues(alpha: 0.85),
                    ),
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
        ],
      );
    }

    // ── List layout phone content ──
    Widget listContent() {
      final mockCourses = [
        _MockCourse('高等数学', '张老师', 'A301', '1-2节', accent),
        _MockCourse('大学英语', '李老师', 'B205', '3-4节', accent),
        _MockCourse('数据结构', '王老师', 'C102', '5-6节', accent),
        _MockCourse('', '', '', '', Colors.grey), // empty placeholder
        _MockCourse('体育', '', '操场', '9-10节', accent),
      ];

      return Column(
        children: [
          // App bar space
          const SizedBox(height: 26),
          // Tab bar mock (周一~周日)
          Container(
            height: 24,
            color: tabBg.withValues(alpha: 0.9),
            child: Row(
              children: List.generate(7, (i) {
                final days = ['一', '二', '三', '四', '五', '六', '日'];
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
          // Course list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
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
                                    Text(c.name,
                                        style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: textColor)),
                                    if (c.teacher.isNotEmpty ||
                                        c.location.isNotEmpty)
                                      Text(
                                        [c.teacher, c.location]
                                            .where((s) => s.isNotEmpty)
                                            .join(' · '),
                                        style: TextStyle(
                                            fontSize: 6, color: subTextColor),
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
                                child: Text(c.time,
                                    style: TextStyle(
                                        fontSize: 6,
                                        fontWeight: FontWeight.bold,
                                        color: accent)),
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

    // ── Grid layout phone content ──
    Widget gridContent() {
      const days = ['一', '二', '三', '四', '五', '六', '日'];
      // Preset: 4 rows (sections) x 7 days
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
          // App bar space
          const SizedBox(height: 26),
          // Week header
          Container(
            height: 22,
            color: tabBg.withValues(alpha: 0.9),
            child: Row(
              children: [
                // Time column header
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
          // Grid
          Expanded(
            child: Row(
              children: [
                // Time column
                SizedBox(
                  width: 16,
                  child: Column(
                    children: List.generate(4, (row) {
                      return Expanded(
                        child: Container(
                          alignment: Alignment.center,
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
                // Day columns
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
                              border: course != null
                                  ? Border.all(
                                      color: accent.withValues(alpha: 0.25))
                                  : Border.all(
                                      color:
                                          Colors.grey.withValues(alpha: 0.06)),
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
                                                color: subTextColor),
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
        // Two phone frames side by side
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

  Widget _buildOpacitySection(
      BuildContext context, WallpaperProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '壁纸不透明度',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(provider.opacity * 100).toInt()}%',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: provider.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '调整壁纸的不透明程度，数值越大壁纸越淡',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: provider.primaryColor,
            inactiveTrackColor: provider.primaryColor.withValues(alpha: 0.2),
            thumbColor: provider.primaryColor,
            overlayColor: provider.primaryColor.withValues(alpha: 0.1),
            valueIndicatorColor: provider.primaryColor,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: Slider(
            value: provider.opacity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: '${(provider.opacity * 100).toInt()}%',
            onChanged: (value) {
              provider.setOpacity(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCardOpacitySection(
      BuildContext context, WallpaperProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '课程卡片透明度',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '调整课表中课程卡片的背景透明度，数值越小越透明',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),

        // List mode card opacity
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.view_agenda,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('列表模式',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
            Text(
              '${(provider.listCardOpacity * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor:
                theme.colorScheme.primary.withValues(alpha: 0.2),
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            valueIndicatorColor: theme.colorScheme.primary,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: Slider(
            value: provider.listCardOpacity,
            min: 0.3,
            max: 1.0,
            divisions: 14,
            label: '${(provider.listCardOpacity * 100).toInt()}%',
            onChanged: (value) {
              provider.setListCardOpacity(value);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Grid mode card opacity
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('网格模式',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
            Text(
              '${(provider.gridCardOpacity * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor:
                theme.colorScheme.primary.withValues(alpha: 0.2),
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            valueIndicatorColor: theme.colorScheme.primary,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: Slider(
            value: provider.gridCardOpacity,
            min: 0.3,
            max: 1.0,
            divisions: 14,
            label: '${(provider.gridCardOpacity * 100).toInt()}%',
            onChanged: (value) {
              provider.setGridCardOpacity(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorSection(BuildContext context, WallpaperProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '提取的颜色',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '从壁纸中自动提取的主题颜色',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildColorChip('主色', provider.primaryColor),
            const SizedBox(width: 12),
            _buildColorChip('辅色', provider.secondaryColor),
            const SizedBox(width: 12),
            _buildColorChip('点缀', provider.accentColor),
          ],
        ),
      ],
    );
  }

  Widget _buildPanControlSection(
      BuildContext context, WallpaperProvider provider) {
    final theme = Theme.of(context);
    final primary = provider.primaryColor;

    Widget arrowBtn(IconData icon, VoidCallback onPressed) {
      return Material(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: primary, size: 20),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '壁纸位置',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '调整壁纸图片的显示位置',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              arrowBtn(Icons.keyboard_arrow_up,
                  () => provider.setPanY(provider.panY - 0.2)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  arrowBtn(Icons.keyboard_arrow_left,
                      () => provider.setPanX(provider.panX - 0.2)),
                  const SizedBox(width: 4),
                  Material(
                    color: primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        provider.setPanX(0);
                        provider.setPanY(0);
                      },
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.center_focus_strong,
                            color: primary.withValues(alpha: 0.6), size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  arrowBtn(Icons.keyboard_arrow_right,
                      () => provider.setPanX(provider.panX + 0.2)),
                ],
              ),
              const SizedBox(height: 4),
              arrowBtn(Icons.keyboard_arrow_down,
                  () => provider.setPanY(provider.panY + 0.2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultThemesSection(
      BuildContext context, WallpaperProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '默认主题',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '选择一套预设配色，无需壁纸即可使用',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: WallpaperProvider.defaultThemes.entries.map((entry) {
            final key = entry.key;
            final t = entry.value;
            final color = t['color'] as Color;
            final name = t['name'] as String;
            final icon = t['icon'] as IconData;

            return Material(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  await provider.applyDefaultTheme(key);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已应用「$name」主题'),
                        backgroundColor: color,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 32 - 30) / 3,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Restore wallpaper colors button
        if (provider.hasExtractedColors) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await provider.restoreWallpaperColors();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已恢复壁纸原色'),
                      backgroundColor: provider.primaryColor,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              icon: Icon(Icons.restore, color: provider.primaryColor),
              label: Text('使用壁纸原色',
                  style: TextStyle(color: provider.primaryColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: provider.primaryColor.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColorChip(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            label: const Text('从相册选择壁纸'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MockCourse {
  final String name;
  final String teacher;
  final String location;
  final String time;
  final Color color;

  _MockCourse(this.name, this.teacher, this.location, this.time, this.color);
}
