import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/notebook.dart';
import '../../../routes/app_router.dart';

class NotebookCard extends StatelessWidget {
  const NotebookCard({
    super.key,
    required this.notebook,
    this.onPin,
    this.onArchive,
    this.onDelete,
  });

  final Notebook notebook;

  /// 置顶 / 取消置顶回调
  final VoidCallback? onPin;

  /// 归档 / 取消归档回调
  final VoidCallback? onArchive;

  /// 删除回调（仅用户自定义本可用）
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.notebookDetail(notebook.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 图标：系统预设本用 📌，用户自定义本用 📓
              Text(
                notebook.isSystem ? '📌' : '📓',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              // 笔记本名称
              Expanded(
                child: Text(
                  notebook.name,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // "⋯" 菜单
              PopupMenuButton<_MenuAction>(
                icon: Icon(Icons.more_horiz, color: colorScheme.onSurfaceVariant),
                onSelected: (action) {
                  switch (action) {
                    case _MenuAction.pin:
                      onPin?.call();
                    case _MenuAction.archive:
                      onArchive?.call();
                    case _MenuAction.delete:
                      onDelete?.call();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _MenuAction.pin,
                    child: Text(notebook.isPinned ? '取消置顶' : '置顶'),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.archive,
                    child: Text(notebook.isArchived ? '取消归档' : '归档'),
                  ),
                  // 仅用户自定义本显示删除选项（需求 1.3, 1.5）
                  if (!notebook.isSystem)
                    const PopupMenuItem(
                      value: _MenuAction.delete,
                      child: Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { pin, archive, delete }
