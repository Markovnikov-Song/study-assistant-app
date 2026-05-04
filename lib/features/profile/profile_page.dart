import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/background_style_provider.dart';
import '../../routes/app_router.dart';
import '../../services/token_service.dart';
import 'learning_os_mode_section.dart';

// App 图标配置：alias 名 → 显示名称
const _kIconConfigs = {
  'Icon1': '星河',
  'Icon2': '朱砂',
  'Icon3': '丹霞',
};

// 当前 App 图标 Provider
final currentAppIconProvider = StateProvider<String>((ref) => 'Icon1');

// Token今日使用量Provider
final tokenTodayUsageProvider = FutureProvider.autoDispose<TokenQuota>((ref) async {
  final service = TokenService();
  return service.getQuota();
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bgStyle = ref.watch(backgroundStyleProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // 让 ShellPage 的背景透过来
      body: Stack(
        children: [
          // 主内容（SVG 背景由 ShellPage 提供）
          CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 80,
                floating: true,
                pinned: false,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    '我的',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              // 用户信息卡片
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: cs.outline,
                        width: 0.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // 头像
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.profileEdit),
                            child: Stack(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [cs.primary, cs.secondary],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: cs.primary.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: user?.avatarBase64 != null &&
                                          user!.avatarBase64!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: Image.memory(
                                            base64Decode(user.avatarBase64!),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            user?.username.isNotEmpty == true
                                                ? user!.username[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                ),
                                // 编辑按钮
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: cs.outline,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.username ?? '未登录',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 1.0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'ID: ${user?.id ?? '—'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Learning OS 模式选择区块
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: const LearningOsModeSection(),
                ),
              ),
              // 功能列表
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionTitle(context, '学习管理', isDark),
                    _buildMenuTile(
                      context,
                      icon: Icons.school_outlined,
                      iconColor: cs.primary,
                      title: '学生证',
                      subtitle: '修改用户名、密码和头像',
                      onTap: () => context.push(AppRoutes.profileEdit),
                      isDark: isDark,
                    ),
                    _buildMenuTile(
                      context,
                      icon: Icons.book_outlined,
                      iconColor: cs.secondary,
                      title: '学科管理',
                      subtitle: '新建、编辑、归档学科',
                      onTap: () => context.push(AppRoutes.profileSubjects),
                      isDark: isDark,
                    ),
                    _buildMenuTile(
                      context,
                      icon: Icons.folder_outlined,
                      iconColor: cs.tertiary,
                      title: '资料管理',
                      subtitle: '管理各学科的资料和历年题',
                      onTap: () => context.push(AppRoutes.profileResources),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle(context, '工具与历史', isDark),
                    // API 配置卡片
                    _buildMenuTile(
                      context,
                      icon: Icons.api_outlined,
                      iconColor: cs.primary,
                      title: 'AI 模型配置',
                      subtitle: '配置自己的 API Key 或使用共享配置',
                      onTap: () => context.push(R.profileApiConfig),
                      isDark: isDark,
                    ),
                    // 系统日志
                    _buildMenuTile(
                      context,
                      icon: Icons.file_copy_outlined,
                      iconColor: cs.tertiary,
                      title: '系统日志',
                      subtitle: '查看应用运行日志，便于排查问题',
                      onTap: () => context.push(R.profileLogs),
                      isDark: isDark,
                    ),
                    // AI使用强度统计卡片
                    _buildTokenUsageCard(context, ref, isDark),
                    _buildMenuTile(
                      context,
                      icon: Icons.history_rounded,
                      iconColor: cs.tertiary,
                      title: '对话历史',
                      subtitle: '查看所有历史对话',
                      onTap: () => context.push(AppRoutes.profileHistory),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle(context, '个性化', isDark),
                    _buildMenuTile(
                      context,
                      icon: Icons.palette_outlined,
                      iconColor: bgStyle.accentColor,
                      title: '外观风格',
                      subtitle: bgStyle.name,
                      onTap: () => _showBackgroundStylePicker(context, ref),
                      isDark: isDark,
                    ),
                    _buildMenuTile(
                      context,
                      icon: Icons.notifications_outlined,
                      iconColor: cs.tertiary,
                      title: '通知设置',
                      subtitle: '学习提醒、复习提醒、计划提醒',
                      onTap: () => context.push(R.profileNotifications),
                      isDark: isDark,
                    ),
                    _buildMenuTile(
                      context,
                      icon: Icons.apps_rounded,
                      iconColor: cs.error,
                      title: '应用图标',
                      subtitle: '切换 App 桌面图标',
                      onTap: () => _showAppIconPicker(context, ref),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    // 退出登录按钮
                    Container(
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
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
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cs.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.logout_rounded,
                                    color: cs.error,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  '退出登录',
                                  style: TextStyle(
                                    fontSize: 16,
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
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTokenUsageCard(BuildContext context, WidgetRef ref, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final quotaAsync = ref.watch(tokenTodayUsageProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.profileTokenUsage),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.1),
                cs.secondary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '词元用量',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      quotaAsync.when(
                        data: (quota) => Text(
                          '今日已用 ${_formatNumber(quota.usedToday)} tokens',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        loading: () => Text(
                          '加载中...',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        error: (e, s) => Text(
                          '暂无数据',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '查看',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
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
          border: Border.all(
            color: cs.outline,
            width: 0.5,
          ),
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
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          iconColor.withValues(alpha: 0.15),
                          iconColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 22,
                    ),
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
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示背景风格选择器
  void _showBackgroundStylePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BackgroundStyleSheet(ref: ref),
    );
  }

  /// 显示 App 图标选择器
  void _showAppIconPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AppIconSheet(ref: ref),
    );
  }
}

/// App 图标选择器底部弹窗
class _AppIconSheet extends StatelessWidget {
  final WidgetRef ref;
  const _AppIconSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentAppIconProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示条
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFFA07A)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.apps_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '应用图标',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '长按桌面图标切换样式',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 图标列表
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _kIconConfigs.entries.map((entry) {
                  final isSelected = entry.key == current;
                  return GestureDetector(
                    onTap: () async {
                      // 调用原生切换（Android）
                      const channel = MethodChannel('app_icon');
                      await channel.invokeMethod('setIcon', {'icon': entry.key});
                      // 记录到 SharedPreferences
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('app_icon_alias', entry.key);
                      // 更新状态
                      ref.read(currentAppIconProvider.notifier).state = entry.key;
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? cs.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.asset(
                              'assets/images/icons/app_icon_${entry.key == 'Icon1' ? '1' : entry.key == 'Icon2' ? '2' : '3'}.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 背景风格选择器底部弹窗
class _BackgroundStyleSheet extends StatelessWidget {
  final WidgetRef ref;

  const _BackgroundStyleSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentStyle = ref.watch(backgroundStyleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示条
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [currentStyle.accentColor, currentStyle.accentColor.withValues(alpha: 0.6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '外观风格',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '切换背景、底色、强调色',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(backgroundStyleProvider.notifier).reset();
                      Navigator.pop(context);
                    },
                    child: Text(
                      '恢复默认',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 风格列表
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: KBackgroundStyles.all.length,
                separatorBuilder: (context, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final style = KBackgroundStyles.all[index];
                  final isSelected = style.id == currentStyle.id;
                  return _BackgroundStyleItem(
                    style: style,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () {
                      ref.read(backgroundStyleProvider.notifier).setStyle(style);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 背景风格单项
class _BackgroundStyleItem extends StatelessWidget {
  final BackgroundStyle style;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _BackgroundStyleItem({
    required this.style,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? style.accentColor.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? style.accentColor : cs.outline,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: style.accentColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // 双色块预览：浅色底 + 深色底
            Column(
              children: [
                Row(
                  children: [
                    _ColorDot(color: style.lightBg, size: 22),
                    const SizedBox(width: 4),
                    _ColorDot(color: style.darkBg, size: 22),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _ColorDot(color: style.accentColor, size: 10),
                    const SizedBox(width: 2),
                    _ColorDot(color: style.accentColor.withValues(alpha: 0.5), size: 10),
                    const SizedBox(width: 2),
                    _ColorDot(color: style.accentColor.withValues(alpha: 0.25), size: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    style.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: style.accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 小色块点
class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  const _ColorDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
    );
  }
}
