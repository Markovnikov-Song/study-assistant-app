import 'package:flutter/material.dart';

/// 参数收集对话框 - 用于多轮对话收集缺失的学习规划参数
class ParamsCollectorDialog extends StatefulWidget {
  final List<String> missingParams;
  final Function(Map<String, dynamic>) onParamsCollected;
  final Map<String, List<String>>? paramOptions;

  const ParamsCollectorDialog({
    super.key,
    required this.missingParams,
    required this.onParamsCollected,
    this.paramOptions,
  });

  /// 显示参数收集对话框
  static Future<void> show(
    BuildContext context, {
    required List<String> missingParams,
    required Function(Map<String, dynamic>) onParamsCollected,
    Map<String, List<String>>? paramOptions,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ParamsCollectorDialog(
        missingParams: missingParams,
        onParamsCollected: onParamsCollected,
        paramOptions: paramOptions,
      ),
    );
  }

  @override
  State<ParamsCollectorDialog> createState() => _ParamsCollectorDialogState();
}

class _ParamsCollectorDialogState extends State<ParamsCollectorDialog> {
  final Map<String, dynamic> _collectedParams = {};
  int _currentIndex = 0;
  final TextEditingController _textController = TextEditingController();

  static const Map<String, String> _paramQuestions = {
    'subject': '您想学习哪个科目？',
    'exam_date': '您计划什么时间考试？',
    'exam_scope': '考试范围是哪些？',
    'daily_hours': '每天学习多长时间？',
    'target_score': '您的目标分数是多少？',
  };

  static const Map<String, List<String>> _defaultOptions = {
    'exam_date': ['本周', '下周', '下个月', '期末', '期中'],
    'exam_scope': ['全书', '前五章', '前十章', '指定章节'],
    'daily_hours': ['1小时', '2小时', '3小时', '4小时'],
    'target_score': ['60分', '70分', '80分', '90分', '100分'],
    'subject': ['数学', '语文', '英语', '物理', '化学', '生物', '历史', '地理', '政治'],
  };

  List<String> get _currentOptions {
    if (_currentIndex >= widget.missingParams.length) {
      return [];
    }
    final paramName = widget.missingParams[_currentIndex];
    final paramOpts = widget.paramOptions;
    if (paramOpts != null) {
      final found = paramOpts[paramName];
      if (found != null) {
        return found;
      }
    }
    final defaultOpts = _defaultOptions[paramName];
    return defaultOpts ?? [];
  }

  String get _currentQuestion {
    if (_currentIndex >= widget.missingParams.length) {
      return '';
    }
    final paramName = widget.missingParams[_currentIndex];
    return _paramQuestions[paramName] ?? '请输入$paramName';
  }

  String get _currentParamName {
    if (_currentIndex >= widget.missingParams.length) {
      return '';
    }
    return widget.missingParams[_currentIndex];
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex >= widget.missingParams.length - 1;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 进度指示器
              Row(
                children: List.generate(
                  widget.missingParams.length,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentIndex 
                            ? Theme.of(context).primaryColor 
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // 问题标题
              Text(
                _currentQuestion,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // 选项按钮（如果有选项）
              if (_currentOptions.isNotEmpty) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _currentOptions.map((option) {
                    return ActionChip(
                      label: Text(option),
                      onPressed: () => _selectOption(option),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              
              // 文本输入框
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: '或直接输入...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _onTextSubmitted,
                  ),
                ),
                onSubmitted: (_) => _onTextSubmitted(),
              ),
              const SizedBox(height: 16),
              
              // 跳过按钮
              if (!isLast)
                Center(
                  child: TextButton(
                    onPressed: _skipCurrent,
                    child: const Text('跳过此问题'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectOption(String option) {
    _collectedParams[_currentParamName] = option;
    _next();
  }

  void _onTextSubmitted() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      _collectedParams[_currentParamName] = text;
    }
    _textController.clear();
    _next();
  }

  void _skipCurrent() {
    _next();
  }

  void _next() {
    if (_currentIndex < widget.missingParams.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // 完成收集
      widget.onParamsCollected(_collectedParams);
      Navigator.of(context).pop();
    }
  }
}

/// 简化的参数收集器 - 用于单次收集单个参数
class SimpleParamCollector extends StatelessWidget {
  final String paramName;
  final String question;
  final List<String> options;
  final Function(String) onConfirm;

  const SimpleParamCollector({
    super.key,
    required this.paramName,
    required this.question,
    required this.options,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              return ActionChip(
                label: Text(option),
                onPressed: () => onConfirm(option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}