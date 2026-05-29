import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import 'mini_app_models.dart';
import 'mini_app_providers.dart';

class WorkshopPage extends ConsumerWidget {
  const WorkshopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(miniAppsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final padding = isDesktop ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('学习小软件工坊'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(miniAppsProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
          IconButton(
            onPressed: () => context.push(R.workshopBuilder),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: '创建学习小软件',
          ),
        ],
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '学习小软件加载失败：$error',
          onRetry: () => ref.invalidate(miniAppsProvider),
        ),
        data: (apps) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(miniAppsProvider),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 18, padding, 0),
                sliver: SliverToBoxAdapter(
                  child: _WorkshopHero(
                    count: apps.length,
                    isDesktop: isDesktop,
                    onCreate: () => context.push(R.workshopBuilder),
                  ),
                ),
              ),
              if (apps.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    onCreate: () => context.push(R.workshopBuilder),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 120),
                  sliver: SliverGrid.builder(
                    itemCount: apps.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: width >= 1280 ? 3 : (isDesktop ? 2 : 1),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: isDesktop ? 1.5 : 1.35,
                    ),
                    itemBuilder: (context, index) {
                      return _MiniAppCard(app: apps[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkshopHero extends StatelessWidget {
  final int count;
  final bool isDesktop;
  final VoidCallback onCreate;

  const _WorkshopHero({
    required this.count,
    required this.isDesktop,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 26 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF2563EB), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 26 : 22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '用文档拼装学习小软件',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 30 : 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '告诉助教你的学习方法想法，系统会生成教学模板、内容包、练习流程、反馈策略和复习算法，并在后端编译成可校验的隐形积木画布。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: isDesktop ? 15 : 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatPill(label: '$count 个小软件'),
                    const _StatPill(label: '文档驱动'),
                    const _StatPill(label: '隐形画布'),
                    const _StatPill(label: '可运行预览'),
                  ],
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('创建'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniAppCard extends StatelessWidget {
  final MiniAppSummary app;

  const _MiniAppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => context.push(R.workshopApp(app.id)),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon(app.appType), color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _typeLabel(app.appType),
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_outline_rounded),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                app.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(label: app.status),
                  _Badge(label: app.validation.ok ? '校验通过' : '需要修订'),
                  if (app.validation.warnings.isNotEmpty)
                    _Badge(label: '${app.validation.warnings.length} 条提示'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(String type) {
    return switch (type) {
      'mistake_drill' => Icons.replay_circle_filled_rounded,
      'quest' => Icons.route_rounded,
      _ => Icons.style_rounded,
    };
  }

  static String _typeLabel(String type) {
    return switch (type) {
      'mistake_drill' => '错题训练',
      'quest' => '闯关练习',
      _ => '背记练习',
    };
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.widgets_rounded, size: 52),
            const SizedBox(height: 12),
            const Text(
              '还没有学习小软件',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '从一句需求开始，助教会帮你生成第一版文档、配置和可运行草稿。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('创建第一个'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;

  const _StatPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 42),
          const SizedBox(height: 10),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
