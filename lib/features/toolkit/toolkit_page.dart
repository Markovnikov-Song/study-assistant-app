import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 所有工具可用的图标名称 → IconData 映射（常量，tree-shaking 安全）
const Map<String, IconData> kToolIconMap = {
  'error_outline_rounded': Icons.error_outline_rounded,
  'error_rounded': Icons.error_rounded,
  'warning_amber_outlined': Icons.warning_amber_outlined,
  'update_outlined': Icons.update_outlined,
  'replay_outlined': Icons.replay_outlined,
  'refresh_outlined': Icons.refresh_outlined,
  'note_alt_outlined': Icons.note_alt_outlined,
  'note_alt_rounded': Icons.note_alt_rounded,
  'sticky_note_2_outlined': Icons.sticky_note_2_outlined,
  'book_outlined': Icons.book_outlined,
  'auto_stories_outlined': Icons.auto_stories_outlined,
  'edit_note_outlined': Icons.edit_note_outlined,
  'calculate_outlined': Icons.calculate_outlined,
  'calculate_rounded': Icons.calculate_rounded,
  'functions': Icons.functions,
  'analytics_outlined': Icons.analytics_outlined,
  'numbers': Icons.numbers,
  'quick_contacts_dialer_outlined': Icons.quick_contacts_dialer_outlined,
  'quiz_outlined': Icons.quiz_outlined,
  'quiz_rounded': Icons.quiz_rounded,
  'help_outline_rounded': Icons.help_outline_rounded,
  'extension_outlined': Icons.extension_outlined,
  'psychology_outlined': Icons.psychology_outlined,
  'lightbulb_outline_rounded': Icons.lightbulb_outline_rounded,
  'account_tree_outlined': Icons.account_tree_outlined,
  'account_tree_rounded': Icons.account_tree_rounded,
  'hub_outlined': Icons.hub_outlined,
  'device_hub_outlined': Icons.device_hub_outlined,
  'bubble_chart_outlined': Icons.bubble_chart_outlined,
  'auto_awesome_outlined': Icons.auto_awesome_outlined,
  'auto_awesome_rounded': Icons.auto_awesome_rounded,
  'star_outline_rounded': Icons.star_outline_rounded,
  'auto_fix_high_outlined': Icons.auto_fix_high_outlined,
  'tips_and_updates_outlined': Icons.tips_and_updates_outlined,
  'calendar_today_outlined': Icons.calendar_today_outlined,
  'calendar_today_rounded': Icons.calendar_today_rounded,
  'calendar_month_outlined': Icons.calendar_month_outlined,
  'event_note_outlined': Icons.event_note_outlined,
  'schedule_outlined': Icons.schedule_outlined,
  'edit_calendar_outlined': Icons.edit_calendar_outlined,
  'date_range_outlined': Icons.date_range_outlined,
};

/// IconData → 名称（反向查找，用于保存）
String _iconToName(IconData icon) {
  return kToolIconMap.entries
      .firstWhere((e) => e.value == icon,
          orElse: () => const MapEntry('error_outline_rounded', Icons.error_outline_rounded))
      .key;
}

/// 用户自定义的工具图标 Provider
final toolIconsProvider = StateNotifierProvider<ToolIconsNotifier, Map<String, IconData>>((ref) {
  return ToolIconsNotifier();
});

class ToolIconsNotifier extends StateNotifier<Map<String, IconData>> {
  ToolIconsNotifier() : super({}) {
    _loadSavedIcons();
  }

