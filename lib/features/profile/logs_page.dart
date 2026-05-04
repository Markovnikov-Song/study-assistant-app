import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/error_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late List<ErrorLog> _logs;
  ErrorLevel? _filterLevel;

  @override
  void initState() {
    super.initState();
    _logs = ErrorService.instance.getLogs();
  }

  void _refresh() {
    setState(() {
      _logs = ErrorService.instance.getLogs();
    });
  }

  void _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空所有日志吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ErrorService.instance.clearLogs();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已清空')),
        );
      }
    }
  }

  void _shareLogs() {
    final logs = ErrorService.instance.exportLogs();
    Share.share(
      logs,
      subject: 'App Logs',
    );
  }

  void _copyLog(ErrorLog log) {
    Clipboard.setData(ClipboardData(text: log.message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制')),
    );
  }

  void _showLogDetail(ErrorLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _levelBadge(log.level),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.message,
                      style: Theme.of(ctx).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (log.context != null) ...[
                const Text('上下文:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(log.context!),
                const SizedBox(height: 12),
              ],
              if (log.endpoint != null) ...[
                const Text('接口:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(log.endpoint!),
                const SizedBox(height: 12),
              ],
              if (log.statusCode != null) ...[
                const Text('状态码:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${log.statusCode}'),
                const SizedBox(height: 12),
              ],
              if (log.stackTrace != null) ...[
                const Text('堆栈:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      log.stackTrace!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: log.toJson().toString(),
                        ));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制')),
                        );
                      },
                      child: const Text('复制详情'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('关闭'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelBadge(ErrorLevel level) {
    final color = switch (level) {
      ErrorLevel.debug => Colors.blue,
      ErrorLevel.info => Colors.green,
      ErrorLevel.warning => Colors.orange,
      ErrorLevel.error => Colors.red,
      ErrorLevel.critical => Colors.purple,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLogItem(ErrorLog log) {
    return ListTile(
      leading: _levelBadge(log.level),
      title: Text(
        log.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (log.endpoint != null)
            Text(
              log.endpoint!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: () => _showLogDetail(log),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () => _copyLog(log),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filterLevel != null
        ? _logs.where((log) => log.level == _filterLevel).toList()
        : _logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('系统日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // 过滤栏
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _filterLevel == null,
                  onSelected: (_) => setState(() => _filterLevel = null),
                ),
                const SizedBox(width: 8),
                for (final level in ErrorLevel.values)
                  FilterChip(
                    label: Text(level.name),
                    selected: _filterLevel == level,
                    onSelected: (_) => setState(() => _filterLevel = level),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredLogs.isEmpty
                ? const Center(child: Text('暂无日志'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredLogs.length,
                    itemBuilder: (_, i) => _buildLogItem(filteredLogs[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
