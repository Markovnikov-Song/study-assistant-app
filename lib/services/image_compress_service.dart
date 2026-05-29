import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 图片压缩与 Base64 转换服务。
///
/// 核心设计：仅限制长边，保持原始宽高比，防止公式图片变形。
/// Web 平台不支持 flutter_image_compress，直接返回原始 Base64（跳过压缩）。
class ImageCompressService {
  /// 压缩多张图片并返回 Base64 字符串列表。
  ///
  /// - [images]：待压缩的图片文件列表
  /// - [maxLongEdge]：长边最大像素（默认 1920px）
  /// - [quality]：JPEG 压缩质量 0-100（默认 75）
  ///
  /// 返回每张图片压缩后的 Base64 字符串（不含 data URI 前缀）。
  /// Web 平台跳过压缩，直接返回原始 Base64。
  static Future<List<String>> compressToBase64List(
    List<XFile> images, {
    int maxLongEdge = 1280,
    int quality = 70,
  }) async {
    final results = <String>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();

      // Web 平台：flutter_image_compress 不支持，直接返回原始 Base64
      if (kIsWeb) {
        results.add(base64Encode(bytes));
        continue;
      }

      // 读取原图尺寸，计算等比缩放后的目标尺寸
      // 仅将长边限制在 maxLongEdge，短边按比例缩放，防止公式图片变形
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final origWidth = frame.image.width;
      final origHeight = frame.image.height;
      frame.image.dispose();

      int targetWidth = origWidth;
      int targetHeight = origHeight;
      final longEdge = origWidth > origHeight ? origWidth : origHeight;

      if (longEdge > maxLongEdge) {
        final scale = maxLongEdge / longEdge;
        targetWidth = (origWidth * scale).round();
        targetHeight = (origHeight * scale).round();
        // 确保最小为 1px
        if (targetWidth < 1) targetWidth = 1;
        if (targetHeight < 1) targetHeight = 1;
      }

      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      results.add(base64Encode(compressed));
    }
    return results;
  }

  /// 压缩单张图片并返回 Base64 字符串。
  static Future<String> compressToBase64(
    XFile image, {
    int maxLongEdge = 1280,
    int quality = 70,
  }) async {
    final list = await compressToBase64List(
      [image],
      maxLongEdge: maxLongEdge,
      quality: quality,
    );
    return list.first;
  }
}
