import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';

class ChangeUsernameForm extends ConsumerStatefulWidget {
  final String currentUsername;
  const ChangeUsernameForm({super.key, required this.currentUsername});

  @override
  ConsumerState<ChangeUsernameForm> createState() => _ChangeUsernameFormState();
}

class _ChangeUsernameFormState extends ConsumerState<ChangeUsernameForm> {
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    if (v == null || v.trim().isEmpty) return '用户名不能为空';
    if (v.trim().length > 64) return '用户名不能超过 64 个字符';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final newName = _ctrl.text.trim();
      await ProfileService().changeUsername(newName);
      ref.read(authProvider.notifier).updateUsername(newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户名修改成功')),
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        setState(() => _serverError = '用户名已被占用');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('修改失败，请稍后重试')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('修改失败，请稍后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _ctrl,
            maxLength: 64,
            decoration: InputDecoration(
              labelText: '新用户名',
              errorText: _serverError,
            ),
            validator: _validate,
            onChanged: (_) => setState(() => _serverError = null),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
