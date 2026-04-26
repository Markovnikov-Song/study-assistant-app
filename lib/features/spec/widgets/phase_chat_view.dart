import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/subject.dart';
import '../../../providers/subject_provider.dart';
import '../providers/study_planner_providers.dart';

/// 阶段 1：LLM 对话式收集规划目标
///
/// 核心改动：
/// - 用户发送自然语言消息，后端 LLM 提取参数
/// - 一句话即可提供所有参数（如"高数和线代，期末前，每天2小时"）
/// - LLM 失败时自动降级到表单模式（ParamFillCard 风格）
/// - 参数齐备后显示确认卡片
class PhaseChatView extends ConsumerStatefulWidget {
  final List<int> prefilledSubjectIds;
  final VoidCallback onConfirmed;

  const PhaseChatView({
    super.key,
    this.prefilledSubjectIds = const [],
    required this.onConfirmed,
  });

  @override
  ConsumerState<PhaseChatView> createState() => _PhaseChatViewState();
}

/// 模式：LLM 对话 / 表单降级
enum _Mode { chat, form }

class _PhaseChatViewState extends ConsumerState<PhaseChatView> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _dio = DioClient.instance.dio;

  _Mode _mode = _Mode.chat;
  bool _loading = false;

  // 对话气泡
  final List<_Bubble> _bubbles = [];

  // 表单模式的临时状态
  final Set<int> _selectedSubjectIds = {};
  final Set<String> _selectedSubjectNames = {};
  DateTime? _deadline;
  int _dailyMinutes = 60;
  int _formStep = 0; // 0=subjects, 1=deadline, 2=dailyMinutes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startConversation());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addBubble(_Bubble bubble) {
    setState(() => _bubbles.add(bubble));
    _scrollToBottom();
  }

  void _startConversation() {
    if (widget.prefilledSubjectIds.isNotEmpty) {
      _addBubble(_Bubble.assistant(
        '你好！我来帮你制定学习计划。\n\n'
        '告诉我你想学什么、什么时候截止、每天能花多少时间。\n\n'
        '比如：「高数和线代，期末前，每天2小时」',
      ));
    } else {
      _addBubble(_Bubble.assistant(
        '你好！我来帮你制定学习计划。\n\n'
        '告诉我你想学什么、什么时候截止、每天能花多少时间。\n\n'
        '比如：「高数，6月30日前，每天1.5小时」\n\n'
        '当然，如果你不确定，也可以一步步来——'
        '先告诉我你想学哪些学科？',
      ));
    }
  }

  /// 发送消息到后端 LLM 对话
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _loading) return;

    setState(() => _loading = true);
    _addBubble(_Bubble.user(text));
    _inputCtrl.clear();

    try {
      final res = await _dio.post('/api/spec/chat', data: {
        'message': text,
      });

      final data = res.data as Map<String, dynamic>;
      final reply = data['reply'] as String? ?? '';
      final ready = data['ready'] as bool? ?? false;
      final collected = data['collected'] as Map<String, dynamic>?;
      final missingSlots = (data['missing_slots'] as List?)?.cast<String>();

      if (ready && collected != null) {
        if (!mounted) return;
        _addBubble(_Bubble.assistant(reply));
        _addBubble(_Bubble.confirm(
          subjectIds: List<int>.from(collected['subject_ids'] ?? []),
          subjectNames: List<String>.from(collected['subject_names'] ?? []),
          deadline: collected['deadline'] as String,
          dailyMinutes: collected['daily_minutes'] as int,
        ));
      } else {
        if (!mounted) return;
        _addBubble(_Bubble.assistant(reply));
        if (missingSlots != null && missingSlots.isNotEmpty) {
          _addBubble(_Bubble.fallbackHint());
        }
      }
    } catch (e) {
      if (mounted) _addBubble(_Bubble.assistant('网络出了点问题，请稍后再试 🙏'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 确认收集到的参数，回调给父组件
  void _onConfirm({
    required List<int> subjectIds,
    required List<String> subjectNames,
    required String deadline,
    required int dailyMinutes,
  }) {
    final deadlineDate = DateTime.tryParse(deadline);
    if (deadlineDate == null) return;

    ref.read(planCollectionProvider.notifier).state = PlanCollectionState(
      subjectIds: subjectIds,
      subjectNames: subjectNames,
      deadline: deadlineDate,
      dailyMinutes: dailyMinutes,
    );
    widget.onConfirmed();
  }

  /// 降级到表单模式
  void _switchToFormMode() {
    setState(() {
      _mode = _Mode.form;
      _formStep = 0;
    });
    _addBubble(_Bubble.assistant(
      '好的，我来一步步引导你填写信息。\n\n'
      '首先，选择你想学习的学科（可多选）：',
    ));
  }

  /// 表单模式的学科确认
  void _onSubjectsConfirmed() {
    if (_selectedSubjectIds.isEmpty) {
      _addBubble(_Bubble.assistant('请至少选择一个学科'));
      return;
    }
    _addBubble(_Bubble.user('已选择：${_selectedSubjectNames.join('、')}'));
    _addBubble(_Bubble.assistant(
      '好的！截止日期是什么时候？\n\n'
      '你可以输入日期（如 2025-08-31），也可以说"期末"、"下个月"。',
    ));
    setState(() => _formStep = 1);
  }

  /// 表单模式的日期输入（也支持自然语言）
  void _onDeadlineInput(String text) {
    // 先尝试直接解析
    var parsed = DateTime.tryParse(text.trim());

    // 尝试简单相对日期
    if (parsed == null) {
      final now = DateTime.now();
      if (text.contains('下个月')) {
        parsed = DateTime(now.year, now.month + 1, 1);
      } else if (text.contains('下周')) {
        parsed = now.add(const Duration(days: 7));
      } else if (text.contains('两周') || text.contains('2周')) {
        parsed = now.add(const Duration(days: 14));
      } else if (text.contains('一个月') || text.contains('1个月')) {
        parsed = DateTime(now.year, now.month + 1, now.day);
      } else if (text.contains('期末')) {
        parsed = now.add(const Duration(days: 60));
      }
    }

    if (parsed == null || parsed.isBefore(DateTime.now())) {
      _addBubble(_Bubble.user(text));
      _addBubble(_Bubble.assistant('我没理解这个日期，请换个说法？如"6月30日"或"下个月"。'));
      return;
    }

    _deadline = parsed;
    final dateStr = '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    _addBubble(_Bubble.user(text));
    _addBubble(_Bubble.assistant(
      '截止日期：$dateStr。\n\n每天能花多少时间学习？（如"2小时"或直接输入分钟数）',
    ));
    setState(() => _formStep = 2);
  }

  /// 表单模式的时长输入
  void _onDurationInput(String text) {
    final trimmed = text.trim();
    int minutes = 60;

    if (trimmed.isNotEmpty) {
      // 尝试解析 "X小时" / "X小时" / "Xmin" 等
      final hourMatch = RegExp(r'(\d+\.?\d*)\s*(?:小时|h|hours?)').firstMatch(trimmed);
      final minMatch = RegExp(r'(\d+)\s*(?:分钟|min)').firstMatch(trimmed);

      if (hourMatch != null) {
        minutes = (double.parse(hourMatch.group(1)!) * 60).round().clamp(15, 480);
      } else if (minMatch != null) {
        minutes = int.parse(minMatch.group(1)!).clamp(15, 480);
      } else {
        final num = int.tryParse(trimmed);
        if (num != null && num >= 15 && num <= 480) {
          minutes = num;
        }
      }
    }

    _dailyMinutes = minutes;
    _addBubble(_Bubble.user(trimmed.isEmpty ? '使用默认 60 分钟' : '$minutes 分钟'));

    // 直接显示确认
    _showConfirmSummary();
  }

  void _showConfirmSummary() {
    final d = _deadline!;
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    _addBubble(_Bubble.confirm(
      subjectIds: _selectedSubjectIds.toList(),
      subjectNames: _selectedSubjectNames.toList(),
      deadline: dateStr,
      dailyMinutes: _dailyMinutes,
    ));
  }

  void _onSubmit() {
    final text = _inputCtrl.text.trim();
    _inputCtrl.clear();
    if (text.isEmpty) return;

    if (_mode == _Mode.chat) {
      _sendMessage(text);
    } else {
      switch (_formStep) {
        case 0:
          _onSubjectsConfirmed();
        case 1:
          _onDeadlineInput(text);
        case 2:
          _onDurationInput(text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subjectsAsync = ref.watch(subjectsProvider);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _bubbles.length + (_mode == _Mode.form && _formStep == 0 ? 1 : 0),
            itemBuilder: (_, i) {
              // 表单模式的学科选择器
              if (_mode == _Mode.form && _formStep == 0 && i == _bubbles.length) {
                return _SubjectSelector(
                  subjectsAsync: subjectsAsync,
                  prefilledIds: widget.prefilledSubjectIds,
                  selectedIds: _selectedSubjectIds,
                  onToggle: (id, name, selected) {
                    setState(() {
                      if (selected) {
                        _selectedSubjectIds.add(id);
                        _selectedSubjectNames.add(name);
                      } else {
                        _selectedSubjectIds.remove(id);
                        _selectedSubjectNames.remove(name);
                      }
                    });
                  },
                  onConfirm: _onSubjectsConfirmed,
                );
              }
              final bubble = _bubbles[i];
              return _BubbleWidget(
                bubble: bubble,
                onConfirm: () => _onConfirm(
                  subjectIds: bubble.subjectIds ?? [],
                  subjectNames: bubble.subjectNames ?? [],
                  deadline: bubble.deadline ?? '',
                  dailyMinutes: bubble.dailyMinutes ?? 60,
                ),
                onFallback: _switchToFormMode,
              );
            },
          ),
        ),
        // 加载指示
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          ),
        // 输入栏
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      hintText: _mode == _Mode.form && _formStep == 0
                          ? '或直接告诉我你的目标…'
                          : _mode == _Mode.form && _formStep == 1
                              ? '输入截止日期，如 2025-08-31 或"下个月"'
                              : _mode == _Mode.form && _formStep == 2
                                  ? '如"2小时"或直接输入分钟数'
                                  : '告诉我你的学习目标…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _onSubmit(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _onSubmit,
                  icon: const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 气泡数据 ──────────────────────────────────────────────────────────────────

enum _BubbleType { user, assistant, confirm, fallbackHint }

class _Bubble {
  final _BubbleType type;
  final String text;
  final bool isUser;
  // confirm 专用
  final List<int>? subjectIds;
  final List<String>? subjectNames;
  final String? deadline;
  final int? dailyMinutes;

  const _Bubble({
    required this.type,
    this.text = '',
    this.isUser = false,
    this.subjectIds,
    this.subjectNames,
    this.deadline,
    this.dailyMinutes,
  });

  factory _Bubble.user(String text) =>
      _Bubble(type: _BubbleType.user, text: text, isUser: true);
  factory _Bubble.assistant(String text) =>
      _Bubble(type: _BubbleType.assistant, text: text);
  factory _Bubble.confirm({
    required List<int> subjectIds,
    required List<String> subjectNames,
    required String deadline,
    required int dailyMinutes,
  }) =>
      _Bubble(type: _BubbleType.confirm, subjectIds: subjectIds,
          subjectNames: subjectNames, deadline: deadline, dailyMinutes: dailyMinutes);
  factory _Bubble.fallbackHint() =>
      _Bubble(type: _BubbleType.fallbackHint);
}

// ── 气泡 Widget ───────────────────────────────────────────────────────────────

class _BubbleWidget extends StatelessWidget {
  final _Bubble bubble;
  final VoidCallback? onConfirm;
  final VoidCallback? onFallback;

  const _BubbleWidget({
    required this.bubble,
    this.onConfirm,
    this.onFallback,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // fallbackHint 类型
    if (bubble.type == _BubbleType.fallbackHint) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          onPressed: onFallback,
          icon: const Icon(Icons.edit_note_outlined, size: 18),
          label: const Text('换种方式，一步步填写'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.outline,
          ),
        ),
      );
    }

    // confirm 类型
    if (bubble.type == _BubbleType.confirm) {
      return _ConfirmCard(
        bubble: bubble,
        onConfirm: onConfirm!,
      );
    }

    // 普通气泡
    return Align(
      alignment: bubble.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: bubble.isUser ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(bubble.isUser ? 18 : 4),
            bottomRight: Radius.circular(bubble.isUser ? 4 : 18),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          bubble.text,
          style: TextStyle(
            color: bubble.isUser ? cs.onPrimary : cs.onSurface,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── 确认卡片 ──────────────────────────────────────────────────────────────────

class _ConfirmCard extends StatelessWidget {
  final _Bubble bubble;
  final VoidCallback onConfirm;

  const _ConfirmCard({required this.bubble, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = bubble.subjectNames ?? [];
    final deadline = bubble.deadline ?? '';
    final mins = bubble.dailyMinutes ?? 60;
    final hours = mins / 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '规划信息确认',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.school_outlined, label: '学科', value: names.join('、')),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.event_outlined, label: '截止日期', value: deadline),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.timer_outlined, label: '每日时长', value: '${hours > 0 && hours == hours.roundToDouble() ? hours.toInt() : hours}小时'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('开始生成计划'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onPrimaryContainer),
        const SizedBox(width: 10),
        Text('$label：', style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── 学科选择器（表单降级模式）────────────────────────────────────────────────

class _SubjectSelector extends StatelessWidget {
  final AsyncValue<List<Subject>> subjectsAsync;
  final List<int> prefilledIds;
  final Set<int> selectedIds;
  final void Function(int id, String name, bool selected) onToggle;
  final VoidCallback onConfirm;

  const _SubjectSelector({
    required this.subjectsAsync,
    required this.prefilledIds,
    required this.selectedIds,
    required this.onToggle,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('加载学科失败：$e'),
        data: (subjects) {
          final active = subjects.where((s) => !s.isArchived).toList();
          if (active.isEmpty) {
            return Text(
              '暂无学科，请先在「我的 → 学科管理」创建学科',
              style: TextStyle(color: cs.outline),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: active.map((s) {
                  final selected = selectedIds.contains(s.id);
                  return FilterChip(
                    label: Text(s.name),
                    selected: selected,
                    onSelected: (v) => onToggle(s.id, s.name, v),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selectedIds.isEmpty ? null : onConfirm,
                  child: const Text('确认学科'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
