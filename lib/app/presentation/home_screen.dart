import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:JWHelper/features/auth/presentation/auth_provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/shared/theme/theme_provider.dart';
import 'package:JWHelper/app/update/update_service.dart';
import 'package:JWHelper/features/evaluation/presentation/evaluation_helper_screen.dart';
import 'package:JWHelper/features/schedule/presentation/schedule_screen.dart';
import 'package:JWHelper/features/schedule/presentation/wallpaper_settings_screen.dart';
import 'package:JWHelper/features/exam/presentation/exam_screen.dart';
import 'package:JWHelper/features/grades/presentation/grades_screen.dart';
import 'package:JWHelper/features/progress/presentation/progress_screen.dart';
import 'package:JWHelper/features/auth/presentation/login_screen.dart';
import 'package:JWHelper/app/coordinators/logout_coordinator.dart';
import 'package:JWHelper/app/coordinators/home_navigation_coordinator.dart';
import 'package:JWHelper/app/coordinators/evaluation_flow_coordinator.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ValueNotifier<bool> _isGridSchedule = ValueNotifier(false);
  final ValueNotifier<int> _selectedWeek = ValueNotifier(1);
  final UpdateService _updateService = UpdateService();
  bool _isEvaluationDialogShowing = false;
  StreamSubscription? _sub;

  // Auto-login state
  bool _isAutoLoggingIn = false;
  String? _loginError;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initScheduleViewMode();
    _pages = [
      ScheduleScreen(isGridViewNotifier: _isGridSchedule, selectedWeekNotifier: _selectedWeek),
      const ExamScreen(),
      const GradesScreen(),
      const ProgressScreen(),
    ];
    _updateService.init();

    // Listen to changes to save state
    _isGridSchedule.addListener(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_grid_schedule', _isGridSchedule.value);
    });

    final data = context.read<DataProvider>();
    data.addListener(_onDataChanged);

    // Load cache synchronously before first frame (no network, no ApiClient)
    _loadCacheOnly();

    _sub = HomeWidget.widgetClicked.listen(_handleWidgetClick);
  }

  /// Synchronous-ish cache load: just read SharedPreferences, no network.
  void _loadCacheOnly() {
    SharedPreferences.getInstance().then((prefs) {
      final username = prefs.getString('username') ?? '';
      if (username.isNotEmpty && mounted) {
        final data = context.read<DataProvider>();
        data.setUsernameDirectly(username);
        data.loadScheduleFromCache();
        data.loadGrades();
        data.loadProgress();
      }
      // Now do the full async init in background
      _initApp();
    });
  }

  Future<void> _initApp() async {
    final auth = context.read<AuthProvider>();
    final data = context.read<DataProvider>();

    // Fast: just load saved prefs (no ApiClient init yet)
    await auth.loadSavedPreferences();
    if (!mounted) return;

    _onDataChanged();
    _checkWidgetLaunch();

    // Try auto-login in background (this will init ApiClient when needed)
    final prefs = await SharedPreferences.getInstance();
    final hasSavedUser = prefs.getBool('auto_login') ?? false;
    final savedUsername = prefs.getString('username') ?? '';

    if (hasSavedUser && savedUsername.isNotEmpty) {
      setState(() => _isAutoLoggingIn = true);
      final error = await auth.performAutoLogin();
      if (mounted) {
        setState(() {
          _isAutoLoggingIn = false;
          _loginError = error;
        });
        if (error == null && auth.isLoggedIn) {
          data.prepareOnlineLoginData();
        }
      }
    }

    // Full schedule load (may fetch from network if cache is stale)
    data.loadSchedule();

    if (mounted) _checkCampusSetting();
  }

  void _initScheduleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('is_grid_schedule')) {
      _isGridSchedule.value = prefs.getBool('is_grid_schedule') ?? false;
    }
  }

  void _checkCampusSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('campus_prompt_shown')) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String selectedCampus = '济南';
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("选择校区"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("请选择您的所在校区，以便应用能够为您提供准确的上课时间表。您稍后可以在“关于我们”中更改。"),
                    const SizedBox(height: 16),
                    RadioGroup<String>(
                      groupValue: selectedCampus,
                      onChanged: (value) => setState(() => selectedCampus = value!),
                      child: Column(
                        children: const [
                          RadioListTile<String>(
                            title: Text('济南校区'),
                            value: '济南',
                          ),
                          RadioListTile<String>(
                            title: Text('日照校区'),
                            value: '日照',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      final data = Provider.of<DataProvider>(context, listen: false);
                      await data.setCampus(selectedCampus);
                      await prefs.setBool('campus_prompt_shown', true);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text("确定"),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    context.read<DataProvider>().removeListener(_onDataChanged);
    _updateService.dispose();
    super.dispose();
  }

  void _checkWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _handleWidgetClick(uri);
    } catch (e) {
      debugPrint("Error checking widget launch: $e");
    }
  }

  void _handleWidgetClick(Uri? uri) {
    if (!mounted || uri == null) return;

    final nextIndex =
        HomeNavigationCoordinator.tabIndexFromWidgetHost(uri.host);
    if (nextIndex == null) return;

    setState(() {
      _currentIndex = nextIndex;
    });
  }

  void _onDataChanged() {
    if (!mounted) return;
    final data = context.read<DataProvider>();
    if (EvaluationFlowCoordinator.shouldShowDialog(
      evaluationRequired: data.evaluationRequired,
      dialogShowing: _isEvaluationDialogShowing,
    )) {
      _showEvaluationDialog();
    }
  }

  Future<void> _showEvaluationDialog() async {
    _isEvaluationDialogShowing = true;
    final data = context.read<DataProvider>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assignment_late_outlined,
                    color: Theme.of(context).colorScheme.tertiary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                "需要进行教学评价",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "系统检测到您未完成教学评价，导致数据无法加载。\n请优先完成评价。",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).disabledColor, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          EvaluationFlowCoordinator.openWebEvaluation(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("网页评价"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await EvaluationFlowCoordinator.openHelperAndReset(
                          openHelper: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const EvaluationHelperScreen()),
                            );
                          },
                          resetEvaluationState: data.resetEvaluationState,
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("手动评教"),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    _isEvaluationDialogShowing = false;
  }

  Widget _buildAboutIcon() {
    return _updateService.buildAboutIcon();
  }

  Widget _buildUpdateSection() {
    return _updateService.buildUpdateSection(context);
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              "设置与关于",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // App Info Section
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: primaryColor,
                                child: const Icon(Icons.school, size: 40, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "教务小助手",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_updateService.currentVersion.isNotEmpty)
                          Text("v${_updateService.currentVersion}", style: const TextStyle(color: Colors.grey, fontSize: 13))
                        else
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Text("v${snapshot.data!.version}", style: const TextStyle(color: Colors.grey, fontSize: 13));
                              }
                              return const Text("v...", style: TextStyle(color: Colors.grey, fontSize: 13));
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text("常规设置", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 8),
                  
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                    child: Column(
                      children: [
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            String themeText;
                            IconData icon;
                            switch (themeProvider.themeMode) {
                              case ThemeMode.system:
                                themeText = "跟随系统";
                                icon = Icons.brightness_auto;
                                break;
                              case ThemeMode.light:
                                themeText = "浅色模式";
                                icon = Icons.brightness_7;
                                break;
                              case ThemeMode.dark:
                                themeText = "深色模式";
                                icon = Icons.brightness_2;
                                break;
                            }
                            return ListTile(
                              leading: Icon(icon, color: primaryColor),
                              title: const Text("外观主题"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(themeText, style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                                ],
                              ),
                              onTap: () => themeProvider.toggleTheme(),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: Icon(Icons.wallpaper, color: primaryColor),
                          title: const Text("课表外观自定义"),
                          subtitle: const Text("自定义课表背景、配色和卡片透明度", style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const WallpaperSettingsScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        Consumer<DataProvider>(
                          builder: (context, dataProvider, child) {
                            return ListTile(
                              leading: Icon(Icons.location_city, color: primaryColor),
                              title: const Text("当前校区"),
                              subtitle: const Text("影响作息时间表计算", style: TextStyle(fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(dataProvider.campus, style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.compare_arrows, size: 16, color: Colors.grey),
                                ],
                              ),
                              onTap: () async {
                                String newCampus = dataProvider.campus == '济南' ? '日照' : '济南';
                                await dataProvider.setCampus(newCampus);
                              },
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        StatefulBuilder(
                          builder: (context, setState) {
                            return FutureBuilder<bool>(
                              future: NotificationService().isEnabled,
                              builder: (context, snapshot) {
                                final isEnabled = snapshot.data ?? true;
                                return SwitchListTile(
                                  secondary: Icon(Icons.notifications_active, color: primaryColor),
                                  title: const Text("课前提醒"),
                                  subtitle: const Text("课前10分钟发送本地通知", style: TextStyle(fontSize: 12)),
                                  value: isEnabled,
                                  activeThumbColor: Theme.of(context).colorScheme.secondary,
                                  onChanged: (newValue) async {
                                    if (newValue) {
                                      var status = await Permission.notification.status;
                                      if (!status.isGranted) {
                                        status = await Permission.notification.request();
                                        if (status.isPermanentlyDenied || !status.isGranted) {
                                          if (context.mounted) {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text("需要通知权限"),
                                                content: const Text("课前提醒功能需要通知权限。请在系统设置中允许通知。"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text("取消"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      openAppSettings();
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text("去设置"),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                      }
                                    }
                                    await NotificationService().setEnabled(newValue);
                                    if (!context.mounted) return;
                                    setState(() {});
                                    
                                    if (newValue) {
                                      final dataProvider = Provider.of<DataProvider>(context, listen: false);
                                      dataProvider.loadSchedule(forceRefresh: true);
                                    } else {
                                      NotificationService().flutterLocalNotificationsPlugin.cancelAll();
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Text("关于", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.update, color: primaryColor),
                          title: const Text("检查更新"),
                          trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          onTap: () {
                            // Close popup to show update
                            Navigator.pop(context);
                            showDialog(
                              context: context, 
                              builder: (_) => Dialog(
                                insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text("版本更新", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      ),
                                      Flexible(
                                        child: SingleChildScrollView(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            child: _buildUpdateSection(),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(onPressed: () => Navigator.pop(_), child: const Text("关闭")),
                                        ),
                                      )
                                    ]
                                  ),
                                )
                              )
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: Icon(Icons.code, color: primaryColor),
                          title: const Text("开源仓库"),
                          subtitle: const Text("GitHub: Sdpei-CTCA/JWHelper", style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                          onTap: () => launchUrl(Uri.parse("https://github.com/Sdpei-CTCA/JWHelper")),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: Icon(Icons.feedback, color: primaryColor),
                          title: const Text("反馈与交流"),
                          subtitle: const Text("加入QQ群反馈问题", style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          onTap: () => launchUrl(Uri.parse("https://qm.qq.com/q/YOwkJmn3gc")),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context); // Close settings first
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final data = Provider.of<DataProvider>(context, listen: false);
                        await LogoutCoordinator.execute(
                          logoutAuth: auth.logout,
                          clearData: data.clearAll,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('退出登录', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      "GPL3.0 License\nOriginal Author: Chendayday-2025\nRemake by: Sdpei-CTCA",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "教务小助手",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (dataProvider.daysUntilStart > 0)
              Text(
                "距新学期还有${dataProvider.daysUntilStart}天",
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.normal),
              )
            else if (dataProvider.currentWeek > 0)
              Text(
                "第${dataProvider.currentWeek}周",
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.normal),
              ),
          ],
        ),
        elevation: 0,
        actions: [
          if (_currentIndex == 0)
            ValueListenableBuilder<bool>(
              valueListenable: _isGridSchedule,
              builder: (context, isGrid, child) {
                if (isGrid) {
                  return ValueListenableBuilder<int>(
                    valueListenable: _selectedWeek,
                    builder: (context, week, _) {
                      final primary = Theme.of(context).colorScheme.primary;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: week > 1
                                ? () => _selectedWeek.value = week - 1
                                : null,
                          ),
                          Text(
                            '第$week周',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: week < 25
                                ? () => _selectedWeek.value = week + 1
                                : null,
                          ),
                          IconButton(
                            icon: Icon(isGrid ? Icons.view_agenda : Icons.view_headline, size: 20),
                            tooltip: "切换视图",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              _isGridSchedule.value = !isGrid;
                            },
                          ),
                        ],
                      );
                    },
                  );
                }
                return IconButton(
                  icon: Icon(isGrid ? Icons.view_agenda : Icons.view_headline),
                  tooltip: "切换视图",
                  onPressed: () {
                    _isGridSchedule.value = !isGrid;
                  },
                );
              },
            ),
          IconButton(
            icon: _buildAboutIcon(),
            tooltip: "设置",
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          _pages[_currentIndex],
          // Floating login status pill (bottom center)
          if (_isAutoLoggingIn)
            Positioned(
              bottom: 24,
              left: 0, right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) => Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 8),
                        Text('正在自动登录...', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (_loginError != null && !context.read<AuthProvider>().isLoggedIn)
            Positioned(
              bottom: 24,
              left: 0, right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) => Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text('登录失败 · 点击重试', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Floating update pill (bottom center, above login pill if both visible)
          ValueListenableBuilder<UpdateUiState>(
            valueListenable: _updateService.updateState,
            builder: (context, state, _) {
              if (!state.hasUpdate) return const SizedBox.shrink();
              return Positioned(
                bottom: _isAutoLoggingIn || (_loginError != null && !context.read<AuthProvider>().isLoggedIn) ? 64 : 24,
                left: 0, right: 0,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () => _showSettingsDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.system_update, size: 14, color: Theme.of(context).colorScheme.tertiary),
                            const SizedBox(width: 6),
                            Text('发现新版本 v${state.latestVersion ?? ''}',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right, size: 14, color: Theme.of(context).colorScheme.tertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '课表',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: '考试',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '成绩',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: '进度',
          ),
        ],
      ),
    );
  }
}
