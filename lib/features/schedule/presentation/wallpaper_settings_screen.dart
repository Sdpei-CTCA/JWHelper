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
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
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
          height: 260,
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
                    padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.view_agenda, size: 14, color: accent),
                            const SizedBox(width: 4),
                            Text('列表模式',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                            const Spacer(),
                            Text('${(provider.listCardOpacity * 100).toInt()}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Simulated list card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: listCardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Accent bar
                                Container(
                                  width: 3,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('高等数学',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: textColor)),
                                      const SizedBox(height: 3),
                                      Text('张老师 #A301 @1-16周',
                                          style: TextStyle(
                                              fontSize: 10, color: subTextColor)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('1-2节',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: accent)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Second row - smaller
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? const Color(0xFF252525)
                                    : Colors.grey[50]!)
                                .withValues(alpha: provider.listCardOpacity),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.all(Radius.circular(2)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('大学英语',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey)),
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
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.grey.withValues(alpha: 0.2),
                ),

                // ── Right: Grid mode ─────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.grid_view, size: 14, color: accent),
                            const SizedBox(width: 4),
                            Text('网格模式',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                            const Spacer(),
                            Text('${(provider.gridCardOpacity * 100).toInt()}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Simulated grid
                        Expanded(
                          child: Row(
                            children: [
                              // Time column
                              Column(
                                children: [
                                  _gridCell('1', Colors.transparent, null, 0, isDark),
                                  _gridCell('2', Colors.transparent, null, 0, isDark),
                                ],
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              // Use a default wallpaper
              _showDefaultWallpaperDialog();
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('使用默认壁纸'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDefaultWallpaperDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('默认壁纸'),
        content: const Text('默认壁纸功能即将推出，敬请期待！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }
}