  Future<void> _loadSavedIcons() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('custom_tool_icons');
    if (saved != null) {
      final map = <String, IconData>{};
      for (final item in saved) {
        final parts = item.split(':');
        if (parts.length == 2) {
          final icon = kToolIconMap[parts[1]];
          if (icon != null) {
            map[parts[0]] = icon;
          }
        }
      }
      state = map;
    }
  }

  Future<void> setIcon(String toolId, IconData icon) async {
    state = {...state, toolId: icon};
    await _saveIcons();
  }

  Future<void> resetIcon(String toolId) async {
    final newState = Map<String, IconData>.from(state);
    newState.remove(toolId);
    state = newState;
    await _saveIcons();
  }

  Future<void> _saveIcons() async {
    final prefs = await SharedPreferences.getInstance();
    final list = state.entries.map((e) => '${e.key}:${_iconToName(e.value)}').toList();
    await prefs.setStringList('custom_tool_icons', list);
  }

  IconData getIcon(String toolId, IconData defaultIcon) {
    return state[toolId] ?? defaultIcon;
  }
}

/// 工具顺序管理 Provider
final toolOrderProvider = StateNotifierProvider<ToolOrderNotifier, List<String>>((ref) {
  return ToolOrderNotifier();
});

class ToolOrderNotifier extends StateNotifier<List<String>> {
  ToolOrderNotifier() : super([]) {
    _loadSavedOrder();
  }

  Future<void> _loadSavedOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('tool_order');
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    } else {
      // 使用默认顺序
      state = kDefaultTools.map((tool) => tool.id).toList();
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final newOrder = List<String>.from(state);
    // Flutter 2.0+ onReorder: newIndex 已经是移除后的正确位置，不需要调整
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);
    state = newOrder;
    await _saveOrder();
  }

  Future<void> resetToDefault() async {
    state = kDefaultTools.map((tool) => tool.id).toList();
    await _saveOrder();
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tool_order', state);
  }

  /// 根据保存的顺序获取排序后的工具列表
  List<ToolItem> getOrderedTools() {
    if (state.isEmpty) {
      return kDefaultTools;
    }
    
    final toolMap = {for (var tool in kDefaultTools) tool.id: tool};
    final orderedTools = <ToolItem>[];
    
    for (final id in state) {
      final tool = toolMap[id];
      if (tool != null) {
        orderedTools.add(tool);
      }
    }
    
    // 添加任何新工具（不在保存的顺序中）
    for (final tool in kDefaultTools) {
      if (!state.contains(tool.id)) {
        orderedTools.add(tool);
      }
    }
    
    return orderedTools;
  }
}

/// 工具项数据模型
class ToolItem {
  final String id;
  final IconData icon;
  final IconData filledIcon;
  final List<Color> gradientColors;
  final String label;
  final String description;
  final String route;
  /// 可选的图标列表（用户可切换）
  final List<IconData>? iconOptions;

  const ToolItem({
    required this.id,
    required this.icon,
    required this.filledIcon,
    required this.gradientColors,
    required this.label,
    required this.description,
    required this.route,
    this.iconOptions,
  });

  /// 获取可用的图标列表
  List<IconData> get availableIcons {
    if (iconOptions != null && iconOptions!.isNotEmpty) {
      return iconOptions!;
    }
    return [icon, filledIcon];
  }
}

