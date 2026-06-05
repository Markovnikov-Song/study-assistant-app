import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import '../../widgets/diy_corner_badge.dart';
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
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: DiyCornerBadge()),
          ),
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
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 14, padding, 0),
                sliver: SliverToBoxAdapter(
                  child: _WorkshopActionStrip(
                    apps: apps,
                    isDesktop: isDesktop,
                    onCreate: () => context.push(R.workshopBuilder),
                    onRunLatest: apps.isEmpty
                        ? null
                        : () => context.push(R.workshopApp(apps.first.id)),
                    onReviseLatest: apps.isEmpty
                        ? null
                        : () => _showReviseDialog(context, ref, apps.first),
                    onShareLatest: apps.isEmpty
                        ? null
                        : () => _copyShareText(context, apps.first),
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
                      final app = apps[index];
                      return _MiniAppCard(
                        app: app,
                        onRun: () => context.push(R.workshopApp(app.id)),
                        onRevise: () => _showReviseDialog(context, ref, app),
                        onShare: () => _copyShareText(context, app),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyShareText(BuildContext context, MiniAppSummary app) async {
    final text = [
      '学习小工具：${app.title}',
      '类型：${_miniAppTypeLabel(app.appType)}',
      '状态：${app.status}',
      if (app.description.trim().isNotEmpty) '说明：${app.description.trim()}',
      '入口：${R.workshopApp(app.id)}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制小工具分享文案')));
  }

  Future<void> _showReviseDialog(
    BuildContext context,
    WidgetRef ref,
    MiniAppSummary app,
  ) async {
    final revised = await showDialog<MiniAppRecord>(
      context: context,
      builder: (dialogContext) => _ReviseMiniAppDialog(
        app: app,
        onSubmit: (instruction) => ref
            .read(miniAppServiceProvider)
            .reviseApp(id: app.id, instruction: instruction),
      ),
    );
    if (revised == null || !context.mounted) return;
    ref.invalidate(miniAppsProvider);
    ref.invalidate(miniAppProvider(app.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          revised.validation.ok
              ? '已改造并校验通过'
              : '已改造，但还有 ${revised.validation.errors.length} 个校验问题',
        ),
      ),
    );
    context.push(R.workshopApp(app.id));
  }
}

class _ReviseMiniAppDialog extends StatefulWidget {
  final MiniAppSummary app;
  final Future<MiniAppRecord> Function(String instruction) onSubmit;

  const _ReviseMiniAppDialog({required this.app, required this.onSubmit});

  @override
  State<_ReviseMiniAppDialog> createState() => _ReviseMiniAppDialogState();
}

class _ReviseMiniAppDialogState extends State<_ReviseMiniAppDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '把这个小工具改成更适合我现在复习的版本：保留核心内容，增强反馈和复习节奏。',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final instruction = _controller.text.trim();
    if (instruction.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final revised = await widget.onSubmit(instruction);
      if (!mounted) return;
      Navigator.pop(context, revised);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('改造失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('改造：${widget.app.title}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '说清楚要怎么改，助教会基于现有文档和运行配置生成新版本。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '例如：改成错题优先、每轮 8 题、答错后先提示再讲解。',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high_rounded),
          label: Text(_saving ? '改造中' : '开始改造'),
        ),
      ],
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
                  '生成、改造、运行、分享学习小工具',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 30 : 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '软件工坊先收敛成四个入口：从一句需求生成，对已有工具提出改造，打开运行页试用，再复制给同学或老师。复杂配置都藏在这四个动作后面。',
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
                    const _StatPill(label: '生成'),
                    const _StatPill(label: '改造'),
                    const _StatPill(label: '运行'),
                    const _StatPill(label: '分享'),
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

class _WorkshopActionStrip extends StatelessWidget {
  final List<MiniAppSummary> apps;
  final bool isDesktop;
  final VoidCallback onCreate;
  final VoidCallback? onRunLatest;
  final VoidCallback? onReviseLatest;
  final VoidCallback? onShareLatest;

  const _WorkshopActionStrip({
    required this.apps,
    required this.isDesktop,
    required this.onCreate,
    required this.onRunLatest,
    required this.onReviseLatest,
    required this.onShareLatest,
  });

  @override
  Widget build(BuildContext context) {
    final latestLabel = apps.isEmpty ? '暂无小工具' : '最近：${apps.first.title}';
    final actions = [
      _WorkshopAction(
        icon: Icons.auto_awesome_rounded,
        title: '生成小工具',
        description: '说一句需求，追问补齐后生成可运行草稿。',
        actionLabel: '去生成',
        onPressed: onCreate,
      ),
      _WorkshopAction(
        icon: Icons.auto_fix_high_rounded,
        title: '改造小工具',
        description: latestLabel,
        actionLabel: '改造最近',
        onPressed: onReviseLatest,
      ),
      _WorkshopAction(
        icon: Icons.play_circle_outline_rounded,
        title: '运行小工具',
        description: latestLabel,
        actionLabel: '运行最近',
        onPressed: onRunLatest,
      ),
      _WorkshopAction(
        icon: Icons.ios_share_rounded,
        title: '保存/分享小工具',
        description: latestLabel,
        actionLabel: '复制分享',
        onPressed: onShareLatest,
      ),
    ];

    if (!isDesktop) {
      return Column(
        children: actions
            .map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: action,
              ),
            )
            .toList(),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: actions,
    );
  }
}

class _WorkshopAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _WorkshopAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAppCard extends StatelessWidget {
  final MiniAppSummary app;
  final VoidCallback onRun;
  final VoidCallback onRevise;
  final VoidCallback onShare;

  const _MiniAppCard({
    required this.app,
    required this.onRun,
    required this.onRevise,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onRun,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
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
                        child: Icon(
                          _miniAppTypeIcon(app.appType),
                          color: Colors.white,
                        ),
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
                              _miniAppTypeLabel(app.appType),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onRun,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('运行'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: onRevise,
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        tooltip: '改造小工具',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share_rounded),
                        tooltip: '复制分享文案',
                      ),
                    ],
                  ),
                ],
              ),
              const Positioned(top: 0, right: 0, child: DiyCornerBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _miniAppTypeIcon(String type) {
  return switch (type) {
    'mistake_drill' => Icons.replay_circle_filled_rounded,
    'quest' => Icons.route_rounded,
    _ => Icons.style_rounded,
  };
}

String _miniAppTypeLabel(String type) {
  return switch (type) {
    'mistake_drill' => '错题训练',
    'quest' => '闯关练习',
    _ => '背记练习',
  };
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
