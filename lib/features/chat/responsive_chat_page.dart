import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/device_info.dart';
import '../../models/subject.dart';
import '../../providers/subject_provider.dart';
import '../../providers/chat_provider.dart';
import 'chat_page.dart';

/// 响应式 ChatPage - 移动端单栏，桌面端分栏布局
class ResponsiveChatPage extends StatelessWidget {
  final String? chatId;
  final int? subjectId;
  final String? taskId;

  const ResponsiveChatPage({
    super.key,
    this.chatId,
    this.subjectId,
    this.taskId,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = DeviceInfo.isLargeScreen;

    if (isDesktop) {
      return _DesktopChatPage(
        chatId: chatId,
        subjectId: subjectId,
        taskId: taskId,
      );
    }

    return ChatPage(
      chatId: chatId,
      subjectId: subjectId,
      taskId: taskId,
    );
  }
}

/// 桌面端 ChatPage - 左侧会话列表 + 右侧聊天区
class _DesktopChatPage extends ConsumerStatefulWidget {
  final String? chatId;
  final int? subjectId;
  final String? taskId;

  const _DesktopChatPage({
    this.chatId,
    this.subjectId,
    this.taskId,
  });

  @override
  ConsumerState<_DesktopChatPage> createState() => _DesktopChatPageState();
}

class _DesktopChatPageState extends ConsumerState<_DesktopChatPage> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth > 1400 ? 320.0 : 280.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Row(
        children: [
          // 左侧边栏 - 会话列表
          Container(
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
            ),
            child: _ChatSidebar(
              subjectId: widget.subjectId,
            ),
          ),
          // 右侧主聊天区
          Expanded(
            child: ChatPage(
              chatId: widget.chatId,
              subjectId: widget.subjectId,
              taskId: widget.taskId,
            ),
          ),
        ],
      ),
    );
  }
}

/// 桌面端会话列表侧边栏
class _ChatSidebar extends ConsumerWidget {
  final int? subjectId;

  const _ChatSidebar({this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    // 如果有学科ID，显示学科会话；否则显示通用会话（subjectId=0 表示通用）
    final sessionsAsync = ref.watch(sessionsProvider(subjectId ?? 0));

    String title = '答疑室';
    if (subjectId != null) {
      final subjectsAsync = ref.watch(subjectsProvider);
      title = subjectsAsync.valueOrNull
              ?.firstWhere(
                (s) => s.id == subjectId,
                orElse: () => Subject(id: 0, name: '学科对话', createdAt: DateTime.now()),
              )
              .name ?? '学科对话';
    }

    return Column(
      children: [
        // 标题栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: cs.outline,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.add, color: cs.primary),
                onPressed: () {
                  // 清空当前通用对话，开始新会话
                  ref.read(chatProvider(('general', 'qa')).notifier).newSession();
                },
                tooltip: '新建会话',
              ),
            ],
          ),
        ),
        // 搜索栏
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索会话...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
        ),
        // 会话列表
        Expanded(
          child: sessionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (sessions) {
              if (sessions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: cs.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '暂无会话',
                        style: TextStyle(color: cs.outline),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return _SessionTile(
                    title: session.title ?? '新对话',
                    updatedAt: session.createdAt,
                    isDark: isDark,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 会话列表项
class _SessionTile extends StatelessWidget {
  final String title;
  final DateTime updatedAt;
  final bool isDark;

  const _SessionTile({
    required this.title,
    required this.updatedAt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(updatedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}

// 导入需要的 Provider（已移至文件顶部）
