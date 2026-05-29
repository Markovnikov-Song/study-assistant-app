import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (ok && mounted) context.go(R.chat);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 900;

    return Scaffold(
      body: _AuthSurface(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 40 : 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 1040 : 460),
                child: isDesktop
                    ? Row(
                        children: [
                          const Expanded(child: _BrandPanel()),
                          const SizedBox(width: 28),
                          SizedBox(
                            width: 424,
                            child: _LoginForm(
                              formKey: _formKey,
                              usernameCtrl: _usernameCtrl,
                              passwordCtrl: _passwordCtrl,
                              isLoading: state.isLoading,
                              error: state.error,
                              onSubmit: _submit,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          const _BrandPanel(compact: true),
                          const SizedBox(height: 18),
                          _LoginForm(
                            formKey: _formKey,
                            usernameCtrl: _usernameCtrl,
                            passwordCtrl: _passwordCtrl,
                            isLoading: state.isLoading,
                            error: state.error,
                            onSubmit: _submit,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthSurface extends StatelessWidget {
  final Widget child;

  const _AuthSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        gradient: LinearGradient(
          colors: [
            bg,
            cs.primary.withValues(alpha: 0.055),
            cs.secondary.withValues(alpha: 0.045),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool compact;

  const _BrandPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 240 : 360),
      padding: EdgeInsets.all(compact ? 22 : 32),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surface.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                    Colors.transparent,
                    cs.secondary.withValues(alpha: isDark ? 0.18 : 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: cs.onPrimary,
                  size: 28,
                ),
              ),
              SizedBox(height: compact ? 44 : 116),
              Text(
                '伴学',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: compact ? 34 : 46,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '把问题、资料、复盘和计划放进一个清晰的学习工作台。',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: compact ? 14 : 17,
                  height: 1.55,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _FeaturePill(icon: Icons.chat_rounded, label: '答疑'),
                    _FeaturePill(icon: Icons.menu_book_rounded, label: '资料'),
                    _FeaturePill(icon: Icons.event_note_rounded, label: '计划'),
                    _FeaturePill(icon: Icons.insights_rounded, label: '复盘'),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;

  const _LoginForm({
    required this.formKey,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.isLoading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('欢迎回来', style: textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text('继续你的学习现场', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            TextFormField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                labelText: '用户名',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入用户名' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordCtrl,
              decoration: const InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
              obscureText: true,
              validator: (v) => v == null || v.length < 6 ? '密码至少 6 位' : null,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: isLoading ? null : onSubmit,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登录'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push(R.register),
              child: const Text('没有账号？立即注册'),
            ),
          ],
        ),
      ),
    );
  }
}
