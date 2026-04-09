import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'avatar_picker.dart';
import 'change_username_form.dart';
import 'change_password_form.dart';

class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑资料')),
        body: const Center(child: Text('未登录')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 头像区域
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => showAvatarPicker(context, ref),
                  child: Stack(
                    children: [
                      user.avatarBase64 != null && user.avatarBase64!.isNotEmpty
                          ? CircleAvatar(
                              radius: 48,
                              backgroundImage: MemoryImage(
                                base64Decode(user.avatarBase64!),
                              ),
                            )
                          : CircleAvatar(
                              radius: 48,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => showAvatarPicker(context, ref),
                  child: const Text('更换头像'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),

          // 修改用户名
          ExpansionTile(
            title: const Text('修改用户名'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: ChangeUsernameForm(currentUsername: user.username),
              ),
            ],
          ),

          const Divider(),

          // 修改密码
          ExpansionTile(
            title: const Text('修改密码'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: const ChangePasswordForm(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
