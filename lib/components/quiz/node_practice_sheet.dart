import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

// ── 数据模型 ──────────────────────────────────────────────────────────────────

class QuizOption {
  final String key;
  final String content;
  final bool isCorrect;

  const QuizOption({required this.key, required this.content, required this.isCorrect});

  factory QuizOption.fromJson(Map<String, dynamic> j) => QuizOption(
        key: j['key'] as String? ?? '',
        content: j['content'] as String? ?? '',
        isCorrect: j['is_correct'] as bool? ?? false,
      );
}

class QuizQuestion {
  final String id;
  final String type; // choice / fill / calc / judge
  final String difficulty;
  final String difficultyLabel;
  final String question;
  final List<QuizOption> options;
  final String correctAnswer;
  final String explanation;
  final String sourceNodeId;
  final String sourceNodeTitle;
  final String knowledgeZone; // pre / current / post

  const QuizQuestion({
    required this.id,
    required this.type,
    required this.difficulty,
    required this.difficultyLabel,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.sourceNodeId,
    required this.sourceNodeTitle,
    required this.knowledgeZone,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'] as String? ?? '',
        type: j['type'] as String? ?? 'choice',
        difficulty: j['difficulty'] as String? ?? 'L1',
        difficultyLabel: j['difficulty_label'] as String? ?? '基础',
        question: j['question'] as String? ?? '',
        options: (j['options'] as List?)
                ?.map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        correctAnswer: j['correct_answer'] as String? ?? '',
        explanation: j['explanation'] as String? ?? '',
        sourceNodeId: j['source_node_id'] as String? ?? '',
        sourceNodeTitle: j['source_node_title'] as String? ?? '',
        knowledgeZone: j['knowledge_zone'] as String? ?? 'current',
      );
}

// ── QuizService ───────────────────────────────────────────────────────────────

class QuizService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<QuizQuestion>> generateForNode({
    required String nodeId,
    required String nodeTitle,
    String? nodeContent,
    int count = 3,
  }) async {
    final res = await _dio.post('/api/quiz/generate', data: {
      'node_id': nodeId,
      'node_title': nodeTitle,
      if (nodeContent != null) 'node_content': nodeContent,
      'question_count': count,
      'question_types': ['choice', 'judge'],
      'difficulty': 'mixed',
    });
    final data = res.data as Map<String, dynamic>;
    return (data['questions'] as List?)
            ?.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<Map<String, dynamic>> submitAnswer({
    required String questionId,
    required String userAnswer,
    required String nodeId,
    required String nodeTitle,
    required String questionText,
    required String correctAnswer,
    required String questionType,
    int? subjectId,
  }) async {
    final res = await _dio.post('/api/quiz/submit-answer', queryParameters: {
      'question_id': questionId,
      'user_answer': userAnswer,
      'node_id': nodeId,
      'node_title': nodeTitle,
      'question_text': questionText,
      'correct_answer': correctAnswer,
      'question_type': questionType,
      if (subjectId != null) 'subject_id': subjectId,
    });
    return res.data as Map<String, dynamic>;
  }
}

final quizServiceProvider = Provider<QuizService>((_) => QuizService());

// ── NodePracticeSheet ─────────────────────────────────────────────────────────

/// 节点练习底部弹窗：生成题目 → 逐题作答 → 显示结果
class NodePracticeSheet extends ConsumerStatefulWidget {
  final String nodeId;
  final String nodeText;
  final int? subjectId;

  const NodePracticeSheet({
    super.key,
    required this.nodeId,
    required this.nodeText,
    this.subjectId,
  });

  @override
  ConsumerState<NodePracticeSheet> createState() => _NodePracticeSheetState();
}

class _NodePracticeSheetState extends ConsumerState<NodePracticeSheet> {
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;
  String? _selectedAnswer; // 当前题目用户选择
  bool _submitted = false;  // 当前题目是否已提交
  Map<String, dynamic>? _result; // 提交结果
  final _fillCtrl = TextEditingController();

