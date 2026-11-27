import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/coordinators/evaluation_flow_coordinator.dart';
import 'package:JWHelper/app/coordinators/home_navigation_coordinator.dart';
import 'package:JWHelper/app/coordinators/logout_coordinator.dart';
import 'package:JWHelper/app/presentation/home_settings_sheet.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/app/update/update_service.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_screen.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_web_actions.dart';
import 'package:JWHelper/features/auth/presentation/auth_provider.dart';
import 'package:JWHelper/features/auth/presentation/login_screen.dart';
import 'package:JWHelper/features/evaluation/presentation/evaluation_helper_screen.dart';
import 'package:JWHelper/features/exam/presentation/exam_screen.dart';
import 'package:JWHelper/features/grades/presentation/grades_screen.dart';
import 'package:JWHelper/features/notice/presentation/notice_entry_button.dart';
import 'package:JWHelper/features/notice/presentation/notice_entry_style.dart';
import 'package:JWHelper/features/notice/presentation/notice_list_screen.dart';
import 'package:JWHelper/features/notice/presentation/notice_provider.dart';
import 'package:JWHelper/features/progress/presentation/progress_screen.dart';
import 'package:JWHelper/features/schedule/presentation/schedule_screen.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';
import 'package:JWHelper/infrastructure/platform/widget_permission_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  /// 底部 5 个 Tab 均采用首次访问后懒挂载保活，切走时用 Offstage + TickerMode
  /// 保留滚动位置、筛选条件与考勤 WebView，并暂停离屏动画 Ticker。
  final List<bool> _tabActivated = [true, false, false, false, false];

  final ValueNotifier<bool> _isGridSchedule = ValueNotifier(false);
  final ValueNotifier<int> _selectedWeek = ValueNotifier(1);
  final ValueNotifier<bool> _scheduleEditing = ValueNotifier(false);
  final UpdateService _updateService = UpdateService();
  bool _isEvaluationDialogShowing = false;
  StreamSubscription? _sub;
  DataProvider? _dataProvider;

  // Auto-login state
  bool _isAutoLoggingIn = false;
  String? _loginError;
  bool _defaultTabApplied = false;
  bool _openedFromExternalEntry = false;

  /// 通知冷启动：等自动登录完成后再打开通知中心，避免被登录页覆盖。
  bool _pendingNoticeOpen = false;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScheduleViewMode();
    _pages = [
      ScheduleScreen(
        isGridViewNotifier: _isGridSchedule,
        selectedWeekNotifier: _selectedWeek,
        editingNotifier: _scheduleEditing,
      ),
      const AttendanceScreen(),
      const ExamScreen(),
      const GradesScreen(),
      const ProgressScreen(),
    ];
    _updateService.init();

    _isGridSchedule.addListener(_onGridScheduleChanged);
    _scheduleEditing.addListener(_onScheduleEditingChanged);

    _dataProvider = context.read<DataProvider>();
    _dataProvider!.addListener(_onDataChanged);

    // Load cache before first frame (strictly disk-only, no network / ApiClient)
    _loadCacheOnly();

    _sub = HomeWidget.widgetClicked.listen(_handleWidgetClick);
  }

  Future<void> _onGridScheduleChanged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_grid_schedule', _isGridSchedule.value);
  }

  /// 纯磁盘缓存预热：只读 SharedPreferences，绝不触发网络请求。
  void _loadCacheOnly() {
    SharedPreferences.getInstance().then((prefs) {
      final username = prefs.getString('username') ?? '';
      if (username.isNotEmpty && mounted) {
        final data = context.read<DataProvider>();
        data.setUsernameDirectly(username);
        data.loadScheduleFromCache();
        data.loadGradesFromCache();
        data.loadProgressFromCache();
      }
      _initApp();
    });
  }

  Future<void> _initApp() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final data = context.read<DataProvider>();

    // Fast: just load saved prefs (no ApiClient init yet)
    await auth.loadSavedPreferences();
    if (!mounted) return;

    _onDataChanged();
    _checkWidgetLaunch();
    _initNotificationNavigation();

    // Try auto-login only when this session is not already authenticated.
    final prefs = await SharedPreferences.getInstance();
    final hasSavedUser = prefs.getBool('auto_login') ?? false;
    final savedUsername = prefs.getString('username') ?? '';

    if (!auth.isLoggedIn) {
      if (hasSavedUser && savedUsername.isNotEmpty) {
        setState(() => _isAutoLoggingIn = true);
        final error = await auth.performAutoLogin();
        if (mounted) {
          setState(() {
            _isAutoLoggingIn = false;
            _loginError = error;
          });
          if (error == null && auth.isLoggedIn) {
            if (auth.isOfflineMode) {
              data.prepareOfflineLoginData();
            } else {
              await data.prepareOnlineLoginData();
            }
            if (mounted) _onDataChanged();
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }
    }

    // LoginScreen may have already refreshed data; avoid duplicate network calls.
    if (auth.isLoggedIn && !data.scheduleLoaded && !data.scheduleLoading) {
      if (auth.isOfflineMode) {
        data.prepareOfflineLoginData();
      } else {
        data.loadSchedule();
      }
    }

    if (mounted) await _checkCampusSetting();

    // 通知检查不阻塞首屏：静默拉一次，并处理「点通知冷启动」的待办跳转。
    unawaited(_checkNoticesInBackground());
    _maybeOpenPendingNotice();
  }

  void _promptWidgetPermissionsIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        WidgetPermissionService.promptIfNeeded(context);
      }
    });
  }

  Future<void> _initScheduleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.containsKey('is_grid_schedule')) {
      _isGridSchedule.value = prefs.getBool('is_grid_schedule') ?? false;
    }
  }

  Future<void> _checkCampusSetting() async {
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
                title: const Text('选择校区'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '请选择您的所在校区，以便应用能够为您提供准确的上课时间表。您稍后可以在“关于我们”中更改。',
                    ),
                    const SizedBox(height: 16),
                    RadioGroup<String>(
                      groupValue: selectedCampus,
                      onChanged: (value) =>
                          setState(() => selectedCampus = value!),
                      child: const Column(
                        children: [
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
                      final data =
                          Provider.of<DataProvider>(context, listen: false);
                      await data.setCampus(selectedCampus);
                      await prefs.setBool('campus_prompt_shown', true);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    _promptWidgetPermissionsIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _isGridSchedule.removeListener(_onGridScheduleChanged);
    _isGridSchedule.dispose();
    _selectedWeek.dispose();
    _scheduleEditing.removeListener(_onScheduleEditingChanged);
    _scheduleEditing.dispose();
    _dataProvider?.removeListener(_onDataChanged);
    _updateService.dispose();
    if (NotificationService.onNotificationSelected == _openTabForToken) {
      NotificationService.onNotificationSelected = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkNoticesInBackground());
    }
  }

  Future<void> _checkNoticesInBackground() async {
    if (!mounted) return;
    try {
      await context.read<NoticeProvider>().checkForNewInBackground();
    } catch (e) {
      debugPrint('Notice background check failed: $e');
    }
  }

  void _openNoticeCenter() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    NoticeListScreen.open(context);
  }

  void _maybeOpenPendingNotice() {
    if (!_pendingNoticeOpen || !mounted) return;
    if (!context.read<AuthProvider>().isLoggedIn) return;
    _pendingNoticeOpen = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openNoticeCenter();
    });
  }

  Widget _buildNoticeAction(BuildContext context) {
    final unread = context.select<NoticeProvider, int>((p) => p.unreadCount);
    final style = context.watch<NoticeEntryStyleProvider>();
    return NoticeEntryButton(
      unread: unread,
      mode: style.mode,
      fill: style.fill,
      onTap: _openNoticeCenter,
      compact: true,
    );
  }

  Future<void> _checkWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null) {
        _openedFromExternalEntry = true;
      }
      _handleWidgetClick(uri);
    } catch (e) {
      debugPrint('Error checking widget launch: $e');
    }
  }

  void _handleWidgetClick(Uri? uri) {
    if (!mounted || uri == null) return;
    _openTabForToken(uri.host);
  }

  Future<void> _initNotificationNavigation() async {
    final service = NotificationService();
    NotificationService.onNotificationSelected = _openTabForToken;

    try {
      await service.init();
      final payload = await service.consumeLaunchPayload();
      if (payload != null && mounted) {
        _openTabForToken(payload);
      }
    } catch (e) {
      debugPrint('Error checking notification launch: $e');
    }
  }

  void _openTabForToken(String? token) {
    if (!mounted) return;

    if (token == NotificationService.noticePayload) {
      _pendingNoticeOpen = true;
      _maybeOpenPendingNotice();
      return;
    }

    final nextIndex = HomeNavigationCoordinator.tabIndexFromToken(token);
    if (nextIndex == null) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    setState(() {
      _currentIndex = nextIndex;
      _tabActivated[nextIndex] = true;
      if (nextIndex != 0 && _scheduleEditing.value) {
        _scheduleEditing.value = false;
      }
      _openedFromExternalEntry = true;
      _defaultTabApplied = true;
    });
  }

  void _applyDefaultTabIfNeeded() {
    if (_defaultTabApplied || _openedFromExternalEntry || !mounted) return;

    final data = context.read<DataProvider>();
    if (!data.scheduleLoaded) return;

    final nextIndex = HomeNavigationCoordinator.resolveDefaultTab(
      schedule: data.schedule,
      currentWeek: data.currentWeek,
    );
    if (_currentIndex != nextIndex) {
      setState(() {
        _currentIndex = nextIndex;
        _tabActivated[nextIndex] = true;
        _defaultTabApplied = true;
      });
    } else {
      _defaultTabApplied = true;
    }
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
    _applyDefaultTabIfNeeded();
  }

  Future<void> _showEvaluationDialog() async {
    _isEvaluationDialogShowing = true;
    final data = context.read<DataProvider>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return Dialog(
          backgroundColor: colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_late_outlined,
                    color: colorScheme.onTertiaryContainer,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '需要进行教学评价',
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '系统检测到您未完成教学评价，导致数据无法加载。\n请优先完成评价。',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            EvaluationFlowCoordinator.openWebEvaluation(
                                context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.outline),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('网页评价'),
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
                                      const EvaluationHelperScreen(),
                                ),
                              );
                            },
                            resetEvaluationState: data.resetEvaluationState,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('手动评教'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    _isEvaluationDialogShowing = false;
  }

  Widget _buildAboutIcon() => _updateService.buildAboutIcon();

  void _onScheduleEditingChanged() {
    if (mounted) setState(() {});
  }

  List<Widget> _buildAttendanceActions(BuildContext context) {
    final actions = context.watch<AttendanceWebActions>();
    if (!actions.isReady) {
      return const [];
    }

    final username = context.select<AttendanceProvider, String>(
      (provider) => provider.savedUsername,
    );

    return [
      IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        tooltip: '重新加载考勤页面',
        visualDensity: VisualDensity.compact,
        onPressed: actions.reload,
      ),
      IconButton(
        icon: const Icon(Icons.lock_reset, size: 20),
        tooltip: '重新登录智慧考勤',
        visualDensity: VisualDensity.compact,
        onPressed: actions.relogin,
      ),
      IconButton(
        icon: const Icon(Icons.manage_accounts_outlined, size: 20),
        tooltip: username.isEmpty ? '配置智慧考勤账号' : '智慧考勤账号: $username',
        visualDensity: VisualDensity.compact,
        onPressed: actions.editAccount,
      ),
      IconButton(
        icon: const Icon(Icons.open_in_browser, size: 20),
        tooltip: '用浏览器打开',
        visualDensity: VisualDensity.compact,
        onPressed: actions.openInBrowser,
      ),
    ];
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.8,
              maxWidth: screenSize.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '版本更新',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _updateService.buildUpdateSection(context),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('关闭'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performLogout() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final data = context.read<DataProvider>();
    final navigator = Navigator.of(context);
    await LogoutCoordinator.execute(
      logoutAuth: auth.logout,
      clearData: data.clearAll,
    );
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showSettingsDialog() {
    HomeSettingsSheet.show(
      context,
      currentVersion: _updateService.currentVersion,
      onRestoreSchedule: () {
        if (!mounted) return;
        confirmAndRestoreSchedule(context, context.read<DataProvider>());
      },
      onCheckUpdate: _showUpdateDialog,
      onLogout: _performLogout,
    );
  }

  Widget _buildWeekSubtitle(
    BuildContext context,
    bool isLocalMode,
    String text,
  ) {
    const style = TextStyle(
      color: Colors.grey,
      fontSize: 12,
      fontWeight: FontWeight.normal,
    );
    if (!isLocalMode) {
      return Text(text, style: style);
    }
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('当前为自定义课表，不与教务同步'),
            action: SnackBarAction(
              label: '恢复',
              onPressed: () => confirmAndRestoreSchedule(
                context,
                context.read<DataProvider>(),
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: style),
          const SizedBox(width: 3),
          Icon(
            Icons.edit_calendar,
            size: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarSubtitle() {
    return Selector<
        DataProvider,
        ({
          bool termUnavailable,
          String? termSubtitle,
          bool keptStale,
          String? keptStaleSubtitle,
          int daysUntilStart,
          int currentWeek,
          bool isLocalMode,
        })>(
      selector: (_, d) => (
        termUnavailable: d.isScheduleTermUnavailable,
        termSubtitle: d.scheduleTermSubtitle,
        keptStale: d.isScheduleKeptStaleCache,
        keptStaleSubtitle: d.scheduleKeptStaleSubtitle,
        daysUntilStart: d.daysUntilStart,
        currentWeek: d.currentWeek,
        isLocalMode: d.isScheduleLocalMode,
      ),
      builder: (context, s, _) {
        if (s.termUnavailable) {
          return Text(
            s.termSubtitle ?? '假期或未发课表',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          );
        }
        if (s.keptStale) {
          return Text(
            s.keptStaleSubtitle ?? '已保留本地课表',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          );
        }
        if (s.daysUntilStart > 0) {
          return _buildWeekSubtitle(
            context,
            s.isLocalMode,
            '距新学期还有${s.daysUntilStart}天',
          );
        }
        if (s.currentWeek > 0) {
          return _buildWeekSubtitle(
            context,
            s.isLocalMode,
            '第${s.currentWeek}周',
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _tabActivated[_currentIndex] = true;

    final editingThisTab = _currentIndex == 0 && _scheduleEditing.value;
    final showLoginErrorPill = !_isAutoLoggingIn &&
        _loginError != null &&
        !context.select<AuthProvider, bool>((a) => a.isLoggedIn);

    return PopScope(
      canPop: !editingThisTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _scheduleEditing.value) {
          _scheduleEditing.value = false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 8,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editingThisTab ? '编辑课表' : '教务小助手',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              _buildAppBarSubtitle(),
            ],
          ),
          elevation: 0,
          actions: [
            if (editingThisTab) ...[
              ValueListenableBuilder<bool>(
                valueListenable: _isGridSchedule,
                builder: (context, isGrid, _) {
                  if (!isGrid) return const SizedBox.shrink();
                  return _ScheduleWeekStepper(
                    selectedWeekNotifier: _selectedWeek,
                  );
                },
              ),
              TextButton(
                onPressed: () => _scheduleEditing.value = false,
                child: const Text(
                  '完成',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              if (_currentIndex == 0)
                Selector<DataProvider, bool>(
                  selector: (_, d) => d.isScheduleTermUnavailable,
                  builder: (context, termUnavailable, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isGridSchedule,
                      builder: (context, isGrid, _) {
                        if (isGrid) {
                          if (termUnavailable) {
                            return IconButton(
                              icon: const Icon(Icons.view_agenda, size: 20),
                              tooltip: '切换视图',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: () => _isGridSchedule.value = false,
                            );
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ScheduleWeekStepper(
                                selectedWeekNotifier: _selectedWeek,
                              ),
                              IconButton(
                                icon: const Icon(Icons.view_agenda, size: 18),
                                tooltip: '切换视图',
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                    minWidth: 26, minHeight: 32),
                                onPressed: () => _isGridSchedule.value = false,
                              ),
                            ],
                          );
                        }
                        return IconButton(
                          icon: const Icon(Icons.view_headline),
                          tooltip: '切换视图',
                          onPressed: () => _isGridSchedule.value = true,
                        );
                      },
                    );
                  },
                ),
              if (_currentIndex == HomeNavigationCoordinator.attendanceTab)
                ..._buildAttendanceActions(context),
              if (_currentIndex != HomeNavigationCoordinator.attendanceTab)
                _buildNoticeAction(context),
              IconButton(
                icon: _buildAboutIcon(),
                tooltip: '设置',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _showSettingsDialog,
              ),
            ],
          ],
        ),
        body: Stack(
          children: [
            for (int i = 0; i < _pages.length; i++)
              if (_tabActivated[i])
                TickerMode(
                  enabled: _currentIndex == i,
                  child: Offstage(
                    offstage: _currentIndex != i,
                    child: _pages[i],
                  ),
                ),
            if (_isAutoLoggingIn)
              _FloatingStatusPill(
                bottom: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                shadowAlpha: 0.1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '正在自动登录...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )
            else if (showLoginErrorPill)
              _FloatingStatusPill(
                bottom: 24,
                backgroundColor: Colors.orange.withValues(alpha: 0.12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      '登录失败 · 点击重试',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ValueListenableBuilder<UpdateUiState>(
              valueListenable: _updateService.updateState,
              builder: (context, state, _) {
                if (!state.hasUpdate) return const SizedBox.shrink();
                final tertiary = Theme.of(context).colorScheme.tertiary;
                return _FloatingStatusPill(
                  bottom: (_isAutoLoggingIn || showLoginErrorPill) ? 64 : 24,
                  backgroundColor: tertiary.withValues(alpha: 0.15),
                  onTap: _showUpdateDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.system_update, size: 14, color: tertiary),
                      const SizedBox(width: 6),
                      Text(
                        '发现新版本 v${state.latestVersion ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, size: 14, color: tertiary),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index != 0 && _scheduleEditing.value) {
              _scheduleEditing.value = false;
            }
            setState(() {
              _currentIndex = index;
              _tabActivated[index] = true;
            });
          },
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: '课表',
            ),
            NavigationDestination(
              icon: Icon(Icons.how_to_reg_outlined),
              selectedIcon: Icon(Icons.how_to_reg),
              label: '考勤',
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
      ),
    );
  }
}

class _ScheduleWeekStepper extends StatelessWidget {
  const _ScheduleWeekStepper({required this.selectedWeekNotifier});

  final ValueNotifier<int> selectedWeekNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedWeekNotifier,
      builder: (context, week, _) {
        final primary = Theme.of(context).colorScheme.primary;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
              onPressed:
                  week > 1 ? () => selectedWeekNotifier.value = week - 1 : null,
            ),
            Text(
              '第$week周',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
              onPressed: week < 25
                  ? () => selectedWeekNotifier.value = week + 1
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _FloatingStatusPill extends StatelessWidget {
  const _FloatingStatusPill({
    required this.bottom,
    required this.backgroundColor,
    required this.child,
    this.onTap,
    this.shadowAlpha = 0.08,
  });

  final double bottom;
  final Color backgroundColor;
  final Widget child;
  final VoidCallback? onTap;
  final double shadowAlpha;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowAlpha),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    return Positioned(
      bottom: bottom,
      left: 0,
      right: 0,
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
          child: onTap == null
              ? pill
              : GestureDetector(onTap: onTap, child: pill),
        ),
      ),
    );
  }
}
