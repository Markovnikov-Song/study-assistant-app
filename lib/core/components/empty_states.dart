import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ============================================================
/// 空状态插画组件
/// 提供各种场景的空状态展示
/// ============================================================

/// 空状态组件基类
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? icon;
  final Widget? action;
  final double iconSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.iconSize = 80,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space2xl),
        child: Column(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Container(
                width: iconSize + 40,
                height: iconSize + 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withValues(alpha: 0.2),
                      cs.secondary.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      size: iconSize * 0.6,
                      color: cs.primary,
                    ),
                    child: icon!,
                  ),
                ),
              ),
            if (icon != null) const SizedBox(height: AppTheme.spaceLg),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spaceXl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 空对话状态
class EmptyChatState extends StatelessWidget {
  final VoidCallback? onAction;

  const EmptyChatState({super.key, this.onAction});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      title: '开始新对话',
      subtitle: '有什么想聊的？试试提问、制定计划\n或探索各种学习场景',
      action: onAction != null
          ? FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建对话'),
            )
          : null,
    );
  }
}

/// 空图书馆状态
class EmptyLibraryState extends StatelessWidget {
  final VoidCallback? onAction;

  const EmptyLibraryState({super.key, this.onAction});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: const Icon(Icons.menu_book_outlined),
      title: '图书馆空空的',
      subtitle: '去「我的」→「学科管理」创建学科\n再生成思维导图，课程就会出现',
      action: onAction != null
          ? FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('创建学科'),
            )
          : null,
    );
  }
}

/// 空工具箱状态
class EmptyToolkitState extends StatelessWidget {
  final String? toolName;
  final VoidCallback? onAction;

  const EmptyToolkitState({
    super.key,
    this.toolName,
    this.onAction,
  });

  IconData get _icon {
    switch (toolName) {
      case 'mistake':
        return Icons.error_outline_rounded;
      case 'notebook':
        return Icons.note_alt_outlined;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'solve':
        return Icons.calculate_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  String get _title {
    switch (toolName) {
      case 'mistake':
        return '暂无错题';
      case 'notebook':
        return '暂无笔记';
      case 'quiz':
        return '暂无测验';
      case 'solve':
        return '暂无答题记录';
      default:
        return '功能空置中';
    }
  }

  String get _subtitle {
    switch (toolName) {
      case 'mistake':
        return '做练习、拍题目来积累错题\n帮助巩固薄弱知识点';
      case 'notebook':
        return '在对话中长按消息收藏\n或拍照识别题目';
      case 'quiz':
        return '在学科导图中点击节点\n生成专属测验';
      case 'solve':
        return '拍题或输入题目来练习\nAI会帮你分析解答';
      default:
        return '使用工具箱的各项功能\n开始你的学习之旅';
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icon(_icon),
      title: _title,
      subtitle: _subtitle,
      action: onAction != null
          ? FilledButton(
              onPressed: onAction,
              child: const Text('开始使用'),
            )
          : null,
    );
  }
}

/// 空进度状态
class EmptyProgressState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onAction;

  const EmptyProgressState({
    super.key,
    this.title,
    this.subtitle,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: const Icon(Icons.trending_up_rounded),
      title: title ?? '暂无学习记录',
      subtitle: subtitle ?? '开始学习后这里会显示\n你的学习进度和成果',
      action: onAction != null
          ? FilledButton(
              onPressed: onAction,
              child: const Text('去学习'),
            )
          : null,
    );
  }
}

/// 空搜索结果状态
class EmptySearchState extends StatelessWidget {
  final String? keyword;
  final VoidCallback? onClear;

  const EmptySearchState({
    super.key,
    this.keyword,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: const Icon(Icons.search_off_rounded),
      title: keyword != null ? '未找到"$keyword"' : '无搜索结果',
      subtitle: '试试其他关键词\n或检查拼写是否正确',
      action: onClear != null
          ? TextButton(
              onPressed: onClear,
              child: const Text('清除搜索'),
            )
          : null,
    );
  }
}

/// 加载中状态
class LoadingState extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingState({
    super.key,
    this.message,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: cs.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 错误状态
class ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: const Icon(Icons.error_outline_rounded),
      iconSize: 64,
      title: '出错了',
      subtitle: message ?? '加载失败，请稍后重试',
      action: onRetry != null
          ? FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新加载'),
            )
          : null,
    );
  }
}

/// 成功状态
class SuccessState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const SuccessState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.check_circle_rounded,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icon(icon),
      title: title,
      subtitle: subtitle,
      action: onAction != null
          ? FilledButton(
              onPressed: onAction,
              child: Text(actionLabel ?? '完成'),
            )
          : null,
    );
  }
}
