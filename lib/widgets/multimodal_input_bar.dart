import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_compress_service.dart';

/// 多模态输入栏组件。
///
/// 支持：
/// - 拍照 / 图库两个图片选取入口
/// - 最多 4 张图片，选取后在输入框上方横向滚动展示缩略图
/// - 每张缩略图右上角有 × 删除按钮
/// - 发送按钮：无图片且文字为空时禁用
/// - 发送时压缩图片并通过 [onSend] 回调传出 payload
/// - 发送成功后清除缩略图和输入框
class MultimodalInputBar extends StatefulWidget {
  /// 发送回调，payload 格式：
  /// ```json
  /// {"text": "...", "images": ["base64..."], "supplement_text": "..."}
  /// ```
  final void Function(Map<String, dynamic> payload) onSend;

  /// 外部传入的文字控制器（可选）；若不传则内部自建
  final TextEditingController? controller;

  /// 输入框占位文字
  final String hintText;

  /// 是否正在发送中（禁用输入）
  final bool isSending;

  const MultimodalInputBar({
    super.key,
    required this.onSend,
    this.controller,
    this.hintText = '输入补充说明（可选）',
    this.isSending = false,
  });

  @override
  State<MultimodalInputBar> createState() => _MultimodalInputBarState();
}

class _MultimodalInputBarState extends State<MultimodalInputBar> {
  /// 已选图片列表，上限 4 张
  final List<XFile> _selectedImages = [];

  /// 图片选取器
  final ImagePicker _picker = ImagePicker();

  /// 内部文字控制器（当外部未传入时使用）
  late final TextEditingController _internalController;

  /// 实际使用的文字控制器
  TextEditingController get _controller =>
      widget.controller ?? _internalController;

  /// 最大图片数量
  static const int _maxImages = 4;
  static const double _pickMaxDimension = 1600;
  static const int _pickImageQuality = 82;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    // 仅在内部创建时才 dispose
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  // ── 图片选取 ──────────────────────────────────────────────────────────────

  /// 从相机拍照
  Future<void> _pickFromCamera() async {
    if (_selectedImages.length >= _maxImages) {
      _showMaxImagesHint();
      return;
    }
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _pickMaxDimension,
      maxHeight: _pickMaxDimension,
      imageQuality: _pickImageQuality,
    );
    if (photo != null) {
      setState(() => _selectedImages.add(photo));
    }
  }

  /// 从图库选取（支持多选）
  Future<void> _pickFromGallery() async {
    if (_selectedImages.length >= _maxImages) {
      _showMaxImagesHint();
      return;
    }
    final remaining = _maxImages - _selectedImages.length;
    final List<XFile> picked = await _picker.pickMultiImage(
      limit: remaining,
      maxWidth: _pickMaxDimension,
      maxHeight: _pickMaxDimension,
      imageQuality: _pickImageQuality,
    );
    if (picked.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(picked.take(remaining));
      });
    }
  }

  /// 提示已达上限
  void _showMaxImagesHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('最多只能选 $_maxImages 张图片')));
  }

  /// 删除指定索引的图片
  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ── 发送逻辑 ──────────────────────────────────────────────────────────────

  /// 发送按钮是否可用
  bool get _canSend =>
      !widget.isSending &&
      (_selectedImages.isNotEmpty || _controller.text.trim().isNotEmpty);

  Future<void> _handleSend() async {
    if (!_canSend) return;

    // 快照当前状态，防止异步过程中状态变化
    final List<XFile> imagesToSend = List.from(_selectedImages);
    final String text = _controller.text.trim();

    // 逐张压缩，失败时 SnackBar 提示并保留其他图片
    final List<String> base64List = [];
    final List<XFile> failedImages = [];

    for (final image in imagesToSend) {
      try {
        final results = await ImageCompressService.compressToBase64List([
          image,
        ]);
        if (results.isNotEmpty && results.first.isNotEmpty) {
          base64List.add(results.first);
        } else {
          failedImages.add(image);
        }
      } catch (_) {
        failedImages.add(image);
      }
    }

    // 有图片处理失败时提示，并从已选列表中移除失败项
    if (failedImages.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${failedImages.length} 张图片处理失败，已跳过')),
      );
      setState(() {
        for (final f in failedImages) {
          _selectedImages.remove(f);
        }
      });
      // 若全部失败且无文字，则不发送
      if (base64List.isEmpty && text.isEmpty) return;
    }

    // 安全检查：images 和 text 至少有一个非空才发送（防止空请求导致后端 400）
    if (base64List.isEmpty && text.isEmpty) return;

    // 组装 payload
    final Map<String, dynamic> payload = {
      'text': text,
      'images': base64List,
      'supplement_text': text,
    };

    // 发送成功后清除状态
    setState(() => _selectedImages.clear());
    _controller.clear();

    widget.onSend(payload);
  }

  // ── 构建 UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 缩略图预览区（有图片时显示）
              if (_selectedImages.isNotEmpty) _buildThumbnailRow(cs),

              // 输入行
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 拍照按钮
                  _buildIconButton(
                    icon: Icons.camera_alt_outlined,
                    tooltip: '拍照',
                    onPressed: widget.isSending ? null : _pickFromCamera,
                    cs: cs,
                  ),
                  // 图库按钮
                  _buildIconButton(
                    icon: Icons.photo_library_outlined,
                    tooltip: '图库',
                    onPressed: widget.isSending ? null : _pickFromGallery,
                    cs: cs,
                  ),
                  const SizedBox(width: 4),
                  // 文字输入框
                  Expanded(child: _buildTextField(cs)),
                  const SizedBox(width: 4),
                  // 发送按钮
                  _buildSendButton(cs),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 横向滚动缩略图列表
  Widget _buildThumbnailRow(ColorScheme cs) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: _selectedImages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _buildThumbnailItem(index, cs),
      ),
    );
  }

  /// 单张缩略图（含右上角删除按钮）
  Widget _buildThumbnailItem(int index, ColorScheme cs) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 图片缩略图
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_selectedImages[index].path),
            width: 68,
            height: 68,
            fit: BoxFit.cover,
          ),
        ),
        // 右上角删除按钮
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: cs.error,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 13, color: cs.onError),
            ),
          ),
        ),
      ],
    );
  }

  /// 图标按钮（拍照 / 图库）
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required ColorScheme cs,
  }) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      color: onPressed == null
          ? cs.onSurface.withValues(alpha: 0.38)
          : cs.onSurfaceVariant,
      iconSize: 24,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 文字输入框
  Widget _buildTextField(ColorScheme cs) {
    return TextField(
      controller: _controller,
      enabled: !widget.isSending,
      maxLines: 4,
      minLines: 1,
      textInputAction: TextInputAction.newline,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.45)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        filled: true,
        fillColor: cs.surfaceContainerLow,
        isDense: true,
      ),
    );
  }

  /// 发送按钮
  Widget _buildSendButton(ColorScheme cs) {
    return AnimatedOpacity(
      opacity: _canSend ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 150),
      child: IconButton(
        icon: widget.isSending
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(Icons.send_rounded, color: cs.primary),
        onPressed: _canSend ? _handleSend : null,
        tooltip: '发送',
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
