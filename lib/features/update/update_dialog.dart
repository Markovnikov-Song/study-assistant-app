// ─────────────────────────────────────────────────────────────
// update_dialog.dart — 应用更新弹窗
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../services/update_service.dart';

/// 显示更新弹窗
/// [isForced] 为 true 时不可跳过
Future<void> showUpdateDialog(
  BuildContext context,
  AppVersionInfo info, {
  required bool isForced,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false, // 点背景不关闭，由按钮控制
    builder: (ctx) => _UpdateDialog(info: info, isForced: isForced),
  );
}

class _UpdateDialog extends StatefulWidget {
  final AppVersionInfo info;
  final bool isForced;

  const _UpdateDialog({required this.info, required this.isForced});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _errorMessage = null;
    });

    try {
      await UpdateService.instance.downloadAndInstall(
        widget.info.downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // 安装界面已弹出，关闭弹窗
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _errorMessage = '下载失败，请检查网络后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      // 强制更新时禁用返回键
      canPop: !widget.isForced && !_downloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.isForced ? '需要更新' : '发现新版本',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'v${widget.info.latestVersion}',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.info.changelog.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.info.changelog,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (widget.isForced) ...[
              const SizedBox(height: 8),
              Text(
                '当前版本已停止支持，请更新后继续使用。',
                style: TextStyle(fontSize: 13, color: colorScheme.error),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Text(
                _progress > 0
                    ? '下载中 ${(_progress * 100).toStringAsFixed(0)}%'
                    : '准备下载...',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(fontSize: 13, color: colorScheme.error),
              ),
            ],
          ],
        ),
        actions: _downloading
            ? null // 下载中隐藏按钮
            : [
                if (!widget.isForced)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('稍后再说'),
                  ),
                FilledButton(
                  onPressed: _startDownload,
                  child: Text(_errorMessage != null ? '重试' : '立即更新'),
                ),
              ],
      ),
    );
  }
}
