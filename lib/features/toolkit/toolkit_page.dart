import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// 工具项数据模型
class ToolItem {
  final String id;
  final IconData icon;
  final IconData filledIcon;
  final List<Color> gradientColors;
  final String label;
  final String description;
  final String route;

  const ToolItem({
    required this.id,
    required this.icon,
    required this.filledIcon,
    required this.gradientColors,
    required this.label,
    required this.description,
    required this.route,
  });
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
  ),
  ToolItem(
    id: 'notebooks',
    icon: Icons.note_alt_outlined,
    filledIcon: Icons.note_alt_rounded,
    gradientColors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    label: '笔记本',
    description: '收藏内容，整理笔记',
    route: '/toolkit/notebooks',
  ),
  ToolItem(
    id: 'solve',
    icon: Icons.calculate_outlined,
    filledIcon: Icons.calculate_rounded,
    gradientColors: [Color(0xFF10B981), Color(0xFF34D399)],
    label: '解题',
    description: '拍照识题，AI解答',
    route: '/toolkit/solve',
  ),
  ToolItem(
    id: 'quiz',
    icon: Icons.quiz_outlined,
    filledIcon: Icons.quiz_rounded,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    label: '出题',
    description: '智能出题，检验学习',
    route: '/toolkit/quiz',
  ),
  ToolItem(
    id: 'mindmap',
    icon: Icons.account_tree_outlined,
    filledIcon: Icons.account_tree_rounded,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    label: '脑图工坊',
    description: '生成思维导图',
    route: '/toolkit/mindmap-workshop',
  ),
  ToolItem(
    id: 'my-skills',
    icon: Icons.auto_awesome_outlined,
    filledIcon: Icons.auto_awesome_rounded,
    gradientColors: [Color(0xFFEC4899), Color(0xFFF472B6)],
    label: '方法库',
    description: '查看并使用学习方法',
    route: '/my-skills',
  ),
];

/// 工具箱页：全新设计的卡片风格
class ToolkitPage extends StatelessWidget {
  const ToolkitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          // 背景装饰
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: isDark
                      ? [
                          AppColors.secondary.withOpacity(0.15),
                          AppColors.accent.withOpacity(0.08),
                          Colors.transparent,
                        ]
                      : [
                          AppColors.secondaryLight.withOpacity(0.12),
                          AppColors.accentLight.withOpacity(0.06),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          // 装饰圆形
          Positioned(
            top: 60,
            left: -80,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(isDark ? 0.1 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 主内容
          CustomScrollView(
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
              // 工具卡片网格
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ToolCard(item: kDefaultTools[index]),
                    childCount: kDefaultTools.length,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  final ToolItem item;

  const _ToolCard({required this.item});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => context.push(widget.item.route),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标
                Container(
                  width: 52,
                  height: 52,
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
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.item.icon,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // 标签
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // 描述
                Text(
                  widget.item.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // 箭头指示
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceElevatedDark.withOpacity(0.5)
                        : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
