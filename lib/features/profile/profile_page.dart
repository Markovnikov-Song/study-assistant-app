import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/skill/skill_model.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';
import 'learning_os_mode_section.dart';

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
                  tooltip: '学生证',
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Learning OS 模式选择区块 ──────────────────────────────────
          // Requirement 4.1: 叠加在现有 UI 之上，不替换底部导航
          const LearningOsModeSection(),

          const SizedBox(height: 8),

          // 功能列表
          _Tile(icon: Icons.badge_outlined, title: '🎓 学生证', subtitle: '修改用户名、密码和头像', onTap: () => context.push(AppRoutes.profileEdit)),
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
                // router redirect 会自动跳转到登录页，无需手动 go
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

// ── Learning OS 模式选择区块 ──────────────────────────────────────────────────
// Requirement 4.1: 叠加在"我的"页面，支持四种模式入口。
// 不替换底部导航（ui-redesign.md 约束）。

class _LearningOsModeSection extends StatelessWidget {
  const _LearningOsModeSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Learning OS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: const [
              _ModeCard(
                mode: LearningMode.skillDriver,
                icon: Icons.bolt_outlined,
                label: 'Skill 驱动',
                description: 'AI 自动匹配学习方法',
              ),
              _ModeCard(
                mode: LearningMode.multiSubject,
                icon: Icons.school_outlined,
                label: '多课学习',
                description: '跨学科统筹计划',
              ),
              _ModeCard(
                mode: LearningMode.diy,
                icon: Icons.tune_outlined,
                label: 'DIY 模式',
                description: '自由组合 Skill 和工具',
              ),
              _ModeCard(
                mode: LearningMode.manual,
                icon: Icons.touch_app_outlined,
                label: '纯手动',
                description: '直接使用各功能模块',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final LearningMode mode;
  final IconData icon;
  final String label;
  final String description;

  const _ModeCard({
    required this.mode,
    required this.icon,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    switch (mode) {
      case LearningMode.diy:
        // DIY 模式：进入学习方法库，用户自己选 Skill
        context.push(AppRoutes.skillMarketplace);
      case LearningMode.skillDriver:
        // Skill 驱动：进入对话式创建/选择页面
        // 暂时跳转到方法库，后续接入意图输入
        context.push(AppRoutes.skillMarketplace);
      case LearningMode.multiSubject:
        // Multi-Agent：进入对话式创建学习计划
        context.push(AppRoutes.skillDialogCreate);
      case LearningMode.manual:
        // 纯手动：直接关闭提示，用户自己用底部导航
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('纯手动模式：直接使用底部导航栏的各功能'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }
}
