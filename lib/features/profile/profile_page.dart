import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../core/theme/styles/export.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';
import '../../services/token_service.dart';

final currentAppIconProvider = StateProvider<String>((ref) => 'Icon1');

final tokenTodayUsageProvider = FutureProvider<TokenQuota>((ref) {
  return TokenService().getQuota();
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final padding = isDesktop ? 40.0 : 18.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding,
              isDesktop ? 34 : 18,
              padding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _ProfileHero(user: user, isDesktop: isDesktop),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 0),
            sliver: SliverToBoxAdapter(
              child: _AiCommandBar(isDesktop: isDesktop),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 120),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : 1,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isDesktop ? 2.85 : 3.8,
              ),
              delegate: SliverChildListDelegate([
                _ActionTile(
                  icon: Icons.bookmark_rounded,
                  title: '科目管理',
                  subtitle: '维护科目、归档内容',
                  colors: const [Color(0xFF6C63FF), Color(0xFF4DD4FF)],
                  onTap: () => context.push(R.profileSubjects),
                ),
                _ActionTile(
                  icon: Icons.folder_special_rounded,
                  title: '资料管理',
                  subtitle: '资料、历年题、讲义',
                  colors: const [Color(0xFFFF7A59), Color(0xFFFFD166)],
                  onTap: () => context.push(R.profileResources),
                ),
                _ActionTile(
                  icon: Icons.history_rounded,
                  title: '对话历史',
                  subtitle: '回到之前的学习现场',
                  colors: const [Color(0xFF37D5D6), Color(0xFF36096D)],
                  onTap: () => context.push(R.profileHistory),
                ),
                _ActionTile(
                  icon: Icons.bolt_rounded,
                  title: 'Token 用量',
                  subtitle: '查看今日和历史消耗',
                  colors: const [Color(0xFFFF4FA3), Color(0xFF8B5CF6)],
                  onTap: () => context.push(R.profileTokenUsage),
                ),
                _ActionTile(
                  icon: Icons.tune_rounded,
                  title: 'AI 配置',
                  subtitle: '模型、接口、个性化',
                  colors: const [Color(0xFF00C9A7), Color(0xFF92FE9D)],
                  onTap: () => context.push(R.profileApiConfig),
                ),
                _ActionTile(
                  icon: Icons.apps_rounded,
                  title: '我的软件库',
                  subtitle: '打开和管理已创建的软件',
                  colors: const [Color(0xFF2563EB), Color(0xFF10B981)],
                  onTap: () => context.push(R.workshop),
                ),
                _ActionTile(
                  icon: Icons.settings_rounded,
                  title: '设置',
                  subtitle: '账号、外观、通知',
                  colors: const [Color(0xFF5961F9), Color(0xFFEE9AE5)],
                  onTap: () => context.push(R.profileSettings),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends ConsumerWidget {
  final User? user;
  final bool isDesktop;

  const _ProfileHero({required this.user, required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(tokenTodayUsageProvider);

    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101828), Color(0xFF5961F9), Color(0xFFFF7AB6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 30 : 24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5961F9).withValues(alpha: 0.26),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          _Avatar(user: user, size: isDesktop ? 86 : 72),
          SizedBox(width: isDesktop ? 22 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? '未登录',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 30 : 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(label: 'ID ${user?.id ?? '-'}'),
                    quota.when(
                      data: (q) => _HeroPill(
                        label: '今日 ${_compact(q.usedToday)} tokens',
                      ),
                      loading: () => const _HeroPill(label: '用量同步中'),
                      error: (_, _) => const _HeroPill(label: '用量暂不可用'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isDesktop)
            FilledButton.tonalIcon(
              onPressed: () => context.push(R.profileEdit),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('编辑资料'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: Colors.white,
              ),
            )
          else
            IconButton(
              onPressed: () => context.push(R.profileEdit),
              icon: const Icon(Icons.edit_rounded),
              color: Colors.white,
              tooltip: '编辑资料',
            ),
        ],
      ),
    );
  }

  String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _Avatar extends StatelessWidget {
  final User? user;
  final double size;

  const _Avatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatarBase64;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
      ),
      child: avatar != null && avatar.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.28),
              child: Image.memory(base64Decode(avatar), fit: BoxFit.cover),
            )
          : Center(
              child: Text(
                user?.username.isNotEmpty == true
                    ? user!.username[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;

  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AiCommandBar extends StatelessWidget {
  final bool isDesktop;

  const _AiCommandBar({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C63FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isDesktop ? '让 AI 帮你选学习方法、拆任务、排计划' : '让 AI 帮你选学习方法',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.filled(
            onPressed: () => context.push(R.spec),
            icon: const Icon(Icons.arrow_forward_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class AppIconSheet extends StatelessWidget {
  final WidgetRef ref;

  const AppIconSheet({super.key, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _ModernSheet(
      title: '应用图标',
      subtitle: '网页端会使用当前新版图标；移动端图标切换稍后统一重做。',
      icon: Icons.apps_rounded,
      child: Wrap(
        spacing: 12,
        children: [
          for (final entry in const {
            'Icon1': '星河',
            'Icon2': '朱砂',
            'Icon3': '丹霞',
          }.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: ref.watch(currentAppIconProvider) == entry.key,
              onSelected: (_) {
                ref.read(currentAppIconProvider.notifier).state = entry.key;
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class BackgroundStyleSheet extends StatelessWidget {
  final WidgetRef ref;

  const BackgroundStyleSheet({super.key, required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(uiStyleIdProvider);
    final previews = ref.watch(stylePreviewsProvider);
    return _ModernSheet(
      title: '外观风格',
      subtitle: '先保留原有主题切换入口，新版视觉会逐步统一到这里。',
      icon: Icons.palette_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final style in previews)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: style.primaryColor),
              title: Text(style.name),
              subtitle: Text(style.description),
              trailing: currentId == style.id
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () async {
                await ref.read(uiStyleIdProvider.notifier).setStyle(style.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _ModernSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _ModernSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF5961F9),
                  foregroundColor: Colors.white,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
