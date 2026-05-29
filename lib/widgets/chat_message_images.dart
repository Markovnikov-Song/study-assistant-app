import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';

import '../providers/solve_prefill_provider.dart';
import '../routes/app_router.dart';

/// 聊天气泡内展示用户附带的 Base64 图片（拍照搜题等）。
class ChatMessageImages extends StatelessWidget {
  final List<String> images;
  final double maxWidth;
  final double maxHeight;

  const ChatMessageImages({
    super.key,
    required this.images,
    this.maxWidth = 220,
    this.maxHeight = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return _Thumbnail(
        base64: images.first,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        onTap: () => _openPreview(context, images.first),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _Thumbnail(
          base64: images[index],
          maxWidth: 96,
          maxHeight: 96,
          onTap: () => _openPreview(context, images[index]),
        ),
      ),
    );
  }

  void _openPreview(BuildContext context, String base64) {
    final bytes = _decode(base64);
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ImagePreviewPage(bytes: bytes),
        fullscreenDialog: true,
      ),
    );
  }
}

class _ImagePreviewPage extends StatelessWidget {
  final Uint8List bytes;

  const _ImagePreviewPage({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片'),
        actions: [
          IconButton(
            onPressed: () => _save(context),
            icon: const Icon(Icons.save_alt_rounded),
            tooltip: '保存',
          ),
          IconButton(
            onPressed: () => _sendToSolve(context),
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: '去解题页编辑',
          ),
        ],
      ),
      body: PhotoView(
        imageProvider: MemoryImage(bytes),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Web 端暂不支持保存到相册')));
      return;
    }

    try {
      await Gal.putImageBytes(
        bytes,
        name: 'study_image_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存到相册')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请检查相册权限')));
    }
  }

  void _sendToSolve(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(solveImagePreFillProvider.notifier).state = [
      base64Encode(bytes),
    ];
    context.push(R.toolkitSolve);
  }
}

class _Thumbnail extends StatelessWidget {
  final String base64;
  final double maxWidth;
  final double maxHeight;
  final VoidCallback? onTap;

  const _Thumbnail({
    required this.base64,
    required this.maxWidth,
    required this.maxHeight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(base64);
    final cs = Theme.of(context).colorScheme;

    Widget child;
    if (bytes == null) {
      child = Container(
        width: maxWidth,
        height: maxHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
      );
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          width: maxWidth,
          height: maxHeight,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
        ),
      );
    }

    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

Uint8List? _decode(String raw) {
  try {
    final data = raw.contains(',') ? raw.split(',').last : raw;
    return base64Decode(data.trim());
  } catch (_) {
    return null;
  }
}
