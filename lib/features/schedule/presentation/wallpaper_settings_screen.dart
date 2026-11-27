import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/features/notice/presentation/notice_entry_button.dart';
import 'package:JWHelper/features/notice/presentation/notice_entry_style.dart';
import 'package:JWHelper/features/schedule/presentation/widgets/wallpaper_preview_section.dart';
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
                  WallpaperPreviewSection(provider: wallpaperProvider),
                  const SizedBox(height: 24),
                  if (wallpaperProvider.wallpaperPath != null) ...[
                    _buildPanControlSection(context, wallpaperProvider),
                    const SizedBox(height: 24),
                  ],
                  _buildCardOpacitySection(context, wallpaperProvider),
                  const SizedBox(height: 24),
                  const _NoticeEntryStyleSection(),
                  const SizedBox(height: 24),
                  _buildOpacitySection(context, wallpaperProvider),
                  const SizedBox(height: 24),
                  _buildColorSection(context, wallpaperProvider),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildDefaultThemesSection(context, wallpaperProvider),
                ],
              ),
            ),
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
        _ThemedOpacitySlider(
          color: provider.primaryColor,
          value: provider.opacity,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          onChanged: (v) => provider.setOpacity(v, persist: false),
          onChangeEnd: (v) => provider.setOpacity(v, persist: true),
        ),
      ],
    );
  }

  Widget _buildCardOpacitySection(
      BuildContext context, WallpaperProvider provider) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.view_agenda, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  '列表模式',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Text(
              '${(provider.listCardOpacity * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        _ThemedOpacitySlider(
          color: primary,
          value: provider.listCardOpacity,
          min: 0.3,
          max: 1.0,
          divisions: 14,
          onChanged: (v) => provider.setListCardOpacity(v, persist: false),
          onChangeEnd: (v) => provider.setListCardOpacity(v, persist: true),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  '网格模式',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Text(
              '${(provider.gridCardOpacity * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        _ThemedOpacitySlider(
          color: primary,
          value: provider.gridCardOpacity,
          min: 0.3,
          max: 1.0,
          divisions: 14,
          onChanged: (v) => provider.setGridCardOpacity(v, persist: false),
          onChangeEnd: (v) => provider.setGridCardOpacity(v, persist: true),
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
                      onTap: provider.resetPan,
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
    final tileWidth = (MediaQuery.sizeOf(context).width - 32 - 30) / 3;

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
                  width: tileWidth,
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
              label: Text(
                '使用壁纸原色',
                style: TextStyle(color: provider.primaryColor),
              ),
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

  Widget _buildActionButtons() {
    return SizedBox(
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
    );
  }
}

class _ThemedOpacitySlider extends StatelessWidget {
  const _ThemedOpacitySlider({
    required this.color,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final Color color;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: color,
        inactiveTrackColor: color.withValues(alpha: 0.2),
        thumbColor: color,
        overlayColor: color.withValues(alpha: 0.1),
        valueIndicatorColor: color,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: '${(value * 100).toInt()}%',
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// 通知入口样式区独立组件：仅本区订阅 [NoticeEntryStyleProvider]，
/// 切换胶囊/铃铛形态时不会重绘顶部的双手机预览框。
class _NoticeEntryStyleSection extends StatelessWidget {
  const _NoticeEntryStyleSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = context.watch<NoticeEntryStyleProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '通知入口样式',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '首页标题栏的「通知公告」入口长什么样',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.arrow_back,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),
              Text(
                '教务小助手',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              NoticeEntryButton(
                unread: 3,
                mode: style.mode,
                fill: style.fill,
                onTap: () {},
                compact: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<NoticeEntryMode>(
          segments: const [
            ButtonSegment(
              value: NoticeEntryMode.capsule,
              label: Text('铃铛 + 公告'),
            ),
            ButtonSegment(
              value: NoticeEntryMode.icon,
              label: Text('仅铃铛'),
            ),
          ],
          selected: {style.mode},
          showSelectedIcon: false,
          onSelectionChanged: (values) => style.setMode(values.first),
        ),
        if (style.mode == NoticeEntryMode.capsule) ...[
          const SizedBox(height: 12),
          SegmentedButton<NoticeEntryFill>(
            segments: const [
              ButtonSegment(
                value: NoticeEntryFill.tint,
                label: Text('浅色底'),
              ),
              ButtonSegment(
                value: NoticeEntryFill.solid,
                label: Text('主题色'),
              ),
            ],
            selected: {style.fill},
            showSelectedIcon: false,
            onSelectionChanged: (values) => style.setFill(values.first),
          ),
        ],
      ],
    );
  }
}