  // 统计
  int _correctCount = 0;
  int _mistakeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await ref.read(quizServiceProvider).generateForNode(
            nodeId: widget.nodeId,
            nodeTitle: widget.nodeText,
            count: 3,
          );
      if (mounted) setState(() { _questions = questions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _submitAnswer() async {
    final q = _questions[_currentIndex];
    final answer = q.type == 'choice' || q.type == 'judge'
        ? (_selectedAnswer ?? '')
        : _fillCtrl.text.trim();

    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先作答')),
      );
      return;
    }

    setState(() => _submitted = true);

    try {
      final result = await ref.read(quizServiceProvider).submitAnswer(
            questionId: q.id,
            userAnswer: answer,
            nodeId: widget.nodeId,
            nodeTitle: widget.nodeText,
            questionText: q.question,
            correctAnswer: q.correctAnswer,
            questionType: q.type,
            subjectId: widget.subjectId,
          );
      if (mounted) {
        setState(() => _result = result);
        final correct = result['correct'] as bool? ?? false;
        if (correct) _correctCount++; else _mistakeCount++;
      }
    } catch (e) {
      if (mounted) setState(() => _result = {'correct': false, 'message': '提交失败：$e'});
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _submitted = false;
        _result = null;
        _fillCtrl.clear();
      });
    } else {
      _showSummary();
    }
  }

  void _showSummary() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('练习完成 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_correctCount / ${_questions.length} 题正确',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cs.primary),
            ),
            const SizedBox(height: 8),
            if (_mistakeCount > 0)
              Text(
                '$_mistakeCount 道错题已自动加入错题本',
                style: TextStyle(fontSize: 13, color: cs.outline),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭 dialog
              Navigator.pop(context); // 关闭 sheet
            },
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '练习：${widget.nodeText}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 内容
            Expanded(
              child: _loading
                  ? const Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('AI 正在出题…', style: TextStyle(fontSize: 13)),
                      ],
                    ))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: cs.error),
                              const SizedBox(height: 12),
                              Text('出题失败：$_error'),
                              const SizedBox(height: 16),
                              FilledButton(onPressed: () {
                                setState(() { _loading = true; _error = null; });
                                _loadQuestions();
                              }, child: const Text('重试')),
                            ],
                          ),
                        )
                      : _questions.isEmpty
                          ? const Center(child: Text('暂无题目'))
                          : _buildQuestion(scrollCtrl, cs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(ScrollController scrollCtrl, ColorScheme cs) {
    final q = _questions[_currentIndex];
    final isChoice = q.type == 'choice';
    final isJudge = q.type == 'judge';
    final isCorrect = _result?['correct'] as bool? ?? false;

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(20),
      children: [
        // 进度
        Row(
          children: [
            Text(
              '${_currentIndex + 1} / ${_questions.length}',
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _questions.length,
                  minHeight: 4,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _DifficultyBadge(label: q.difficultyLabel, difficulty: q.difficulty),
          ],
        ),
        const SizedBox(height: 20),

        // 题目
        Text(q.question, style: const TextStyle(fontSize: 15, height: 1.6)),
        const SizedBox(height: 16),

        // 选项 / 输入框
        if (isChoice)
          ...q.options.map((opt) => _ChoiceOption(
                option: opt,
                selected: _selectedAnswer == opt.key,
                submitted: _submitted,
                onTap: _submitted ? null : () => setState(() => _selectedAnswer = opt.key),
              ))
        else if (isJudge)
          Row(
            children: ['正确', '错误'].map((label) {
              final key = label == '正确' ? 'T' : 'F';
              final selected = _selectedAnswer == key;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: _submitted ? null : () => setState(() => _selectedAnswer = key),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: selected ? cs.primaryContainer : null,
                      side: BorderSide(
                        color: selected ? cs.primary : cs.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(label),
                  ),
                ),
              );
            }).toList(),
          )
        else
          TextField(
            controller: _fillCtrl,
            enabled: !_submitted,
            decoration: InputDecoration(
              hintText: '输入你的答案',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 3,
          ),

        const SizedBox(height: 20),

        // 提交 / 下一题
        if (!_submitted)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitAnswer,
              child: const Text('提交答案'),
            ),
          )
        else ...[
          // 结果反馈
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCorrect ? '回答正确！' : '答错了',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    if (!isCorrect) ...[
                      const Spacer(),
                      Text(
                        '已加入错题本',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                      ),
                    ],
                  ],
                ),
                if (!isCorrect) ...[
                  const SizedBox(height: 8),
                  Text(
                    '正确答案：${q.correctAnswer}',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                  ),
                ],
                if (q.explanation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '解析：${q.explanation}',
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nextQuestion,
              child: Text(_currentIndex < _questions.length - 1 ? '下一题' : '查看结果'),
            ),
          ),
        ],
      ],
    );
  }
}

// ── 选择题选项 ────────────────────────────────────────────────────────────────

class _ChoiceOption extends StatelessWidget {
  final QuizOption option;
  final bool selected;
  final bool submitted;
  final VoidCallback? onTap;

  const _ChoiceOption({
    required this.option,
    required this.selected,
    required this.submitted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color? bgColor;
    Color borderColor = cs.outlineVariant;

    if (submitted) {
      if (option.isCorrect) {
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
      } else if (selected && !option.isCorrect) {
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
      }
    } else if (selected) {
      bgColor = cs.primaryContainer;
      borderColor = cs.primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor ?? cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? cs.primary : cs.surfaceContainerHigh,
              ),
              child: Center(
                child: Text(
                  option.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary : cs.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(option.content, style: const TextStyle(fontSize: 14)),
            ),
            if (submitted && option.isCorrect)
              Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
            if (submitted && selected && !option.isCorrect)
              Icon(Icons.cancel, size: 18, color: Colors.red.shade400),
          ],
        ),
      ),
    );
  }
}

// ── 难度标签 ──────────────────────────────────────────────────────────────────

class _DifficultyBadge extends StatelessWidget {
  final String label;
  final String difficulty;

  const _DifficultyBadge({required this.label, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty) {
      'L1' => Colors.green,
      'L2' => Colors.orange,
      'L3' => Colors.red,
      _ => Colors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color.shade700, fontWeight: FontWeight.w600),
      ),
    );
  }
}
