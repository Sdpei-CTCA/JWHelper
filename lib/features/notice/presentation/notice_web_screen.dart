import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';

/// 通知平台的应用内网页兜底。
///
/// 解析失败、正文含图片、需要下载附件时用这里打开原始页面。打开前会把统一
/// 认证票据写进 WebView 的 Cookie，尽量免登录进入；票据不被接受时页面自身的
/// 登录入口仍然可用，不会白屏。
///
/// Windows / Linux 没有可用的 WebView 实现，直接给浏览器入口（与考勤页一致）。
class NoticeWebScreen extends StatefulWidget {
  const NoticeWebScreen({super.key, required this.url, this.title = '通知原文'});

  final Uri url;
  final String title;

  /// 打开网页版；返回值仅表示页面是否成功打开。
  static Future<void> open(
    BuildContext context, {
    required Uri url,
    String title = '通知原文',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoticeWebScreen(url: url, title: title),
      ),
    );
  }

  @override
  State<NoticeWebScreen> createState() => _NoticeWebScreenState();
}

class _NoticeWebScreenState extends State<NoticeWebScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isSupported = true;

  @override
  void initState() {
    super.initState();
    _isSupported = WebViewPlatform.instance != null;

    if (!_isSupported) {
      _isLoading = false;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final controller = _controller;
    if (controller == null) return;

    await _injectCookies();
    if (!mounted) return;
    await controller.loadRequest(widget.url);
  }

  /// 把统一认证票据写进通知平台的域，尽量免登录。
  Future<void> _injectCookies() async {
    final attendance = context.read<AttendanceProvider>();
    if (!attendance.hasSavedCredentials) return;

    final cookieManager = WebViewCookieManager();
    final domain = widget.url.host;

    Future<void> set(String name, String value) async {
      if (value.isEmpty) return;
      await cookieManager.setCookie(
        WebViewCookie(name: name, value: value, domain: domain, path: '/'),
      );
    }

    await set('CTTICKET', attendance.ctTicket);
    await set('APPCTTICKET', attendance.appCtTicket);
    await set('userToken', attendance.userToken);
  }

  Future<void> _openInBrowser() async {
    if (!await launchUrl(widget.url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开浏览器')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '用浏览器打开',
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: _isSupported ? _buildWebView() : _buildUnsupportedPlatform(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildUnsupportedPlatform() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.web_asset_off,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              '当前平台不支持应用内网页',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '可以改用系统浏览器打开通知原文。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('用浏览器打开'),
            ),
          ],
        ),
      ),
    );
  }
}
