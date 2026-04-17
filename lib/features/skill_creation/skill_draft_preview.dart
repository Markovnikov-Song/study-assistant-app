// lib/features/skill_creation/skill_draft_preview.dart
// Skill 草稿预览组件
// 任务 27：对话式 Skill 创建 UI 页面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/skill/dialog_skill_creation_service.dart';
import '../../core/skill/skill_model.dart';

class SkillDraftPreview extends ConsumerStatefulWidget {
  final SkillDraft draft;
  final String sessionId;
  final VoidCallback onConfirmed;
  final VoidCallback onContinue;

  const SkillDraftPreview({
    super.key,
    required this.draft,
    required this.sessionId,
    required this.onConfirmed,
    required this.onContinue,
  });

  @override
  ConsumerState<SkillDraftPreview> createState() => _SkillDraftPreviewState();
}

class _SkillDraftPreviewState extends ConsumerState<SkillDraftPreview> {
  final _service = DialogSkillCreationService();
  bool _publishing = false;

  Future<void> _confirmAndPublish() async {
    setState(() => _publishing = true);
    try {
      await _service.confirmAndPublish(widget.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('学习方法已保存，可以在方法库中找到它'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onConfirmed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发布失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('确认你的学习方法'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提示横幅
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '这是根据你的描述整理出的学习方法，确认后即可使用。',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 名称
            _SectionLabel(label: '名称'),
            const SizedBox(height: 6),
            Text(
              draft.name ?? '（未命名）',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 描述
            if (draft.description != null) ...[
              _SectionLabel(label: '描述'),
              const SizedBox(height: 6),
              Text(
                draft.description!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 标签
            if (draft.tags.isNotEmpty) ...[
              _SectionLabel(label: '适用学科'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: draft.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 步骤列表
            _SectionLabel(
              label: '包含 ${draft.promptChain.length} 个学习环节',
            ),
            const SizedBox(height: 8),
            if (draft.promptChain.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('还没有学习环节，继续告诉 AI 你的学习步骤吧'),
                  ],
                ),
              )
            else
              ...draft.promptChain.asMap().entries.map(
                (entry) => _StepItem(
                  index: entry.key + 1,
                  prompt: entry.value.prompt,
                ),
              ),

            const SizedBox(height: 32),

            // 操作按钮
            Row(
              children: [
                // 继续修改
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _publishing ? null : widget.onContinue,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('继续修改'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 确认发布
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _publishing ? null : _confirmAndPublish,
                    icon: _publishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_publishing ? '保存中…' : '保存并使用'),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── 辅助 Widget ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int index;
  final String prompt;

  const _StepItem({required this.index, required this.prompt});

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
