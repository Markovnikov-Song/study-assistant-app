import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:webview_flutter/webview_flutter.dart';

Widget buildMindMapView(String htmlContent) {
  final ctrl = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.white)
    ..loadHtmlString(htmlContent);
  return WebViewWidget(controller: ctrl);
}

Future<void> saveMindMapImage(BuildContext context, dynamic ctrl) async {
  if (ctrl is! WebViewController) return;
  try {
    final result = await ctrl.runJavaScriptReturningResult('''
(function() {
  return new Promise((resolve) => {
    const svg = document.querySelector('#mindmap');
    if (!svg) { resolve(''); return; }
    const bbox = svg.getBBox();
    const padding = 24;
    const w = Math.ceil(bbox.width + padding * 2);
    const h = Math.ceil(bbox.height + padding * 2);
    const clone = svg.cloneNode(true);
    clone.setAttribute('width', w);
    clone.setAttribute('height', h);
    clone.setAttribute('viewBox', (bbox.x - padding) + ' ' + (bbox.y - padding) + ' ' + w + ' ' + h);
    const xml = new XMLSerializer().serializeToString(clone);
    const img = new Image();
    img.onload = function() {
      const canvas = document.createElement('canvas');
      canvas.width = w * 2; canvas.height = h * 2;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.scale(2, 2);
      ctx.drawImage(img, 0, 0);
      resolve(canvas.toDataURL('image/png'));
    };
    img.onerror = () => resolve('');
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(xml);
  });
})()
''');
    final dataUrl = result.toString().replaceAll('"', '');
    if (dataUrl.isEmpty || !dataUrl.startsWith('data:image/png')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('截图失败，请稍后重试')));
      }
      return;
    }
    final bytes = base64Decode(dataUrl.split(',').last);
    await Gal.putImageBytes(bytes,
        name: 'mindmap_${DateTime.now().millisecondsSinceEpoch}');
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存到相册')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }
}
