import 'package:flutter/material.dart';

class NoSubjectHint extends StatelessWidget {
  const NoSubjectHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          const Text('请先在顶部选择或新建学科', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}
