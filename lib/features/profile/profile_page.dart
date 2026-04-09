import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          // 用户信息头部
          Container(
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.push(AppRoutes.profileEdit),
                  child: user?.avatarBase64 != null && user!.avatarBase64!.isNotEmpty
                      ? CircleAvatar(
                          radius: 32,
                          backgroundImage: MemoryImage(base64Decode(user.avatarBase64!)),
                        )
                      : CircleAvatar(
                          radius: 32,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            user?.username.isNotEmpty == true ? user!.username[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.username ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('ID: ${user?.id ?? ''}', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(AppRoutes.profileEdit),
                  tooltip: '编辑资料',
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 功能列表
          _Tile(icon: Icons.person_outline, title: '编辑资料', subtitle: '修改用户名、密码和头像', onTap: () => context.push(AppRoutes.profileEdit)),
          _Tile(icon: Icons.book_outlined, title: '学科管理', subtitle: '新建、编辑、归档学科', onTap: () => context.push(AppRoutes.subjects)),
          _Tile(icon: Icons.folder_outlined, title: '资料管理', subtitle: '管理各学科的资料和历年题', onTap: () => context.push(AppRoutes.resources)),
          _Tile(icon: Icons.menu_book_outlined, title: '📓 笔记本', subtitle: '管理学习笔记', onTap: () => context.push(AppRoutes.notebooks)),
          _Tile(icon: Icons.history, title: '对话历史', subtitle: '查看所有历史对话', onTap: () => context.push(AppRoutes.history)),

          const Divider(height: 32),

          _Tile(
            icon: Icons.logout,
            title: '退出登录',
            color: Colors.red,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('退出登录'),
                  content: const Text('确定要退出吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('退出')),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.title, this.subtitle, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: color == null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
