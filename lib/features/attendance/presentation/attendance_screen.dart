import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_account_form.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/attendance/presentation/campus_webview_screen.dart';

/// 智慧考勤（底部导航「考勤」tab 主体）。
///
/// 主体是考勤网页版；首次使用（或清除账号后）先展示智慧山体账号绑定引导，
/// 保存并校验通过后直接进入网页版。
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  AttendanceProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AttendanceProvider>();
    if (!identical(provider, _provider)) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider..addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  /// 在设置里配置/清除账号后同步本页（表单视图 ↔ 网页版视图）。
  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    // 本地凭据还没读完时不能判断「未配置」，否则冷启动会先闪出绑定表单。
    if (!provider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!provider.isConfigured) {
      return _buildAccountSetupView();
    }

    return const CampusWebViewScreen();
  }

  /// 首次使用（或清除账号后）的引导视图。
  Widget _buildAccountSetupView() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
          ),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.how_to_reg, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '首次使用请配置智慧考勤账号',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '考勤签到需要「智慧山体」学号与密码。保存后会立即校验，'
                  '通过后即可直接进入考勤页面。账号可随时在'
                  '「设置 → 智慧考勤账号」中修改。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AttendanceAccountForm(
              initialUsername: context.read<AttendanceProvider>().savedUsername,
              onSaved: (_) {
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
      ],
    );
  }
}
