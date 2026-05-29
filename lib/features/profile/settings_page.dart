import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/styles/export.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';
import 'profile_page.dart' show AppIconSheet, BackgroundStyleSheet;

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final styleMeta = ref.watch(uiStyleMetaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // 账号
          _buildMenuTile(
            context,
            icon: Icons.school_outlined,
            iconColor: cs.primary,
            title: '学生证',
            subtitle: '修改用户名、密码和头像',
            onTap: () => context.push(R.profileEdit),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          // 外观
          _buildMenuTile(
            context,
            icon: Icons.palette_outlined,
            iconColor: cs.primary,
            title: '外观风格',
            subtitle: styleMeta.name,
            onTap: () => _showBackgroundStylePicker(context, ref),
            isDark: isDark,
          ),
          _buildMenuTile(
            context,
            icon: Icons.apps_rounded,
            iconColor: cs.tertiary,
            title: '应用图标',
            subtitle: '切换 App 桌面图标',
            onTap: () => _showAppIconPicker(context, ref),
            isDark: isDark,
          ),
          // 通知
          _buildMenuTile(
            context,
            icon: Icons.notifications_outlined,
            iconColor: cs.secondary,
            title: '通知设置',
            subtitle: '学习提醒、复习提醒、计划提醒',
            onTap: () => context.push(R.profileNotifications),
            isDark: isDark,
          ),
          // AI
          _buildMenuTile(
            context,
            icon: Icons.api_outlined,
            iconColor: cs.primary,
            title: 'AI 模型配置',
            subtitle: '配置自己的 API Key 或使用共享配置',
            onTap: () => context.push(R.profileApiConfig),
            isDark: isDark,
          ),
          // 系统
          _buildMenuTile(
            context,
            icon: Icons.file_copy_outlined,
            iconColor: cs.onSurfaceVariant,
            title: '系统日志',
            subtitle: '本机错误与接口失败记录（最近 100 条）',
            onTap: () => context.push(R.profileLogs),
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          // 退出登录
          Container(
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.error.withValues(alpha: 0.2)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('退出登录'),
                      content: const Text('确定要退出吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                          ),
                          child: const Text('退出'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(authProvider.notifier).logout();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          color: cs.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '退出登录',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBackgroundStylePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackgroundStyleSheet(ref: ref),
    );
  }

  void _showAppIconPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AppIconSheet(ref: ref),
    );
  }
}
