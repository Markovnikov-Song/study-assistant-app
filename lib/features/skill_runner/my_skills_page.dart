import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import 'skill_runner_page.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _mySkillsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient.instance.dio.get('/api/agent/skills');
  final data = res.data as Map<String, dynamic>;
  return ((data['skills'] as List?) ?? []).cast<Map<String, dynamic>>();
});

// ── MySkillsPage ──────────────────────────────────────────────────────────────

class MySkillsPage extends ConsumerStatefulWidget {
  const MySkillsPage({super.key});

  @override
  ConsumerState<MySkillsPage> createState() => _MySkillsPageState();
}

class _MySkillsPageState extends ConsumerState<MySkillsPage> {
  String _query = '';
  String? _selectedTag;

  static const _allTags = ['通用', '记忆', '复习', '解题', '考试', '理工科', '可视化'];

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> skills) {
    var result = skills;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((s) {
        final name = (s['name'] as String? ?? '').toLowerCase();
        final desc = (s['description'] as String? ?? '').toLowerCase();
        return name.contains(q) || desc.contains(q);
      }).toList();
    }
    if (_selectedTag != null) {
      result = result.where((s) {
        final tags = (s['tags'] as List?)?.cast<String>() ?? [];
        return tags.contains(_selectedTag);
      }).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(_mySkillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的方法库'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => ref.invalidate(_mySkillsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索学习方法…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          // 标签过滤
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('全部'),
                    selected: _selectedTag == null,
                    onSelected: (_) => setState(() => _selectedTag = null),
                  ),
                ),
                ..._allTags.map((tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: _selectedTag == tag,
                        onSelected: (v) =>
                            setState(() => _selectedTag = v ? tag : null),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Skill 列表
          Expanded(
            child: skillsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('加载失败：$e'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_mySkillsProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (skills) {
                final filtered = _filter(skills);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant),
                        const SizedBox(height: 12),
                        const Text('没有找到匹配的学习方法',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _SkillCard(skill: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skill 卡片 ─────────────────────────────────────────────────────────────────

class _SkillCard extends StatelessWidget {
  final Map<String, dynamic> skill;

  const _SkillCard({required this.skill});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = skill['name'] as String? ?? '';
    final description = skill['description'] as String? ?? '';
    final tags = (skill['tags'] as List?)?.cast<String>() ?? [];
    final steps = (skill['promptChain'] as List?)?.length ?? 0;
    final isBuiltin = skill['type'] == 'builtin';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkillRunnerPage(
              skillId: skill['id'] as String,
              skillName: name,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (isBuiltin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '内置',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSecondaryContainer),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // 标签
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(tag,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant)),
                              ))
                          .toList(),
                    ),
                  ),
                  // 步骤数
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.format_list_numbered,
                          size: 14, color: cs.outline),
                      const SizedBox(width: 3),
                      Text('$steps 步',
                          style:
                              TextStyle(fontSize: 12, color: cs.outline)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 开始按钮
                  FilledButton.tonal(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SkillRunnerPage(
                          skillId: skill['id'] as String,
                          skillName: name,
                        ),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('开始'),
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
