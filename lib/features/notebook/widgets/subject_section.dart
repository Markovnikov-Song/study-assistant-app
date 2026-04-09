import 'package:flutter/material.dart';
import '../../../models/notebook.dart';
import 'note_card.dart';

class SubjectSection extends StatelessWidget {
  final String? subjectName;
  final List<Note> notes;
  final int notebookId;

  const SubjectSection({
    super.key,
    required this.subjectName,
    required this.notes,
    required this.notebookId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = subjectName ?? '通用';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '暂无笔记',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          )
        else
          ...notes.map(
            (note) => NoteCard(note: note, notebookId: notebookId),
          ),
      ],
    );
  }
}
