import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../services/incident_report_service.dart';

/// 用于截图的 [RepaintBoundary] key（在 [MaterialApp.builder] 中绑定）。
class IncidentCapture {
  IncidentCapture._();
  static final GlobalKey boundaryKey = GlobalKey();

  static Future<Uint8List?> capturePng() async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

/// 右下角反馈按钮（登录后显示）。
class IncidentFeedbackFab extends ConsumerStatefulWidget {
  const IncidentFeedbackFab({super.key});

  @override
  ConsumerState<IncidentFeedbackFab> createState() =>
      _IncidentFeedbackFabState();
}

class _IncidentFeedbackFabState extends ConsumerState<IncidentFeedbackFab> {
  bool _submitting = false;

  String? _route(BuildContext context) {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit(BuildContext context) async {
    final route = _route(context) ?? '';
    final descCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    String? description;
    String? contact;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('提交问题反馈', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '将自动附带：当前页面截图、路由、最近错误日志、版本与设备信息',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text('页面', style: Theme.of(ctx).textTheme.labelSmall),
            Text(route, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: '问题描述（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactCtrl,
              decoration: const InputDecoration(
                labelText: '联系方式（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                description = descCtrl.text;
                contact = contactCtrl.text;
                Navigator.pop(ctx, true);
              },
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
    descCtrl.dispose();
    contactCtrl.dispose();
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final shot = await IncidentCapture.capturePng();
      final result = await IncidentReportService.instance.submit(
        route: route,
        description: description,
        contact: contact,
        screenshot: shot,
      );
      final id = (result['incident'] as Map?)?['id'];
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(id != null ? '已提交 #$id' : '提交成功')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('提交失败: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final route = _route(context);
    if (!auth.isAuthenticated ||
        auth.isRestoring ||
        !IncidentReportService.instance.shouldShowFab(route)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 10,
      bottom: 88,
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 4),
        child: Material(
          elevation: 3,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _submitting ? null : () => _submit(context),
            child: SizedBox(
              width: 40,
              height: 40,
              child: _submitting
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.bug_report_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
