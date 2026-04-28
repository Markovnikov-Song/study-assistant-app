import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/document.dart';
import '../../models/mindmap_library.dart';
import '../../providers/chat_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/library_provider.dart';
import '../../routes/app_router.dart';

/// CourseSpacePage — 学科详情页
///
/// 布局：
///   AppBar：学科名 + [生成] 按钮
///   ① 知识树区块   — 该学科下所有导图列表，点击进入 EditableMindMapPage
///   ② 知识关联图   — 占位（后续扩展）
///   ③ 学习进度     — 聚合所有 session 的节点点亮进度
class CourseSpacePage extends ConsumerWidget {
  final int subjectId;
  const CourseSpacePage({super.key, required this.subjectId});

  void _showGenerateSheet(BuildContext context, WidgetRef ref, int subjectId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GenerateMindmapSheet(subjectId: subjectId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(courseSessionsProvider(subjectId));

    // 从 schoolSubjectsProvider 取学科名
    final subjectName = ref.watch(schoolSubjectsProvider).maybeWhen(
          data: (list) =>
              list
                  .where((s) => s.subject.id == subjectId)
                  .firstOrNull
                  ?.subject
                  .name ??
              '学科详情',
          orElse: () => '学科详情',
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(subjectName),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: '资料库',
            onPressed: () => context.push(AppRoutes.subjectDetailPath(subjectId)),
          ),
          FilledButton.tonal(
            onPressed: () => _showGenerateSheet(context, ref, subjectId),
            child: const Text('生成'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (sessions) => RefreshIndicator(
          onRefresh: () =>
              ref.read(courseSessionsProvider(subjectId).notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── ① 知识树 ──────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.account_tree_outlined,
                title: '知识树',
                subtitle: '${sessions.length} 份思维导图',
              ),
              const SizedBox(height: 8),
              if (sessions.isEmpty)
                _EmptyMindmapCard(subjectId: subjectId)
              else
                ...sessions.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MindmapSessionCard(
                        session: s,
                        subjectId: subjectId,
                        ref: ref,
                      ),
                    )),

              const SizedBox(height: 24),

              // ── ③ 学习进度 ────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.bar_chart_outlined,
                title: '学习进度',
              ),
              const SizedBox(height: 8),
              _ProgressSection(subjectId: subjectId, sessions: sessions),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(subtitle!,
              style: TextStyle(fontSize: 12, color: cs.outline)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ① 知识树 — 导图 Session 卡片
// ─────────────────────────────────────────────────────────────────────────────

class _MindmapSessionCard extends ConsumerWidget {
  final MindMapSession session;
  final int subjectId;
  final WidgetRef ref;

  const _MindmapSessionCard({
    required this.session,
    required this.subjectId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final cs = Theme.of(context).colorScheme;
    final title = session.title?.isNotEmpty == true ? session.title! : '未命名大纲';
    final pct = session.totalNodes == 0
        ? 0
        : (session.litNodes / session.totalNodes * 100).floor();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.editableMindMap(subjectId, session.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              // 图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_tree_outlined,
                    color: cs.onPrimaryContainer, size: 20),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (session.isPinned) ...[
                          Icon(Icons.push_pin, size: 12, color: cs.primary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: session.totalNodes == 0
                                  ? 0
                                  : session.litNodes / session.totalNodes,
                              minHeight: 4,
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$pct%',
                            style: TextStyle(fontSize: 11, color: cs.outline)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.litNodes}/${session.totalNodes} 个知识点  ·  ${_formatDate(session.createdAt)}',
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                  ],
                ),
              ),
              // 菜单
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: cs.outline),
                onSelected: (v) {
                  if (v == 'rename') _showRenameDialog(context, widgetRef);
                  if (v == 'pin') _togglePin(context, widgetRef);
                  if (v == 'delete') _showDeleteDialog(context, widgetRef);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(session.isPinned ? '取消置顶' : '置顶'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(courseSessionsProvider(subjectId).notifier)
          .updateMeta(session.id, isPinned: !session.isPinned);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: session.title ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(
              hintText: '输入新名称', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final title = ctrl.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              await ref
                  .read(courseSessionsProvider(subjectId).notifier)
                  .renameSession(session.id, title);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除导图'),
        content: Text(
            '确认删除「${session.title?.isNotEmpty == true ? session.title : '未命名大纲'}」？\n此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(courseSessionsProvider(subjectId).notifier)
                  .deleteSession(session.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _EmptyMindmapCard extends StatelessWidget {
  final int subjectId;
  const _EmptyMindmapCard({required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.account_tree_outlined, size: 40, color: cs.outlineVariant),
          const SizedBox(height: 8),
          Text('还没有思维导图',
              style: TextStyle(fontSize: 14, color: cs.outline)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(
              '/chat/${DateTime.now().millisecondsSinceEpoch}/subject/$subjectId',
            ),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('去生成'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ 学习进度（三维度）
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressSection extends ConsumerWidget {
  final int subjectId;
  final List<MindMapSession> sessions;
  const _ProgressSection({required this.subjectId, required this.sessions});

  /// 取"最顶部的置顶 session"：优先 isPinned=true 且 sortOrder 最小；
  /// 若无置顶，则取 sortOrder 最小的第一个。
  MindMapSession? get _targetSession {
    if (sessions.isEmpty) return null;
    final pinned = sessions.where((s) => s.isPinned).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (pinned.isNotEmpty) return pinned.first;
    return (sessions.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))).first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final target = _targetSession;

    if (target == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Center(
          child: Text('暂无学习数据', style: TextStyle(color: cs.outline, fontSize: 13)),
        ),
      );
    }

    // 用 session 级别的三层进度 provider
    final progressAsync = ref.watch(fullMindMapProgressProvider(target.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: _buildContent(context, cs, target, progressAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    MindMapSession target,
    MindMapProgress progress,
  ) {
    final totalNodes = target.totalNodes;
    final litNodes = target.litNodes;
    final pct = totalNodes == 0 ? 0 : (litNodes / totalNodes * 100).floor();

    // 是否有三层进度数据
    final hasThreeDim = progress.overallProgress != null ||
        progress.readProgress != null ||
        progress.practiceProgress != null;

    // 置顶标签
    final isPinned = target.isPinned;
    final sessionTitle = target.title?.isNotEmpty == true ? target.title! : '未命名大纲';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标注当前统计的是哪个 session
        Row(
          children: [
            if (isPinned) ...[
              Icon(Icons.push_pin, size: 12, color: cs.primary),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                sessionTitle,
                style: TextStyle(fontSize: 12, color: cs.outline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 节点点亮进度
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('已点亮 $litNodes / $totalNodes 个节点',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: cs.primary)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: totalNodes == 0 ? 0 : litNodes / totalNodes,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (hasThreeDim) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _DimensionRow(
            icon: Icons.auto_stories,
            label: '阅读',
            value: ((progress.readProgress ?? 0) * 100).floor(),
            weight: '30%',
            color: Colors.blue,
            progress: progress.readProgress ?? 0,
          ),
          const SizedBox(height: 10),
          _DimensionRow(
            icon: Icons.quiz_outlined,
            label: '练习',
            value: ((progress.practiceProgress ?? 0) * 100).floor(),
            weight: '50%',
            color: Colors.orange,
            progress: progress.practiceProgress ?? 0,
          ),
          const SizedBox(height: 10),
          _DimensionRow(
            icon: Icons.star_outline,
            label: '掌握',
            value: ((progress.masteryProgress ?? 0) * 100).floor(),
            weight: '20%',
            color: Colors.green,
            progress: progress.masteryProgress ?? 0,
          ),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            '配合练习和复习将提升综合掌握度',
            style: TextStyle(fontSize: 11, color: cs.outline),
          ),
        ],
      ],
    );
  }
}

/// 单维度进度行
class _DimensionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String weight;
  final Color color;
  final double progress;

  const _DimensionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.weight,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurface),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '$value%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          weight,
          style: TextStyle(fontSize: 10, color: cs.outline),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 生成思维导图 Sheet — 选资料 + 触发生成
// ─────────────────────────────────────────────────────────────────────────────

class _GenerateMindmapSheet extends ConsumerStatefulWidget {
  final int subjectId;
  const _GenerateMindmapSheet({required this.subjectId});

  @override
  ConsumerState<_GenerateMindmapSheet> createState() =>
      _GenerateMindmapSheetState();
}

class _GenerateMindmapSheetState
    extends ConsumerState<_GenerateMindmapSheet> {
  final Set<int> _selectedDocIds = {};
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider(widget.subjectId));
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // 拖拽把手
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI 生成思维导图',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('选择资料范围，AI 自动提取知识点生成导图',
                          style:
                              TextStyle(fontSize: 12, color: cs.outline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 资料列表
          Expanded(
            child: docsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (docs) {
                final completed = docs
                    .where((d) => d.status == DocumentStatus.completed)
                    .toList();
                if (completed.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_outlined,
                              size: 48, color: cs.outlineVariant),
                          const SizedBox(height: 12),
                          Text('暂无可用资料',
                              style: TextStyle(color: cs.outline)),
                          const SizedBox(height: 6),
                          Text('请先在资料库上传并处理完成资料',
                              style: TextStyle(
                                  fontSize: 12, color: cs.outline)),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    // 全选/清空
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            _selectedDocIds.isEmpty
                                ? '全部资料（默认）'
                                : '已选 ${_selectedDocIds.length} 个资料',
                            style: TextStyle(
                                fontSize: 13, color: cs.outline),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              for (final d in completed) {
                                _selectedDocIds.add(d.id);
                              }
                            }),
                            child: const Text('全选'),
                          ),
                          TextButton(
                            onPressed: () => setState(
                                () => _selectedDocIds.clear()),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: completed.length,
                        itemBuilder: (_, i) {
                          final doc = completed[i];
                          final selected =
                              _selectedDocIds.contains(doc.id);
                          return CheckboxListTile(
                            value: selected,
                            title: Text(doc.filename,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            controlAffinity:
                                ListTileControlAffinity.trailing,
                            onChanged: (v) => setState(() {
                              if (v ?? false) {
                                _selectedDocIds.add(doc.id);
                              } else {
                                _selectedDocIds.remove(doc.id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 生成按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating ? '生成中…' : '开始生成'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final docId =
          _selectedDocIds.length == 1 ? _selectedDocIds.first : null;
      // 用 subjectId 作为 chatKey，mode = mindmap
      await ref
          .read(chatProvider(
                  (widget.subjectId.toString(), 'mindmap'))
              .notifier)
          .generateMindMap(docId: docId);

      // 生成完成后刷新 session 列表
      ref.invalidate(courseSessionsProvider(widget.subjectId));
      ref.invalidate(schoolSubjectsProvider);
      ref.invalidate(allSessionsProvider); // 同步刷新「我的」历史记录页

      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('思维导图已生成，已添加到知识树')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        messenger.showSnackBar(
          SnackBar(
              content: Text('生成失败：$e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
