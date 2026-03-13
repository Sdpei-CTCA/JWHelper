import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:home_widget/home_widget.dart';
import 'package:JWHelper/features/auth/presentation/auth_provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/shared/theme/theme_provider.dart';
import 'package:JWHelper/app/update/update_service.dart';
import 'package:JWHelper/features/evaluation/presentation/evaluation_helper_screen.dart';
import 'package:JWHelper/features/schedule/presentation/schedule_screen.dart';
import 'package:JWHelper/features/exam/presentation/exam_screen.dart';
import 'package:JWHelper/features/grades/presentation/grades_screen.dart';
import 'package:JWHelper/features/progress/presentation/progress_screen.dart';
import 'package:JWHelper/features/auth/presentation/login_screen.dart';
import 'package:JWHelper/app/coordinators/logout_coordinator.dart';
import 'package:JWHelper/app/coordinators/home_navigation_coordinator.dart';
import 'package:JWHelper/app/coordinators/evaluation_flow_coordinator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const ScheduleScreen(),
    const ExamScreen(),
    const GradesScreen(),
    const ProgressScreen(),
  ];

  final UpdateService _updateService = UpdateService();
  bool _isEvaluationDialogShowing = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _updateService.init();
    final data = context.read<DataProvider>();
    data.addListener(_onDataChanged);
    
    // Initial check
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _onDataChanged();
       _checkWidgetLaunch();
    });

    _sub = HomeWidget.widgetClicked.listen(_handleWidgetClick);
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

    final nextIndex = HomeNavigationCoordinator.tabIndexFromWidgetHost(uri.host);
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
                  color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_late_outlined, color: Colors.orange, size: 32),
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
                style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                children: [
                    Expanded(
                    child: OutlinedButton(
                      onPressed: () => EvaluationFlowCoordinator.openWebEvaluation(context),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                MaterialPageRoute(builder: (_) => const EvaluationHelperScreen()),
                              );
                            },
                            resetEvaluationState: data.resetEvaluationState,
                          );
                        },
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("关于我们", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
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
                    color: const Color(0xFF409EFF),
                    child: const Icon(Icons.school, size: 50, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "教务小助手",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (_updateService.currentVersion.isNotEmpty)
              Text("v${_updateService.currentVersion}", style: const TextStyle(color: Colors.grey))
            else
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text("v${snapshot.data!.version}", style: const TextStyle(color: Colors.grey));
                  }
                  return const Text("v...", style: TextStyle(color: Colors.grey));
                },
              ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => launchUrl(Uri.parse("https://github.com/Sdpei-CTCA/JWHelper")),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    "GitHub 仓库",
                    style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                return InkWell(
                  onTap: () {
                    themeProvider.toggleTheme();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          "主题: $themeText",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildUpdateSection(),
            const SizedBox(height: 12),
            const Text(
              "GPL3.0 License",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              "Original Author:Chendayday-2025\nRemake by: Sdpei-CTCA",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("关闭"),
          ),
        ],
      ),
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
                "距开学还有${dataProvider.daysUntilStart}天",
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.normal),
              )
            else if (dataProvider.currentWeek > 0)
              Text(
                "第${dataProvider.currentWeek}周",
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: _buildAboutIcon(),
            tooltip: "关于我们",
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF409EFF)),
            tooltip: "退出登录",
            onPressed: () async {
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
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        elevation: 2,
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