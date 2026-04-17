// lib/features/skill_marketplace/skill_detail_page.dart
// Skill 详情页面
// 任务 26：Skill 市场 UI 页面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/skill/marketplace_models.dart';
import '../../core/skill/skill_marketplace_service.dart';

class SkillDetailPage extends ConsumerStatefulWidget {
  final MarketplaceSkill skill;

  const SkillDetailPage({super.key, required this.skill});

  @override
  ConsumerState<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends ConsumerState<SkillDetailPage> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final svc = SkillMarketplaceService();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(skill.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _downloading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _download,
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text(
                      '添加',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名称
            Text(
              skill.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 描述
            Text(
              skill.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),

            // 元信息行
            _InfoRow(
              icon: Icons.source_outlined,
              label: '来源',
              value: SkillSourceExtendedX.fromString(skill.source?.name ?? '')
                  .displayName,
            ),
            _InfoRow(
              icon: Icons.download_outlined,
              label: '下载次数',
              value: '${skill.downloadCount} 次',
            ),
            _InfoRow(
              icon: Icons.info_outline,
              label: '版本',
              value: skill.version,
            ),
            const SizedBox(height: 16),

            // 标签
            Text(
              '标签',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: skill.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),

            // 步骤列表
            Text(
              '包含 ${skill.promptChain.length} 个学习环节',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...skill.promptChain.asMap().entries.map(
              (entry) => _StepCard(
                index: entry.key + 1,
                prompt: entry.value.prompt,
              ),
            ),
            const SizedBox(height: 32),

            // 下载按钮（底部）
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_downloading ? '添加中…' : '添加到我的方法库'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 辅助 Widget ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label：',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final String prompt;

  const _StepCard({required this.index, required this.prompt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              prompt,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
