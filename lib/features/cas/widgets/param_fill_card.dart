import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/action_result.dart';

/// 参数补全卡片 — 根据 ParamRequest.type 渲染对应输入控件。
/// 复用 SceneCard 的视觉样式（圆角卡片、左侧彩色竖条）。
class ParamFillCard extends ConsumerStatefulWidget {
  final ParamRequest param;
  final ValueChanged<dynamic> onFilled;
  final VoidCallback onCancel;

  const ParamFillCard({
    super.key,
    required this.param,
    required this.onFilled,
    required this.onCancel,
  });

  @override
  ConsumerState<ParamFillCard> createState() => _ParamFillCardState();
}

class _ParamFillCardState extends ConsumerState<ParamFillCard> {
  dynamic _value;
  final _textCtrl = TextEditingController();
  final Set<String> _checkedOptions = {};

  @override
  void initState() {
    super.initState();
    _value = widget.param.defaultValue;
    if (widget.param.type == ParamType.checkbox) {
      // checkbox 默认选中 default 中的值
      final def = widget.param.defaultValue;
      if (def is List) _checkedOptions.addAll(def.cast<String>());
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    dynamic val;
    switch (widget.param.type) {
      case ParamType.radio:
        val = _value;
        break;
      case ParamType.checkbox:
        val = _checkedOptions.toList();
        break;
      case ParamType.number:
        val = _value ?? widget.param.min ?? 0;
        break;
      case ParamType.text:
        val = _textCtrl.text.trim();
        if (val.isEmpty) return;
        break;
      case ParamType.date:
        val = _value;
        break;
      case ParamType.topicTree:
        val = _value;
        break;
    }
    if (val == null) return;
    widget.onFilled(val);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧彩色竖条
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      widget.param.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 输入控件
                    _buildInput(isDark, cs),
                    const SizedBox(height: 16),
                    // 操作按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: widget.onCancel,
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _canSubmit() ? _submit : null,
                          child: const Text('确认'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    switch (widget.param.type) {
      case ParamType.radio:
        return _value != null;
      case ParamType.checkbox:
        return _checkedOptions.isNotEmpty;
      case ParamType.number:
        return _value != null;
      case ParamType.text:
        return _textCtrl.text.trim().isNotEmpty;
      case ParamType.date:
        return _value != null;
      case ParamType.topicTree:
        return !widget.param.required || _value != null;
    }
  }

  Widget _buildInput(bool isDark, ColorScheme cs) {
    switch (widget.param.type) {
      case ParamType.radio:
        return _buildRadio(isDark);
      case ParamType.checkbox:
        return _buildCheckbox(isDark);
      case ParamType.number:
        return _buildNumber(isDark);
      case ParamType.text:
        return _buildText(isDark);
      case ParamType.date:
        return _buildDate(isDark);
      case ParamType.topicTree:
        return _buildTopicTree(isDark);
    }
  }

  Widget _buildRadio(bool isDark) {
    final options = widget.param.options ?? [];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = _value == opt;
        return ChoiceChip(
          label: Text(opt),
          selected: selected,
          onSelected: (_) => setState(() => _value = opt),
        );
      }).toList(),
    );
  }

  Widget _buildCheckbox(bool isDark) {
    final options = widget.param.options ?? [];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final checked = _checkedOptions.contains(opt);
        return FilterChip(
          label: Text(opt),
          selected: checked,
          onSelected: (v) => setState(() {
            if (v) {
              _checkedOptions.add(opt);
            } else {
              _checkedOptions.remove(opt);
            }
          }),
        );
      }).toList(),
    );
  }

  Widget _buildNumber(bool isDark) {
    final min = widget.param.min ?? 0;
    final max = widget.param.max ?? 100;
    final step = widget.param.step ?? 1;
    _value ??= widget.param.defaultValue ?? min;
    final current = (_value as num).toDouble();

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: current > min
              ? () => setState(() => _value = (current - step).clamp(min, max))
              : null,
        ),
        Expanded(
          child: Text(
            current % 1 == 0 ? current.toInt().toString() : current.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: current < max
              ? () => setState(() => _value = (current + step).clamp(min, max))
              : null,
        ),
      ],
    );
  }

  Widget _buildText(bool isDark) {
    return TextField(
      controller: _textCtrl,
      maxLength: widget.param.maxLength,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: '请输入${widget.param.label}',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildDate(bool isDark) {
    final dateStr = _value as String?;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final minDate = widget.param.minDate != null
            ? DateTime.tryParse(widget.param.minDate!) ?? now
            : now;
        final maxDate = widget.param.maxDate != null
            ? DateTime.tryParse(widget.param.maxDate!)
            : null;

        final picked = await showDatePicker(
          context: context,
          initialDate: dateStr != null ? (DateTime.tryParse(dateStr) ?? now) : now,
          firstDate: minDate,
          lastDate: maxDate ?? DateTime(2100),
        );
        if (picked != null) {
          setState(() => _value = picked.toIso8601String().substring(0, 10));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: 8),
            Text(
              dateStr ?? '选择日期',
              style: TextStyle(
                color: dateStr != null ? null : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicTree(bool isDark) {
    // 简化实现：文本输入，后续可替换为真正的知识点树选择器
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textCtrl,
          onChanged: (v) => setState(() => _value = v.trim().isEmpty ? null : v.trim()),
          decoration: InputDecoration(
            hintText: '输入知识点名称（可选）',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: const Icon(Icons.account_tree_outlined, size: 18),
          ),
        ),
        if (!widget.param.required)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '可选，不填则推荐全部错题',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
      ],
    );
  }
}