/// 默认工具列表（数据驱动，扩展只需追加 ToolItem）
const List<ToolItem> kDefaultTools = [
  // 1. 解题（最常用）
  ToolItem(
    id: 'solve',
    icon: Icons.calculate_outlined,
    filledIcon: Icons.calculate_rounded,
    gradientColors: [Color(0xFF10B981), Color(0xFF34D399)],
    label: '解题',
    description: '拍照识题，AI解答',
    route: '/toolkit/solve',
    iconOptions: [
      Icons.calculate_outlined,
      Icons.calculate_rounded,
      Icons.functions,
      Icons.analytics_outlined,
      Icons.numbers,
      Icons.quick_contacts_dialer_outlined,
    ],
  ),
  // 2. 出题
  ToolItem(
    id: 'quiz',
    icon: Icons.quiz_outlined,
    filledIcon: Icons.quiz_rounded,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    label: '出题',
    description: '智能出题，检验学习',
    route: '/toolkit/quiz',
    iconOptions: [
      Icons.quiz_outlined,
      Icons.quiz_rounded,
      Icons.help_outline_rounded,
      Icons.extension_outlined,
      Icons.psychology_outlined,
      Icons.lightbulb_outline_rounded,
    ],
  ),
  // 3. 复盘中心
  ToolItem(
    id: 'mistake-book',
    icon: Icons.error_outline_rounded,
    filledIcon: Icons.error_rounded,
    gradientColors: [Color(0xFFEF4444), Color(0xFFF87171)],
    label: '复盘中心',
    description: '错题复盘，SM-2间隔复习',
    route: '/toolkit/review',
    iconOptions: [
      Icons.error_outline_rounded,
      Icons.error_rounded,
      Icons.warning_amber_outlined,
      Icons.update_outlined,
      Icons.replay_outlined,
      Icons.refresh_outlined,
    ],
  ),
  // 4. 笔记本
  ToolItem(
    id: 'notebooks',
    icon: Icons.note_alt_outlined,
    filledIcon: Icons.note_alt_rounded,
    gradientColors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    label: '笔记本',
    description: '收藏内容，整理笔记',
    route: '/toolkit/notebooks',
    iconOptions: [
      Icons.note_alt_outlined,
      Icons.note_alt_rounded,
      Icons.sticky_note_2_outlined,
      Icons.book_outlined,
      Icons.auto_stories_outlined,
      Icons.edit_note_outlined,
    ],
  ),
  // 5. 脑图工坊
  ToolItem(
    id: 'mindmap',
    icon: Icons.account_tree_outlined,
    filledIcon: Icons.account_tree_rounded,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    label: '脑图工坊',
    description: '生成思维导图',
    route: '/toolkit/mindmap-workshop',
    iconOptions: [
      Icons.account_tree_outlined,
      Icons.account_tree_rounded,
      Icons.hub_outlined,
      Icons.device_hub_outlined,
      Icons.bubble_chart_outlined,
      Icons.psychology_outlined,
    ],
  ),
  // 6. 学习日历
  ToolItem(
    id: 'calendar',
    icon: Icons.calendar_today_outlined,
    filledIcon: Icons.calendar_today_rounded,
    gradientColors: [Color(0xFF6366F1), Color(0xFF818CF8)],
    label: '学习日历',
    description: '计划、打卡、复盘，学习闭环',
    route: '/toolkit/calendar',
    iconOptions: [
      Icons.calendar_today_outlined,
      Icons.calendar_month_outlined,
      Icons.event_note_outlined,
      Icons.schedule_outlined,
      Icons.edit_calendar_outlined,
      Icons.date_range_outlined,
    ],
  ),
  // 7. 方法库
  ToolItem(
    id: 'my-skills',
    icon: Icons.auto_awesome_outlined,
    filledIcon: Icons.auto_awesome_rounded,
    gradientColors: [Color(0xFFEC4899), Color(0xFFF472B6)],
    label: '方法库',
    description: '查看并使用学习方法',
    route: '/my-skills',
    iconOptions: [
      Icons.auto_awesome_outlined,
      Icons.auto_awesome_rounded,
      Icons.star_outline_rounded,
      Icons.auto_fix_high_outlined,
      Icons.psychology_outlined,
      Icons.tips_and_updates_outlined,
    ],
  ),
];

