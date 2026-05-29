import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subject_bar.dart';

class NoSubjectHint extends ConsumerWidget {
  const NoSubjectHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 96, color: cs.outlineVariant),
            const SizedBox(height: 24),
            Text(
              '选择或新建科目',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '选择一个科目后即可使用当前功能',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SubjectPickerSheet(),
              ),
              icon: const Icon(Icons.book_outlined),
              label: const Text('选择科目'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 52),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const CreateSubjectSheet(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('新建科目'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 52),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
