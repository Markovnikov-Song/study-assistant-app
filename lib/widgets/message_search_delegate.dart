import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/current_subject_provider.dart';
import '../providers/subject_provider.dart';
import '../routes/app_router.dart';
import '../services/history_service.dart';

class MessageSearchDelegate extends SearchDelegate<void> {
  final WidgetRef _ref;
  List<MessageSearchResult> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  MessageSearchDelegate(this._ref);

  @override
  String get searchFieldLabel => '搜索聊天记录…';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () { query = ''; showSuggestions(context); },
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('输入关键词搜索聊天记录', style: TextStyle(color: Colors.grey)));
    }
    if (query != _lastQuery) {
      _lastQuery = query;
      _doSearch(context);
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return const Center(child: Text('没有找到相关记录', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _SearchResultTile(
        result: _results[i],
        query: query,
        onTap: () => _openResult(context, _results[i]),
      ),
    );
  }

  Future<void> _doSearch(BuildContext context) async {
    _loading = true;
    showSuggestions(context);
    try {
      _results = await HistoryService().searchMessages(query.trim());
    } catch (_) {
      _results = [];
    } finally {
      _loading = false;
      // showSuggestions triggers a rebuild of the search delegate UI
      if (context.mounted) showSuggestions(context);
    }
  }

  Future<void> _openResult(BuildContext context, MessageSearchResult result) async {
    close(context, null);

    if (result.subjectId != null) {
      final subjects = _ref.read(subjectsProvider).valueOrNull ?? [];
      final subject = subjects.where((s) => s.id == result.subjectId).firstOrNull;
      if (subject != null) _ref.read(currentSubjectProvider.notifier).state = subject;
    }

    if (result.subjectId != null &&
        (result.sessionType == SessionType.qa || result.sessionType == SessionType.solve)) {
      final key = (result.subjectId!, result.sessionType.name);
      await _ref.read(chatProvider(key).notifier).loadSession(result.sessionId);
    }

    if (!context.mounted) return;
    context.go(switch (result.sessionType) {
      SessionType.solve   => AppRoutes.solve,
      SessionType.mindmap => AppRoutes.mindmap,
      SessionType.exam    => AppRoutes.quiz,
      _                   => AppRoutes.chat,
    });
  }
}

class _SearchResultTile extends StatelessWidget {
  final MessageSearchResult result;
  final String query;
  final VoidCallback onTap;
  const _SearchResultTile({required this.result, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Text(result.typeLabel, style: const TextStyle(fontSize: 20)),
      title: Text(result.sessionTitle ?? '未命名对话',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HighlightText(text: result.snippet, query: query, baseStyle: const TextStyle(fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            '${result.subjectName != null ? '${result.subjectName!} · ' : ''}'
            '${result.role == 'user' ? '我' : 'AI'} · '
            '${result.createdAt.month}月${result.createdAt.day}日',
            style: TextStyle(fontSize: 11, color: cs.outline),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  const _HighlightText({required this.text, required this.query, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: baseStyle, maxLines: 2, overflow: TextOverflow.ellipsis);
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(lowerQ, start);
      if (idx == -1) { spans.add(TextSpan(text: text.substring(start), style: baseStyle)); break; }
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: baseStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
      ));
      start = idx + query.length;
    }
    return RichText(text: TextSpan(children: spans), maxLines: 2, overflow: TextOverflow.ellipsis);
  }
}
