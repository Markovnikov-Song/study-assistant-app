import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .register(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (ok && mounted) {
      context.go(R.chat);
      context.push(R.profileSubjects);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          gradient: LinearGradient(
            colors: [
              bg,
              cs.primary.withValues(alpha: 0.05),
              cs.secondary.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
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
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '创建账号',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? '请输入用户名' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: '密码',
                            prefixIcon: Icon(Icons.lock_rounded),
                          ),
                          obscureText: true,
                          validator: (v) =>
                              v == null || v.length < 6 ? '密码至少 6 位' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmCtrl,
                          decoration: const InputDecoration(
                            labelText: '确认密码',
                            prefixIcon: Icon(Icons.verified_user_rounded),
                          ),
                          obscureText: true,
                          validator: (v) =>
                              v != _passwordCtrl.text ? '两次密码不一致' : null,
                        ),
                        if (state.error != null) ...[
                          const SizedBox(height: 12),
                          Text(state.error!, style: TextStyle(color: cs.error)),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: state.isLoading ? null : _submit,
                          child: state.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('注册'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
