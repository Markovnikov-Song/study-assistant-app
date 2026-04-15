import 'package:flutter/material.dart';

/// 文具盒：工具集合页（番茄钟、背单词、课表等，后续扩展）
class StationeryPage extends StatelessWidget {
  const StationeryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文具盒')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('更多工具即将上线',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 8),
            Text('番茄钟、背单词、课表…',
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