/// 工具箱页：全新设计的卡片风格
class ToolkitPage extends ConsumerWidget {
  const ToolkitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    
    // 正确监听排序状态
    final order = ref.watch(toolOrderProvider);
    final toolMap = {for (var tool in kDefaultTools) tool.id: tool};
    final orderedTools = order
        .map((id) => toolMap[id])
        .whereType<ToolItem>()
        .toList();
    // 添加默认列表中新增的工具（向后兼容）
    for (final tool in kDefaultTools) {
      if (!order.contains(tool.id)) {
        orderedTools.add(tool);
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    // Web端限制最大宽度，保持类似手机的紧凑布局
    final contentMaxWidth = isWideScreen ? 420.0 : double.infinity;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // 主内容（SVG 背景由 ShellPage 提供）
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 80,
                    floating: true,
                    pinned: false,
                    backgroundColor: Colors.transparent,
                    actions: [
                      // 设置按钮
                      IconButton(
                        icon: Icon(Icons.settings_outlined, color: cs.onSurface),
                        onPressed: () => context.push('/toolkit/settings'),
                        tooltip: '工具排序',
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                      title: Text(
                        '工具箱',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  // 工具卡片网格（响应式，像手机桌面一样）
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 100,  // 减小，让一行能放4-5个
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ToolCard(
                          item: orderedTools[index],
                          iconSize: 48,  // 图标改小，像桌面图标
                        ),
                        childCount: orderedTools.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends ConsumerStatefulWidget {
  final ToolItem item;
  final double iconSize;

  const _ToolCard({required this.item, this.iconSize = 48});

  @override
  ConsumerState<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends ConsumerState<_ToolCard> {
  bool _isPressed = false;

  /// 长按显示功能说明和图标选择器
  void _showToolOptions() {
    if (widget.item.iconOptions == null || widget.item.iconOptions!.isEmpty) {
      return;
    }

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ToolOptionsSheet(
        item: widget.item,
        currentIcon: ref.read(toolIconsProvider.notifier).getIcon(
              widget.item.id,
              widget.item.icon,
            ),
        onSelectIcon: (icon) {
          ref.read(toolIconsProvider.notifier).setIcon(widget.item.id, icon);
        },
        onResetIcon: () {
          ref.read(toolIconsProvider.notifier).resetIcon(widget.item.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 获取用户自定义图标或默认图标
    final currentIcon = ref.watch(toolIconsProvider.notifier).getIcon(
          widget.item.id,
          widget.item.icon,
        );

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => context.push(widget.item.route),
      // 长按显示功能说明和图标选择（仅对有 iconOptions 的工具生效）
      onLongPress: widget.item.iconOptions != null ? _showToolOptions : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标（像手机桌面图标，小方块）
          Transform.scale(
            scale: _isPressed ? 0.9 : 1.0,
            child: Container(
              width: widget.iconSize,
              height: widget.iconSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.item.gradientColors,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: widget.item.gradientColors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                currentIcon,
                size: widget.iconSize * 0.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 文字（在图标下方，像手机桌面）
          SizedBox(
            width: widget.iconSize + 16,
            child: Text(
              widget.item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 工具选项底部弹窗（功能说明 + 图标选择）
class _ToolOptionsSheet extends StatelessWidget {
  final ToolItem item;
  final IconData currentIcon;
  final ValueChanged<IconData> onSelectIcon;
  final VoidCallback onResetIcon;

  const _ToolOptionsSheet({
    required this.item,
    required this.currentIcon,
    required this.onSelectIcon,
    required this.onResetIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icons = item.iconOptions!;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示条
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 功能说明区域
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  // 当前图标
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: item.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      currentIcon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 标题和说明
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 分割线
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outline.withValues(alpha: 0.5),
              indent: 20,
              endIndent: 20,
            ),
            // 图标选择标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text(
                    '选择图标',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  // 重置按钮
                  GestureDetector(
                    onTap: () {
                      onResetIcon();
                      Navigator.pop(context);
                    },
                    child: Text(
                      '恢复默认',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 图标网格
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: icons.map((icon) {
                  final isSelected = icon == currentIcon;
                  return GestureDetector(
                    onTap: () {
                      onSelectIcon(icon);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: item.gradientColors)
                            : null,
                        color: isSelected
                            ? null
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : cs.outline,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: item.gradientColors.first.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        icon,
                        size: 26,
                        color: isSelected
                            ? Colors.white
                            : cs.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
