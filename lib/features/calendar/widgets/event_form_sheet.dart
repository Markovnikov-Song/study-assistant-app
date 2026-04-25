import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/event_bus/app_event_bus.dart';
import '../../../core/event_bus/calendar_events.dart';
import '../../../providers/subject_provider.dart';
import '../models/calendar_models.dart';
import '../services/calendar_api_service.dart';
import '../../spec/services/study_planner_api_service.dart';

enum _EventType { event, routine, task }

class EventFormSheet extends ConsumerStatefulWidget {
  final CalendarEvent? initialEvent;
  final DateTime? prefillDate;
  final int? prefillSubjectId;
  final String? prefillTitle;
  final String? prefillTime;

  const EventFormSheet({
    super.key,
    this.initialEvent,
    this.prefillDate,
    this.prefillSubjectId,
    this.prefillTitle,
    this.prefillTime,
  });

  @override
  ConsumerState<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends ConsumerState<EventFormSheet> {
  _EventType _type = _EventType.event;
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  int _durationMinutes = 60;
  int? _subjectId;
  String _color = '#6366F1';
  bool _isCountdown = false;
  String _priority = 'medium';
  bool _saving = false;
  String? _titleError;

  // 预设颜色
  static const _presetColors = [
    '#6366F1', '#10B981', '#F59E0B', '#EF4444',
    '#3B82F6', '#8B5CF6', '#EC4899', '#14B8A6',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.initialEvent;
    if (e != null) {
      _titleCtrl.text = e.title;
      _notesCtrl.text = e.notes ?? '';
      _date = e.eventDate;
      final parts = e.startTime.split(':');
      _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      _durationMinutes = e.durationMinutes;
      _subjectId = e.subjectId;
      _color = e.color;
      _isCountdown = e.isCountdown;
      _priority = e.priority;
    } else {
      if (widget.prefillDate != null) _date = widget.prefillDate!;
      if (widget.prefillTitle != null) _titleCtrl.text = widget.prefillTitle!;
      if (widget.prefillSubjectId != null) _subjectId = widget.prefillSubjectId;
      if (widget.prefillTime != null) {
        final parts = widget.prefillTime!.split(':');
        if (parts.length == 2) {
          _startTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? TimeOfDay.now().hour,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  bool _validate() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '请输入事件标题');
      return false;
    }
    setState(() => _titleError = null);
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(calendarApiServiceProvider);
      final data = {
        'title': _titleCtrl.text.trim(),
        'event_date': _formatDate(_date),
        'start_time': _formatTime(_startTime),
        'duration_minutes': _durationMinutes,
        if (_subjectId != null) 'subject_id': _subjectId,
        'color': _color,
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'is_countdown': _isCountdown,
        'priority': _priority,
        'source': 'manual',
      };

      CalendarEvent event;
      if (widget.initialEvent != null) {
        event = await api.updateEvent(widget.initialEvent!.id, data);
        AppEventBus.instance.fire(CalendarEventUpdated(
          eventId: event.id,
          eventDate: event.eventDate,
        ));
      } else {
        event = await api.createEvent(data);
        AppEventBus.instance.fire(CalendarEventCreated(
          eventId: event.id,
          eventDate: event.eventDate,
          source: 'manual',
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.initialEvent;
    if (e == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除事件'),
        content: Text('确定要删除「${e.title}」吗？'
            '${e.source == 'study-planner' ? '\n\n关联的学习计划任务也会被标记为跳过。' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(calendarApiServiceProvider);
      await api.deleteEvent(e.id);
      AppEventBus.instance.fire(CalendarEventDeleted(
        eventId: e.id,
        eventDate: e.eventDate,
        source: e.source,
      ));
      if (mounted) Navigator.pop(context);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$err')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final subjects = subjectsAsync.valueOrNull ?? [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // 拖拽把手
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 类型切换
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<_EventType>(
                segments: const [
                  ButtonSegment(value: _EventType.event, label: Text('事件')),
                  ButtonSegment(value: _EventType.routine, label: Text('例程')),
                  ButtonSegment(value: _EventType.task, label: Text('任务')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // 标题
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: '标题 *',
                      errorText: _titleError,
                      border: const OutlineInputBorder(),
                    ),
                    maxLength: 50,
                    onChanged: (_) {
                      if (_titleError != null) setState(() => _titleError = null);
                    },
                  ),
                  const SizedBox(height: 12),

                  // 日期
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(_formatDate(_date)),
                    subtitle: const Text('日期'),
                    onTap: _pickDate,
                  ),

                  if (_type == _EventType.event || _type == _EventType.routine) ...[
                    // 开始时间
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_outlined),
                      title: Text(_formatTime(_startTime)),
                      subtitle: const Text('开始时间'),
                      onTap: _pickTime,
                    ),
                    // 时长
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timer_outlined),
                      title: Text('$_durationMinutes 分钟'),
                      subtitle: const Text('时长'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: _durationMinutes > 15
                                ? () => setState(() => _durationMinutes -= 15)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _durationMinutes < 480
                                ? () => setState(() => _durationMinutes += 15)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 学科
                  if (subjects.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      initialValue: _subjectId,
                      decoration: const InputDecoration(
                        labelText: '学科（选填）',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('不绑定学科')),
                        ...subjects.map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            )),
                      ],
                      onChanged: (v) => setState(() => _subjectId = v),
                    ),
                  const SizedBox(height: 12),

                  // 颜色
                  Text('颜色', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _presetColors.map((c) {
                      final selected = c == _color;
                      return GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _hexColor(c),
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // 优先级
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: '优先级',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'high', child: Text('高')),
                      DropdownMenuItem(value: 'medium', child: Text('中')),
                      DropdownMenuItem(value: 'low', child: Text('低')),
                    ],
                    onChanged: (v) => setState(() => _priority = v!),
                  ),
                  const SizedBox(height: 12),

                  // 考试倒计时开关（仅事件类型）
                  if (_type == _EventType.event)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('标记为考试/重要日期'),
                      subtitle: const Text('在日历上高亮显示倒计时'),
                      value: _isCountdown,
                      onChanged: (v) => setState(() => _isCountdown = v),
                    ),

                  // 备注
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: '备注（选填）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                  const SizedBox(height: 16),

                  // 保存按钮
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(widget.initialEvent != null ? '保存修改' : '保存'),
                  ),
                  // 删除按钮（仅编辑 study-planner / agent 事件时显示）
                  if (widget.initialEvent != null &&
                      (widget.initialEvent!.source == 'study-planner' ||
                       widget.initialEvent!.source == 'agent'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _delete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('删除此事件'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }
}
