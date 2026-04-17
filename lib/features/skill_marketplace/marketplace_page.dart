// lib/features/skill_marketplace/marketplace_page.dart
// Skill 市场浏览页面
// 任务 26：Skill 市场 UI 页面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/skill/marketplace_models.dart';
import '../../core/skill/skill_marketplace_service.dart';
import 'skill_detail_page.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _marketplaceServiceProvider = Provider<SkillMarketplaceService>(
  (ref) => SkillMarketplaceService(),
);

final _marketplaceSkillsProvider =
    FutureProvider.family<PaginatedSkillList, _MarketplaceFilter>(
  (ref, filter) async {
    final svc = ref.watch(_marketplaceServiceProvider);
    return svc.listSkills(
      tag: filter.tag,
      keyword: filter.keyword,
      sortBy: filter.sortBy,
    );
  },
);

class _MarketplaceFilter {
  final String? tag;
  final String? keyword;
  final String sortBy;

  const _MarketplaceFilter({
    this.tag,
    this.keyword,
    this.sortBy = 'download_count',
  });

  @override
  bool operator ==(Object other) =>
      other is _MarketplaceFilter &&
      tag == other.tag &&
      keyword == other.keyword &&
      sortBy == other.sortBy;

  @override
  int get hashCode => Object.hash(tag, keyword, sortBy);
}

// ── MarketplacePage ───────────────────────────────────────────────────────────

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  final _searchController = TextEditingController();
  String? _keyword;
  String? _selectedTag;
  String _sortBy = 'download_count';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() {
      _keyword = value.trim().isEmpty ? null : value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = _MarketplaceFilter(
      keyword: _keyword,
      tag: _selectedTag,
      sortBy: _sortBy,
    );    final skillsAsync = ref.watch(_marketplaceSkillsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习方法库'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '排序方式',
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'download_count',
                child: Text('按下载量'),
              ),
              PopupMenuItem(
                value: 'submitted_at',
                child: Text('按最新'),
              ),
              PopupMenuItem(
                value: 'name',
                child: Text('按名称'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索学习方法名称或描述…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
            ),
          ),

          // 标签过滤横向滚动
          _TagFilterBar(
            selectedTag: _selectedTag,
            onTagSelected: (tag) => setState(() => _selectedTag = tag),
          ),

          // Skill 列表
          Expanded(
            child: skillsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('加载失败：$err'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(_marketplaceSkillsProvider(filter)),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (result) {
                if (result.skills.isEmpty) {
                  return const Center(
                    child: Text('暂无 Skill，换个关键词试试？'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_marketplaceSkillsProvider(filter)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: result.skills.length,
                    separatorBuilder: (context2, index2) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final skill = result.skills[index];
                      return _SkillCard(skill: skill);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 标签过滤栏 ─────────────────────────────────────────────────────────────────

class _TagFilterBar extends StatelessWidget {
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;

  static const _tags = ['通用', '记忆', '复习', '解题', '考试', '理工科', '可视化'];

  const _TagFilterBar({
    required this.selectedTag,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "全部" 选项
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('全部'),
              selected: selectedTag == null,
              onSelected: (_) => onTagSelected(null),
            ),
          ),
          ..._tags.map(
            (tag) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tag),
                selected: selectedTag == tag,
                onSelected: (selected) =>
                    onTagSelected(selected ? tag : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skill 卡片 ─────────────────────────────────────────────────────────────────

class _SkillCard extends ConsumerStatefulWidget {
  final MarketplaceSkill skill;

  const _SkillCard({required this.skill});

  @override
  ConsumerState<_SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends ConsumerState<_SkillCard> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final svc = ref.read(_marketplaceServiceProvider);
      await svc.downloadSkill(widget.skill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${widget.skill.name}」已添加到我的方法库'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkillDetailPage(skill: skill),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      skill.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 下载按钮
                  _downloading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download_outlined),
                          tooltip: '下载',
                          onPressed: _download,
                        ),
                ],
              ),
              const SizedBox(height: 4),

              // 描述
              Text(
                skill.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 标签 + 下载次数
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: skill.tags
                          .take(3)
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              labelStyle: const TextStyle(fontSize: 11),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.download, size: 14, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        '${skill.downloadCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
