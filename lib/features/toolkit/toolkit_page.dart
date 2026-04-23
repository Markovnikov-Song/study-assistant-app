import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';

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
          final iconCode = int.tryParse(parts[1]);
          if (iconCode != null) {
            map[parts[0]] = IconData(iconCode, fontFamily: 'MaterialIcons');
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
    final list = state.entries.map((e) => '${e.key}:${e.value.codePoint}').toList();
    await prefs.setStringList('custom_tool_icons', list);
  }

  IconData getIcon(String toolId, IconData defaultIcon) {
    return state[toolId] ?? defaultIcon;
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
  ToolItem(
    id: 'mistake-book',
    icon: Icons.error_outline_rounded,
    filledIcon: Icons.error_rounded,
    gradientColors: [Color(0xFFEF4444), Color(0xFFF87171)],
    label: '错题本',
    description: '记录错题，巩固薄弱点',
    route: '/toolkit/mistake-book',
    iconOptions: const [
      Icons.error_outline_rounded,
      Icons.error_rounded,
      Icons.warning_amber_outlined,
      Icons.gpp_bad_outlined,
      Icons.report_outlined,
      Icons.cancel_outlined,
    ],
  ),
  ToolItem(
    id: 'notebooks',
    icon: Icons.note_alt_outlined,
    filledIcon: Icons.note_alt_rounded,
    gradientColors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    label: '笔记本',
    description: '收藏内容，整理笔记',
    route: '/toolkit/notebooks',
    iconOptions: const [
      Icons.note_alt_outlined,
      Icons.note_alt_rounded,
      Icons.sticky_note_2_outlined,
      Icons.book_outlined,
      Icons.auto_stories_outlined,
      Icons.edit_note_outlined,
    ],
  ),
  ToolItem(
    id: 'solve',
    icon: Icons.calculate_outlined,
    filledIcon: Icons.calculate_rounded,
    gradientColors: [Color(0xFF10B981), Color(0xFF34D399)],
    label: '解题',
    description: '拍照识题，AI解答',
    route: '/toolkit/solve',
    iconOptions: const [
      Icons.calculate_outlined,
      Icons.calculate_rounded,
      Icons.functions,
      Icons.analytics_outlined,
      Icons.numbers,
      Icons.quick_contacts_dialer_outlined,
    ],
  ),
  ToolItem(
    id: 'quiz',
    icon: Icons.quiz_outlined,
    filledIcon: Icons.quiz_rounded,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    label: '出题',
    description: '智能出题，检验学习',
    route: '/toolkit/quiz',
    iconOptions: const [
      Icons.quiz_outlined,
      Icons.quiz_rounded,
      Icons.help_outline_rounded,
      Icons.extension_outlined,
      Icons.psychology_outlined,
      Icons.lightbulb_outline_rounded,
    ],
  ),
  ToolItem(
    id: 'mindmap',
    icon: Icons.account_tree_outlined,
    filledIcon: Icons.account_tree_rounded,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    label: '脑图工坊',
    description: '生成思维导图',
    route: '/toolkit/mindmap-workshop',
    iconOptions: const [
      Icons.account_tree_outlined,
      Icons.account_tree_rounded,
      Icons.hub_outlined,
      Icons.device_hub_outlined,
      Icons.bubble_chart_outlined,
      Icons.psychology_outlined,
    ],
  ),
  ToolItem(
    id: 'my-skills',
    icon: Icons.auto_awesome_outlined,
    filledIcon: Icons.auto_awesome_rounded,
    gradientColors: [Color(0xFFEC4899), Color(0xFFF472B6)],
    label: '方法库',
    description: '查看并使用学习方法',
    route: '/my-skills',
    iconOptions: const [
      Icons.auto_awesome_outlined,
      Icons.auto_awesome_rounded,
      Icons.star_outline_rounded,
      Icons.auto_fix_high_outlined,
      Icons.wand_outlined,
      Icons.tips_and_updates_outlined,
    ],
  ),
  ToolItem(
    id: 'calendar',
    icon: Icons.calendar_today_outlined,
    filledIcon: Icons.calendar_today_rounded,
    gradientColors: [Color(0xFF6366F1), Color(0xFF818CF8)],
    label: '学习日历',
    description: '计划、打卡、复盘，学习闭环',
    route: '/toolkit/calendar',
    iconOptions: const [
      Icons.calendar_today_outlined,
      Icons.calendar_month_outlined,
      Icons.event_note_outlined,
      Icons.schedule_outlined,
      Icons.edit_calendar_outlined,
      Icons.date_range_outlined,
    ],
  ),
];

/// 工具箱页：全新设计的卡片风格
class ToolkitPage extends ConsumerWidget {
  const ToolkitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    // Web端限制最大宽度，保持类似手机的紧凑布局
    final contentMaxWidth = isWideScreen ? 420.0 : double.infinity;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
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
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                      title: Text(
                        '工具箱',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
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
                        childAspectRatio: 0.88,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ToolCard(
                          item: kDefaultTools[index],
                          iconSize: isWideScreen ? 48 : 44,
                        ),
                        childCount: kDefaultTools.length,
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
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? Colors.black.withOpacity(0.1)
                    : Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                blurRadius: _isPressed ? 8 : 16,
                offset: Offset(0, _isPressed ? 2 : 6),
              ),
            ],
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.border,
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
                        color: widget.item.gradientColors.first.withOpacity(0.35),
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
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
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
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
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
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceElevatedDark.withOpacity(0.5)
                            : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icons = item.iconOptions!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
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
                color: isDark ? AppColors.borderDark : AppColors.border,
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
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '长按卡片可随时更换',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
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
                          color: AppColors.primary,
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
                            : (isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceContainer),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark ? AppColors.borderDark : AppColors.border),
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: item.gradientColors.first.withOpacity(0.4),
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
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
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
