import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/review.dart';
import '../../providers/review_provider.dart';
import '../quiz/node_practice_sheet.dart';

/// 复盘引导页面（6步复盘流程）
class ReviewSessionPage extends ConsumerStatefulWidget {
  final Mistake mistake;

  const ReviewSessionPage({super.key, required this.mistake});

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  int _currentStep = 0;
  int _selectedQuality = -1;
  bool _isLoading = false;
  String? _reviewContent;
  ReviewSubmitResult? _result;

  final List<String> _steps = [
    '查看原题',
    '重新答题',
    '分析原因',
    '练习巩固',
    '评分确认',
    '完成复盘',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_steps[_currentStep]),
        bottom: _buildProgressIndicator(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentStep(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSize _buildProgressIndicator() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(4),
      child: LinearProgressIndicator(
        value: (_currentStep + 1) / _steps.length,
        backgroundColor: Colors.grey.shade200,
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStepShowQuestion();
      case 1:
        return _buildStepRetry();
      case 2:
        return _buildStepAnalysis();
      case 3:
        return _buildStepPractice();
      case 4:
        return _buildStepRating();
      case 5:
        return _buildStepComplete();
      default:
        return const SizedBox();
    }
  }

  /// Step 1: 显示原题
  Widget _buildStepShowQuestion() {
    final theme = Theme.of(context);
    final mistake = widget.mistake;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('原题'),
          const SizedBox(height: 16),
          if (mistake.questionText != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                mistake.questionText!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (mistake.correctAnswer != null) ...[
            Text('正确答案', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                mistake.correctAnswer!,
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (mistake.userAnswer != null) ...[
            Text('你的答案', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                mistake.userAnswer!,
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Step 2: 重新答题
  Widget _buildStepRetry() {
    final theme = Theme.of(context);
    final mistake = widget.mistake;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('重新挑战'),
          const SizedBox(height: 8),
          Text(
            '再次尝试回答这个问题，检验是否真正理解',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (mistake.questionText != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                mistake.questionText!,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的答案：',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  mistake.correctAnswer ?? '（请自行思考答案）',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Step 3: 分析原因
  Widget _buildStepAnalysis() {
    final theme = Theme.of(context);
    final mistake = widget.mistake;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('错误原因分析'),
          const SizedBox(height: 8),
          Text(
            '分析这道题为什么会做错',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (mistake.mistakeCategory != null) ...[
            Text('可能的原因：', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _buildCategoryChip(mistake.mistakeCategory!),
            const SizedBox(height: 24),
          ],
          Text('复盘笔记（可选）：', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '写下你对这道题的理解和反思...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _reviewContent = value,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final labels = {
      'concept': ('概念模糊', Colors.blue),
      'calculation': ('计算错误', Colors.orange),
      'careless': ('粗心大意', Colors.purple),
      'complete': ('完全不会', Colors.red),
    };

    final entry = labels[category];
    if (entry == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: entry.$2.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: entry.$2.shade200),
      ),
      child: Text(
        entry.$1,
        style: TextStyle(
          color: entry.$2.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Step 4: 练习巩固
  Widget _buildStepPractice() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('类似题目练习'),
          const SizedBox(height: 8),
          Text(
            '为了巩固理解，建议找一道类似的题目练习',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.quiz_outlined, size: 40, color: Colors.blue.shade700),
                const SizedBox(height: 12),
                Text(
                  '针对性练习',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '基于「${widget.mistake.title ?? '该知识点'}」生成练习题，巩固理解',
                  style: TextStyle(color: Colors.blue.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    final nodeId = widget.mistake.nodeId;
                    final subjectId = widget.mistake.subjectId;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => NodePracticeSheet(
                        nodeId: nodeId ?? 'unknown',
                        nodeText: widget.mistake.title ?? '该知识点',
                        subjectId: subjectId,
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('开始练习'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _nextStep(),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('跳过'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _nextStep(),
                  icon: const Icon(Icons.check),
                  label: const Text('已完成练习'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Step 5: 评分确认
  Widget _buildStepRating() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('复盘评分'),
          const SizedBox(height: 8),
          Text(
            '给这次复盘表现打个分',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ...[
            (0, '忘了', '完全没有印象，需要重新学习', Colors.red),
            (1, '模糊', '有点印象，但不完整', Colors.orange),
            (2, '想起', '能想起来，但需要一点时间', Colors.blue),
            (3, '巩固', '完全掌握，下次可以直接答对', Colors.green),
          ].map((item) => _buildQualityOption(
                item.$1,
                item.$2,
                item.$3,
                item.$4,
              )),
        ],
      ),
    );
  }

  Widget _buildQualityOption(int quality, String label, String desc, Color color) {
    final isSelected = _selectedQuality == quality;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedQuality = quality),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label[0],
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  /// Step 6: 完成复盘
  Widget _buildStepComplete() {
    if (_result == null) {
      return const Center(child: Text('正在提交...'));
    }

    final hasNodeId = widget.mistake.nodeId != null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.celebration,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 24),
          Text(
            '复盘完成！',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 32),
          _buildResultCard(),
          const SizedBox(height: 24),
          // ── 后续学习引导 ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '接下来可以：',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (hasNodeId)
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.auto_stories,
                          label: '再读讲义',
                          color: Colors.blue,
                          onTap: () => _openLecture(widget.mistake.nodeId!),
                        ),
                      ),
                    if (hasNodeId) const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.quiz_outlined,
                        label: '巩固练习',
                        color: Colors.green,
                        onTap: () => _openPractice(widget.mistake.nodeId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  void _openLecture(String nodeId) {
    final subjectId = widget.mistake.subjectId;
    Navigator.pop(context);
    if (subjectId != null) {
      context.push('/course-space/$subjectId');
    } else {
      context.push('/course-space');
    }
  }

  void _openPractice(String? nodeId) {
    final subjectId = widget.mistake.subjectId;
    Navigator.pop(context);
    if (nodeId != null) {
      // 直接用 NodePracticeSheet 针对该知识点出题
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => NodePracticeSheet(
          nodeId: nodeId,
          nodeText: widget.mistake.title ?? nodeId,
          subjectId: subjectId,
        ),
      );
    } else if (subjectId != null) {
      context.push('/toolkit/quiz?subject=$subjectId');
    } else {
      context.push('/toolkit/quiz');
    }
  }

  Widget _buildResultCard() {
    final result = _result!;
    final nextReviewDays = result.newInterval;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule, size: 48, color: Colors.green.shade700),
          const SizedBox(height: 16),
          Text(
            nextReviewDays == 1 ? '明天继续复习' : '${nextReviewDays}天后复习',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '掌握度: ${result.newMastery}/5',
            style: TextStyle(color: Colors.green.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '期望因子: ${result.newEase.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.green.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildBottomBar() {
    if (_currentStep >= 5) return const SizedBox();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_currentStep > 0)
              TextButton(
                onPressed: _prevStep,
                child: const Text('上一步'),
              ),
            const Spacer(),
            if (_currentStep == 4)
              FilledButton(
                onPressed: _selectedQuality >= 0 ? _submitReview : null,
                child: const Text('提交复盘'),
              )
            else
              FilledButton(
                onPressed: _nextStep,
                child: const Text('下一步'),
              ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitReview() async {
    if (_selectedQuality < 0) return;

    setState(() => _isLoading = true);

    final notifier = ref.read(reviewNotifierProvider.notifier);
    final result = await notifier.submitReview(
      noteId: widget.mistake.id,
      quality: _selectedQuality,
      reviewContent: _reviewContent,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _result = result;
        _currentStep = 5;
      });
    }
  }
}

/// 后续行动按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
