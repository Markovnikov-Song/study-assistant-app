import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';

Future<void> showAvatarPicker(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('拍照'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('从相册选择'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  if (source == null) return;
  if (!context.mounted) return;

  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 512,
    maxHeight: 512,
  );

  if (file == null) return;
  if (!context.mounted) return;

  final bytes = await file.readAsBytes();

  const maxSize = 5 * 1024 * 1024;
  if (bytes.length > maxSize) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('图片过大，请选择小于 5MB 的图片')),
    );
    return;
  }

  try {
    final user = await ProfileService().uploadAvatar(bytes);
    if (!context.mounted) return;
    ref.read(authProvider.notifier).updateAvatar(user.avatarBase64!);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('头像上传失败，请稍后重试')),
    );
  }
}
