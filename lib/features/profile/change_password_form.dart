import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_exception.dart';
import '../../services/profile_service.dart';

class ChangePasswordForm extends ConsumerStatefulWidget {
  const ChangePasswordForm({super.key});

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _oldPasswordError;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _oldPasswordError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ProfileService().changePassword(_oldCtrl.text, _newCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码修改成功')),
        );
        _oldCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        setState(() => _oldPasswordError = '当前密码错误');
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
            controller: _oldCtrl,
            obscureText: !_showOld,
            decoration: InputDecoration(
              labelText: '当前密码',
              errorText: _oldPasswordError,
              suffixIcon: IconButton(
                icon: Icon(_showOld ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showOld = !_showOld),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? '请输入当前密码' : null,
            onChanged: (_) => setState(() => _oldPasswordError = null),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newCtrl,
            obscureText: !_showNew,
            decoration: InputDecoration(
              labelText: '新密码',
              suffixIcon: IconButton(
                icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showNew = !_showNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '请输入新密码';
              if (v.length < 6) return '新密码至少 6 个字符';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: !_showConfirm,
            decoration: InputDecoration(
              labelText: '确认新密码',
              suffixIcon: IconButton(
                icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '请确认新密码';
              if (v != _newCtrl.text) return '两次输入的密码不一致';
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('修改密码'),
          ),
        ],
      ),
    );
  }
}
