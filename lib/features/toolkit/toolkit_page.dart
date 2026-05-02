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
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
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
    
    // 获取排序后的工具列表
    final orderedTools = ref.watch(toolOrderProvider.notifier).getOrderedTools();

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
                  // 工具卡片网格（固定2列，类似手机布局）
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ToolCard(
                          item: orderedTools[index],
                          iconSize: isWideScreen ? 48 : 44,
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

  const _ToolCard({required this.item, this.iconSize = 44});

  @override
  ConsumerState<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends ConsumerState<_ToolCard> {
  bool _isPressed = false;

  /// 长按显示图标选择器
  void _showIconPicker() {
    if (widget.item.iconOptions == null || widget.item.iconOptions!.isEmpty) {
      return;
    }

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _IconPickerSheet(
        item: widget.item,
        currentIcon: ref.read(toolIconsProvider.notifier).getIcon(
              widget.item.id,
              widget.item.icon,
            ),
        onSelect: (icon) {
          ref.read(toolIconsProvider.notifier).setIcon(widget.item.id, icon);
          Navigator.pop(context);
        },
        onReset: () {
          ref.read(toolIconsProvider.notifier).resetIcon(widget.item.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      // 长按显示图标选择（仅对有 iconOptions 的工具生效）
      onLongPress: widget.item.iconOptions != null ? _showIconPicker : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // ignore: deprecated_member_use
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: _isPressed ? 8 : 16,
                offset: Offset(0, _isPressed ? 2 : 6),
              ),
            ],
            border: Border.all(
              color: cs.outline,
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 图标
                Container(
                  width: widget.iconSize,
                  height: widget.iconSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.item.gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: widget.item.gradientColors.first.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    currentIcon,
                    size: widget.iconSize * 0.52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // 标签
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // 描述
                Text(
                  widget.item.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // 底部指示
                Row(
                  children: [
                    if (widget.item.iconOptions != null)
                      Icon(
                        Icons.touch_app_outlined,
                        size: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 1.0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 图标选择器底部弹窗
class _IconPickerSheet extends StatelessWidget {
  final ToolItem item;
  final IconData currentIcon;
  final ValueChanged<IconData> onSelect;
  final VoidCallback onReset;

  const _IconPickerSheet({
    required this.item,
    required this.currentIcon,
    required this.onSelect,
    required this.onReset,
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
            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: item.gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择${item.label}图标',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '长按卡片可随时更换',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 重置按钮
                  if (item.availableIcons.contains(item.icon))
                    TextButton(
                      onPressed: onReset,
                      child: Text(
                        '恢复默认',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.primary,
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
                    onTap: () => onSelect(icon),
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
