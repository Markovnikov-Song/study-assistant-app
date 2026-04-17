// Learning OS — MCP 接入层 Dart 模型
// Flutter 端不直接连接 MCP，通过后端 HTTP API 间接调用。
// 此文件定义工具引用解析和连接状态枚举。

/// MCP 整体连接状态，对应后端 MCPConnectionState。
/// 用于 UI 层状态指示器（需求 3.5）。
enum MCPConnectionState {
  /// 所有服务器（含远程）均已连接
  allOnline,

  /// 仅本地服务器可用，远程服务器不可用
  localOnly,

  /// 全部不可用
  offline,
}

extension MCPConnectionStateX on MCPConnectionState {
  /// 从后端返回的字符串解析
  static MCPConnectionState fromString(String value) {
    switch (value) {
      case 'all_online':
        return MCPConnectionState.allOnline;
      case 'local_only':
        return MCPConnectionState.localOnly;
      case 'offline':
      default:
        return MCPConnectionState.offline;
    }
  }

  /// 用户友好的状态描述
  String get label {
    switch (this) {
      case MCPConnectionState.allOnline:
        return '全部在线';
      case MCPConnectionState.localOnly:
        return '仅本地';
      case MCPConnectionState.offline:
        return '离线模式';
    }
  }
}

/// MCP 工具引用解析器。
///
/// 工具引用格式：{server_id}.{tool_name}，如 "filesystem.read_file"。
/// Component 引用格式：无点号，如 "notebook"。
///
/// 用于 AgentKernelImpl 在 dispatchSkill 时区分两种调用路径（需求 4.2、4.3）。
class MCPToolRef {
  final String serverId;
  final String toolName;

  const MCPToolRef({required this.serverId, required this.toolName});

  /// 全局引用名，格式为 "{serverId}.{toolName}"
  String get globalRef => '$serverId.$toolName';

  /// 从 "{server_id}.{tool_name}" 格式解析。
  /// 格式不合法时抛出 [FormatException]。
  factory MCPToolRef.fromString(String ref) {
    final dotIndex = ref.indexOf('.');
    if (dotIndex <= 0 || dotIndex == ref.length - 1) {
      throw FormatException(
        'MCP 工具引用格式错误：期望 "{server_id}.{tool_name}"，实际为 "$ref"',
      );
    }
    return MCPToolRef(
      serverId: ref.substring(0, dotIndex),
      toolName: ref.substring(dotIndex + 1),
    );
  }

  /// 判断一个 requiredComponents 条目是否为 MCP 工具引用（含点号）。
  ///
  /// 用法：
  /// ```dart
  /// for (final ref in skill.requiredComponents) {
  ///   if (MCPToolRef.isMCPRef(ref)) {
  ///     // 走 MCP_Client 路径
  ///   } else {
  ///     // 走 ComponentRegistry 路径
  ///   }
  /// }
  /// ```
  static bool isMCPRef(String ref) => ref.contains('.');

  @override
  String toString() => globalRef;

  @override
  bool operator ==(Object other) =>
      other is MCPToolRef &&
      other.serverId == serverId &&
      other.toolName == toolName;

  @override
  int get hashCode => Object.hash(serverId, toolName);
}

/// MCP 工具调用结果，对应后端 MCPToolResult。
class MCPToolResult {
  final bool success;
  final Map<String, dynamic> data;
  final String? errorMessage;
  final bool fallbackTriggered;
  final bool degraded;

  const MCPToolResult({
    required this.success,
    this.data = const {},
    this.errorMessage,
    this.fallbackTriggered = false,
    this.degraded = false,
  });

  factory MCPToolResult.fromJson(Map<String, dynamic> json) {
    return MCPToolResult(
      success: json['success'] as bool? ?? false,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      errorMessage: json['error_message'] as String?,
      fallbackTriggered: json['fallback_triggered'] as bool? ?? false,
      degraded: json['degraded'] as bool? ?? false,
    );
  }
}

/// MCP 连接状态摘要，对应后端 MCPConnectionSummary。
class MCPConnectionSummary {
  final MCPConnectionState state;
  final List<String> connectedServers;
  final List<String> failedServers;
  final int totalTools;

  const MCPConnectionSummary({
    required this.state,
    this.connectedServers = const [],
    this.failedServers = const [],
    this.totalTools = 0,
  });

  factory MCPConnectionSummary.fromJson(Map<String, dynamic> json) {
    return MCPConnectionSummary(
      state: MCPConnectionStateX.fromString(json['state'] as String? ?? 'offline'),
      connectedServers: List<String>.from(json['connected_servers'] ?? []),
      failedServers: List<String>.from(json['failed_servers'] ?? []),
      totalTools: json['total_tools'] as int? ?? 0,
    );
  }

  /// 离线状态的默认值，用于网络不可用时的降级展示
  static const MCPConnectionSummary offline = MCPConnectionSummary(
    state: MCPConnectionState.offline,
  );
}
