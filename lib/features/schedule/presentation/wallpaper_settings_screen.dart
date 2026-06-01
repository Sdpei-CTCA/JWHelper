import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';

class WallpaperSettingsScreen extends StatefulWidget {
  const WallpaperSettingsScreen({super.key});

  @override
  State<WallpaperSettingsScreen> createState() => _WallpaperSettingsScreenState();
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

  Widget _buildPreviewSection(BuildContext context, WallpaperProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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

    Widget sampleCard({
      required Color bg,
      required bool isList,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            if (isList) ...[
              Container(
                width: 2,
                height: 24,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('高等数学',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  if (isList)
                    Text('张老师 #A301',
                        style: TextStyle(fontSize: 8, color: subTextColor)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(isList ? '1-2节' : '',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: accent)),
            ),
          ],
        ),
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
        const SizedBox(height: 12),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: bgImage,
            color: bgImage == null ? (theme.cardTheme.color ?? theme.cardColor) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: overlayColor,
            ),
            child: Row(
              children: [
                // ── Left: List mode ──────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 5, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.view_agenda, size: 12, color: accent),
                            const SizedBox(width: 3),
                            Text('列表',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                            const Spacer(),
                            Text('${(provider.listCardOpacity * 100).toInt()}%',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: sampleCard(bg: listCardBg, isList: true)),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (isDark ? const Color(0xFF252525) : Colors.grey[50]!)
                                        .withValues(alpha: provider.listCardOpacity),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 2,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Colors.grey,
                                          borderRadius: BorderRadius.all(Radius.circular(1)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('大学英语',
                                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Divider
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  color: Colors.grey.withValues(alpha: 0.2),
                ),

                // ── Right: Grid mode ─────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.grid_view, size: 12, color: accent),
                            const SizedBox(width: 3),
                            Text('网格',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                            const Spacer(),
                            Text('${(provider.gridCardOpacity * 100).toInt()}%',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Time column
                              SizedBox(
                                width: 18,
                                child: Column(
                                  children: [
                                    _gridCell('1', Colors.transparent, null, 0, isDark),
                                    _gridCell('2', Colors.transparent, null, 0, isDark),
                                  ],
                                ),
                              ),
                              // Mon
                              Expanded(
                                child: Column(
                                  children: [
                                    _gridCell('', gridCardBg, accent, provider.gridCardOpacity, isDark,
                                        courseName: '高等数学', isHighlighted: true),
                                    _gridCell('', gridCardBg, accent, provider.gridCardOpacity, isDark,
                                        courseName: '', isHighlighted: false),
                                  ],
                                ),
                              ),
                              // Tue
                              Expanded(
                                child: Column(
                                  children: [
                                    _gridCell('', Colors.transparent, null, 0, isDark),
                                    _gridCell('', Colors.transparent, null, 0, isDark),
                                  ],
                                ),
                              ),
                              // Wed
                              Expanded(
                                child: Column(
                                  children: [
                                    _gridCell('', gridCardBg, accent, provider.gridCardOpacity, isDark,
                                        courseName: '大学英语', isHighlighted: true),
                                    _gridCell('', Colors.transparent, null, 0, isDark),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _gridCell(String label, Color? bg, Color? accent, double opacity, bool isDark,
      {String? courseName, bool isHighlighted = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: (courseName != null && courseName.isNotEmpty)
              ? bg
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: label.isNotEmpty
              ? null
              : (courseName != null && courseName.isNotEmpty)
                  ? Border.all(color: accent!.withValues(alpha: 0.3))
                  : Border.all(color: Colors.grey.withValues(alpha: 0.08)),
        ),
        child: Center(
          child: label.isNotEmpty
              ? Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black54))
              : (courseName != null && courseName.isNotEmpty)
                  ? Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text(courseName,
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _buildOpacitySection(BuildContext context, WallpaperProvider provider) {
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

  Widget _buildCardOpacitySection(BuildContext context, WallpaperProvider provider) {
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
                Icon(Icons.view_agenda, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('列表模式', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
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
            inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.2),
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
                Icon(Icons.grid_view, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('网格模式', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
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
            inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.2),
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

  Widget _buildPanControlSection(BuildContext context, WallpaperProvider provider) {
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
              arrowBtn(Icons.keyboard_arrow_up, () => provider.setPanY(provider.panY - 0.2)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  arrowBtn(Icons.keyboard_arrow_left, () => provider.setPanX(provider.panX - 0.2)),
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
                        child: Icon(Icons.center_focus_strong, color: primary.withValues(alpha: 0.6), size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  arrowBtn(Icons.keyboard_arrow_right, () => provider.setPanX(provider.panX + 0.2)),
                ],
              ),
              const SizedBox(height: 4),
              arrowBtn(Icons.keyboard_arrow_down, () => provider.setPanY(provider.panY + 0.2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultThemesSection(BuildContext context, WallpaperProvider provider) {
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
                side: BorderSide(color: provider.primaryColor.withValues(alpha: 0.4)),
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
