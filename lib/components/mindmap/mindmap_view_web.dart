// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

int _viewIdCounter = 0;

Widget buildMindMapView(String htmlContent, {void Function(dynamic)? onController}) {
  final viewId = 'mindmap-iframe-$_viewIdCounter';

  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = html.IFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..srcdoc = htmlContent;
    return iframe;
  });

  return HtmlElementView(viewType: viewId);
}

Future<void> saveMindMapImage(BuildContext context, dynamic ctrl) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Web 端暂不支持保存图片')),
  );
}
