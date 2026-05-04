import 'package:flutter/material.dart';

/// 错误类型
enum ErrorType {
  error,
  warning,
  info,
  success,
}

/// 统一的错误提示组件
/// 支持自动关闭、手动关闭、点击重试等功能
class ErrorToast extends StatefulWidget {
  final String message;
  final ErrorType type;
  final Duration? duration;
  final VoidCallback? onClose;
  final VoidCallback? onRetry;
  final bool dismissible;
  final Widget? customIcon;

  const ErrorToast({
    super.key,
    required this.message,
    this.type = ErrorType.error,
    this.duration = const Duration(seconds: 5),
    this.onClose,
    this.onRetry,
    this.dismissible = true,
    this.customIcon,
  });

  /// 显示错误提示
  static void show(
    BuildContext context,
    String message, {
    ErrorType type = ErrorType.error,
    Duration? duration,
    VoidCallback? onClose,
    VoidCallback? onRetry,
    bool dismissible = true,
    Widget? customIcon,
  }) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => ErrorToast(
        message: message,
        type: type,
        duration: duration,
        onClose: () {
          onClose?.call();
          entry.remove();
        },
        onRetry: onRetry,
        dismissible: dismissible,
        customIcon: customIcon,
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<ErrorToast> createState() => _ErrorToastState();
}

class _ErrorToastState extends State<ErrorToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slideAnimation = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // 自动关闭
    if (widget.duration != null && widget.duration! > Duration.zero) {
      Future.delayed(widget.duration!, () {
        _dismiss();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onClose?.call();
    });
  }

  void _handleTap() {
    if (widget.onRetry != null) {
      widget.onRetry!();
    }
    _dismiss();
  }

  Widget _buildIcon() {
    if (widget.customIcon != null) {
      return widget.customIcon!;
    }

    final iconData = switch (widget.type) {
      ErrorType.error => Icons.error_outline,
      ErrorType.warning => Icons.warning_amber_outlined,
      ErrorType.info => Icons.info_outline,
      ErrorType.success => Icons.check_circle_outline,
    };

    final color = switch (widget.type) {
      ErrorType.error => Colors.red,
      ErrorType.warning => Colors.orange,
      ErrorType.info => Colors.blue,
      ErrorType.success => Colors.green,
    };

    return Icon(iconData, color: color, size: 24);
  }

  Color _getBackgroundColor() {
    final theme = Theme.of(context);
    switch (widget.type) {
      case ErrorType.error:
        return theme.colorScheme.errorContainer;
      case ErrorType.warning:
        return Colors.orange[100] ?? Colors.orange.shade100;
      case ErrorType.info:
        return Colors.blue[100] ?? Colors.blue.shade100;
      case ErrorType.success:
        return theme.colorScheme.successContainer;
    }
  }

  Color _getTextColor() {
    final theme = Theme.of(context);
    switch (widget.type) {
      case ErrorType.error:
        return theme.colorScheme.onErrorContainer;
      case ErrorType.warning:
        return Colors.orange[900] ?? Colors.orange.shade900;
      case ErrorType.info:
        return Colors.blue[900] ?? Colors.blue.shade900;
      case ErrorType.success:
        return theme.colorScheme.onSuccessContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation.drive(
          Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero),
        ),
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onRetry != null ? _handleTap : null,
              child: Container(
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _buildIcon(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: _getTextColor(),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (widget.dismissible || widget.onRetry != null)
                      const SizedBox(width: 8),
                    if (widget.onRetry != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        onPressed: () {
                          widget.onRetry!();
                          _dismiss();
                        },
                        child: const Text(
                          '重试',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    if (widget.dismissible && widget.onRetry == null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _dismiss,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
