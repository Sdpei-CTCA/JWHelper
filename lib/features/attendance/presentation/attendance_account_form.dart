import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/features/attendance/data/sso_token_service.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';

/// 智慧考勤账号表单（智慧山体统一认证学号 + 密码，必要时加图形验证码）。
///
/// tab 首次进入时内嵌展示，「设置 → 智慧考勤账号」以弹窗形式复用同一份表单，
/// 保存前后都会立即校验一次登录，避免存下错误凭据。密码连续输错后服务端会
/// 要求图形验证码，此时表单会多出一张验证码图片与输入框。
class AttendanceAccountForm extends StatefulWidget {
  const AttendanceAccountForm({
    super.key,
    this.initialUsername = '',
    this.showClearAction = false,
    this.onSaved,
  });

  final String initialUsername;
  final bool showClearAction;

  /// 保存且校验通过后回调。
  final ValueChanged<String>? onSaved;

  @override
  State<AttendanceAccountForm> createState() => _AttendanceAccountFormState();
}

class _AttendanceAccountFormState extends State<AttendanceAccountForm> {
  late final TextEditingController _usernameController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void didUpdateWidget(covariant AttendanceAccountForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 凭据是异步读出来的，加载晚到时把学号补进输入框。
    if (widget.initialUsername != oldWidget.initialUsername &&
        _usernameController.text.isEmpty) {
      _usernameController.text = widget.initialUsername;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<AttendanceProvider>();

    // 已经进入验证码阶段：凭据已保存，只需提交验证码。
    if (provider.needsCaptcha) {
      await _submitCaptcha(provider);
      return;
    }

    final username = _usernameController.text.trim();
    // 密码可能含空格，不做 trim。
    final password = _passwordController.text;

    if (username.isEmpty) {
      setState(() => _error = '请输入智慧山体学号');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '请输入智慧山体密码');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await provider.saveCredentials(
      username: username,
      password: password,
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });

    if (error == null) {
      widget.onSaved?.call(username);
    }
  }

  Future<void> _submitCaptcha(AttendanceProvider provider) async {
    final code = _captchaController.text.trim();
    if (code.length != SsoTokenService.captchaLength) {
      setState(() => _error = '请输入 ${SsoTokenService.captchaLength} 位图形验证码');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await provider.submitCaptcha(code);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });

    if (error == null) {
      _captchaController.clear();
      widget.onSaved?.call(_usernameController.text.trim());
    } else {
      // 失败时服务端已换图，清空输入让用户重填。
      _captchaController.clear();
    }
  }

  Future<void> _refreshCaptcha() async {
    final provider = context.read<AttendanceProvider>();
    await provider.refreshCaptcha();
    if (!mounted) return;
    setState(() {
      _error = null;
      _captchaController.clear();
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除智慧考勤账号'),
        content: const Text('清除后需要重新填写学号与密码才能使用考勤签到，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<AttendanceProvider>().clearCredentials();
    if (!mounted) return;
    _passwordController.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfigured = context.select<AttendanceProvider, bool>(
      (provider) => provider.isConfigured,
    );
    final needsCaptcha = context.select<AttendanceProvider, bool>(
      (provider) => provider.needsCaptcha,
    );
    final showClear = widget.showClearAction && isConfigured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          needsCaptcha
              ? '登录需要图形验证码：请输入图片上的字符。看不清可以点图片换一张。'
              : '智慧考勤使用「智慧山体」统一认证账号，与教务系统账号相互独立。'
                  '密码连续输错后，登录会要求输入图形验证码。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _usernameController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          enabled: !_submitting,
          decoration: const InputDecoration(
            labelText: '智慧山体学号',
            hintText: '请输入学号',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !_submitting,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_submitting) _submit();
          },
          decoration: InputDecoration(
            labelText: '智慧山体密码',
            hintText: '请输入密码',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        if (needsCaptcha) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _captchaController,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  enabled: !_submitting,
                  maxLength: SsoTokenService.captchaLength,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  onSubmitted: (_) {
                    if (!_submitting) _submit();
                  },
                  decoration: const InputDecoration(
                    labelText: '图形验证码',
                    hintText: '请输入图片上的字符',
                    border: OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildCaptchaImage(theme),
            ],
          ),
        ],
        if (_error != null && _error!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error, height: 1.4),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (showClear) ...[
              OutlinedButton(
                onPressed: _submitting ? null : _clear,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
                child: const Text('清除账号'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login, size: 18),
                label: Text(
                  _submitting
                      ? '校验中…'
                      : needsCaptcha
                          ? '提交验证码'
                          : '保存并登录',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 验证码图片：点击换一张。
  Widget _buildCaptchaImage(ThemeData theme) {
    final image = context.select<AttendanceProvider, Uint8List?>(
      (provider) => provider.captchaImage,
    );

    return Tooltip(
      message: '点击换一张',
      child: InkWell(
        onTap: _submitting ? null : _refreshCaptcha,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: SsoTokenService.captchaWidth.toDouble(),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(6),
            color: theme.colorScheme.surface,
          ),
          child: image == null
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Image.memory(image, fit: BoxFit.contain, gaplessPlayback: true),
        ),
      ),
    );
  }
}

/// 「设置 → 智慧考勤账号」弹窗：编辑或清除已保存的考勤账号。
class AttendanceAccountDialog {
  /// 返回 true 表示保存成功。
  static Future<bool> show(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    await provider.ensureLoaded();
    if (!context.mounted) return false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Expanded(child: Text('智慧考勤账号')),
              SizedBox(width: 8),
            ],
          ),
          content: SingleChildScrollView(
            child: AttendanceAccountForm(
              initialUsername: provider.savedUsername,
              showClearAction: true,
              onSaved: (_) => Navigator.of(dialogContext).pop(true),
            ),
          ),
        );
      },
    );

    return saved == true;
  }
}
