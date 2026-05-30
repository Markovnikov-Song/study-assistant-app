import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/capability/capability_models.dart';
import '../../core/capability/capability_providers.dart';
import '../../core/theme/styles/export.dart';
import '../../routes/app_router.dart';
import '../../routes/app_navigation.dart';
import '../../widgets/diy_corner_badge.dart';
import '../workshop/mini_app_models.dart';
import '../workshop/mini_app_providers.dart';

class ToolItem {
  final String id;
  final IconData icon;
  final List<Color> colors;
  final String label;
  final String description;
  final String route;
  final String? iconAsset;
  final bool userCreated;

  const ToolItem({
    required this.id,
    required this.icon,
    required this.colors,
    required this.label,
    required this.description,
    required this.route,
    this.iconAsset,
    this.userCreated = false,
  });

  List<Color> get gradientColors => colors;

  ToolItem copyWith({IconData? icon}) {
    return ToolItem(
      id: id,
      icon: icon ?? this.icon,
      colors: colors,
      label: label,
      description: description,
      route: route,
      iconAsset: iconAsset,
      userCreated: userCreated,
    );
  }
}

const _iconPackRoot = 'assets/images/icons/nieobie_game_icon_pack/svg-v1.0.3';

const kWorkshopTool = ToolItem(
  id: 'workshop',
  icon: Icons.precision_manufacturing_rounded,
  colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
  label: '软件工坊',
  description: '拼装并运行学科学习软件',
  route: R.workshop,
  iconAsset: '$_iconPackRoot/6.Items/tool-kit.svg',
);

const kDefaultTools = [
  ToolItem(
    id: 'solve',
    icon: Icons.camera_alt_rounded,
    colors: [Color(0xFF19D3A2), Color(0xFF12AEEA)],
    label: '拍照解题',
    description: '拍题、识别、讲透步骤',
    route: R.toolkitSolve,
    iconAsset: '$_iconPackRoot/2.Media & Technology/camera.svg',
  ),
  ToolItem(
    id: 'quiz',
    icon: Icons.extension_rounded,
    colors: [Color(0xFFFFB23F), Color(0xFFFF6B8B)],
    label: '智能出题',
    description: '按知识点生成练习',
    route: R.toolkitQuiz,
    iconAsset: '$_iconPackRoot/5.Game/puzzle.svg',
  ),
  ToolItem(
    id: 'review',
    icon: Icons.replay_circle_filled_rounded,
    colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
    label: '复盘中心',
    description: '错题、间隔复习、再练',
    route: '/toolkit/review',
    iconAsset: '$_iconPackRoot/5.Game/cards.svg',
  ),
  ToolItem(
    id: 'notebooks',
    icon: Icons.auto_stories_rounded,
    colors: [Color(0xFF5B8CFF), Color(0xFF7C5CFF)],
    label: '笔记本',
    description: '保存讲义、整理灵感',
    route: R.toolkitNotebooks,
    iconAsset: '$_iconPackRoot/6.Items/book.svg',
  ),
  ToolItem(
    id: 'mindmap',
    icon: Icons.account_tree_rounded,
    colors: [Color(0xFF8B5CF6), Color(0xFFEC5DFF)],
    label: '脑图工坊',
    description: '把知识整理成结构',
    route: R.mindmapGenerate,
    iconAsset: '$_iconPackRoot/6.Items/map.svg',
  ),
  ToolItem(
    id: 'calendar',
    icon: Icons.calendar_month_rounded,
    colors: [Color(0xFF4F8BFF), Color(0xFF4EE7F1)],
    label: '学习日历',
    description: '计划、打卡、倒计时',
    route: R.toolkitCalendar,
    iconAsset: '$_iconPackRoot/2.Media & Technology/calendar.svg',
  ),
  kWorkshopTool,
];

ToolItem toolItemFromCapability(CapabilitySummary capability) {
  return ToolItem(
    id: capability.id,
    icon: _iconFromCapability(capability.icon),
    colors: _colorsFromCapability(capability.color),
    label: capability.title,
    description: capability.description,
    route: capability.miniAppRoute ?? R.toolkit,
  );
}

ToolItem toolItemFromMiniApp(MiniAppSummary app) {
  return ToolItem(
    id: 'mini_app_${app.id}',
    icon: _miniAppIcon(app.appType),
    iconAsset: _miniAppIconAsset(app.appType),
    colors: _miniAppColors(app.appType),
    label: app.title.isEmpty ? '学习小软件' : app.title,
    description: app.description.isEmpty ? '运行工坊生成的学习流程' : app.description,
    route: R.workshopApp(app.id),
    userCreated: true,
  );
}

IconData _miniAppIcon(String type) {
  return switch (type) {
    'mistake_drill' => Icons.replay_circle_filled_rounded,
    'quest' => Icons.route_rounded,
    _ => Icons.style_rounded,
  };
}

String _miniAppIconAsset(String type) {
  return switch (type) {
    'mistake_drill' => '$_iconPackRoot/5.Game/cards.svg',
    'quest' => '$_iconPackRoot/6.Items/map.svg',
    _ => '$_iconPackRoot/5.Game/card.svg',
  };
}

List<Color> _miniAppColors(String type) {
  return switch (type) {
    'mistake_drill' => const [Color(0xFFFF5F6D), Color(0xFFFFC371)],
    'quest' => const [Color(0xFF8B5CF6), Color(0xFFEC5DFF)],
    _ => const [Color(0xFF2563EB), Color(0xFF10B981)],
  };
}

IconData _iconFromCapability(String icon) {
  return switch (icon) {
    'camera_alt' => Icons.camera_alt_rounded,
    'extension' => Icons.extension_rounded,
    'replay_circle_filled' => Icons.replay_circle_filled_rounded,
    'auto_stories' => Icons.auto_stories_rounded,
    'account_tree' => Icons.account_tree_rounded,
    'calendar_month' => Icons.calendar_month_rounded,
    'auto_awesome' => Icons.auto_awesome_rounded,
    _ => Icons.widgets_rounded,
  };
}

List<Color> _colorsFromCapability(List<String> values) {
  final parsed = values.map(_parseHexColor).whereType<Color>().toList();
  if (parsed.length >= 2) return parsed.take(2).toList();
  return const [Color(0xFF5B8CFF), Color(0xFF7C5CFF)];
}

Color? _parseHexColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) return null;
  final raw = int.tryParse(normalized, radix: 16);
  if (raw == null) return null;
  return Color(normalized.length == 6 ? 0xFF000000 | raw : raw);
}

class ToolkitPage extends ConsumerWidget {
  const ToolkitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final styleId = ref.watch(uiStyleIdProvider);
    final isClay = styleId == StyleIds.clay;
    final crossAxisCount = width >= 1400 ? 4 : (isDesktop ? 3 : 2);
    final horizontal = isDesktop ? 28.0 : 18.0;
    final capabilitiesAsync = ref.watch(standaloneCapabilitiesProvider);
    final miniApps = ref.watch(miniAppsProvider).valueOrNull ?? const [];
    final order = ref.watch(toolOrderProvider);
    final hiddenIds = ref.watch(hiddenToolsProvider);
    final customIcons = ref.watch(toolIconsProvider);
    final capabilityTools = capabilitiesAsync.maybeWhen(
      data: (capabilities) => capabilities
          .where(
            (capability) =>
                capability.miniAppRoute != null &&
                capability.miniAppRoute!.isNotEmpty &&
                capability.miniAppRoute != '/my-skills',
          )
          .map(toolItemFromCapability)
          .toList(),
      orElse: () => const <ToolItem>[],
    );
    final baseTools = capabilityTools.isNotEmpty
        ? capabilityTools
        : kDefaultTools;
    final builtInTools =
        baseTools.any(
          (tool) =>
              tool.id == kWorkshopTool.id || tool.route == kWorkshopTool.route,
        )
        ? baseTools
        : [...baseTools, kWorkshopTool];
    final availableTools = [
      ...builtInTools,
      ...miniApps.map(toolItemFromMiniApp),
    ];
    final tools = _orderedTools(availableTools, order)
        .where((tool) => !hiddenIds.contains(tool.id))
        .map((tool) => tool.copyWith(icon: customIcons[tool.id]))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              isDesktop ? 26 : 18,
              horizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _ToolkitHero(isDesktop: isDesktop, styleId: styleId),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              isClay ? 18 : 22,
              horizontal,
              120,
            ),
            sliver: SliverGrid.builder(
              itemCount: tools.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: isDesktop ? 16 : 12,
                mainAxisSpacing: isDesktop ? 16 : 12,
                childAspectRatio: isDesktop ? 1.55 : 1.06,
              ),
              itemBuilder: (context, index) =>
                  _ToolCard(item: tools[index], styleId: styleId),
            ),
          ),
        ],
      ),
    );
  }
}

List<ToolItem> _orderedTools(List<ToolItem> tools, List<String> order) {
  final byId = {for (final tool in tools) tool.id: tool};
  final ordered = <ToolItem>[];
  for (final id in order) {
    final tool = byId.remove(id);
    if (tool != null) ordered.add(tool);
  }
  ordered.addAll(byId.values);
  return ordered;
}

final toolOrderProvider =
    StateNotifierProvider<ToolOrderNotifier, List<String>>((ref) {
      return ToolOrderNotifier();
    });

class ToolOrderNotifier extends StateNotifier<List<String>> {
  ToolOrderNotifier() : super(kDefaultTools.map((tool) => tool.id).toList()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('tool_order');
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final next = [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), item);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tool_order', state);
  }

  Future<void> resetToDefault() async {
    state = kDefaultTools.map((tool) => tool.id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tool_order', state);
  }
}

final hiddenToolsProvider =
    StateNotifierProvider<HiddenToolsNotifier, Set<String>>((ref) {
      return HiddenToolsNotifier();
    });

class HiddenToolsNotifier extends StateNotifier<Set<String>> {
  HiddenToolsNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList('hidden_tools') ?? const []).toSet();
  }

  Future<void> hide(String id) async {
    state = {...state, id};
    await _persist();
  }

  Future<void> show(String id) async {
    final next = {...state}..remove(id);
    state = next;
    await _persist();
  }

  Future<void> reset() async {
    state = const {};
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_tools', state.toList());
  }
}

final toolIconsProvider =
    StateNotifierProvider<ToolIconsNotifier, Map<String, IconData>>((ref) {
      return ToolIconsNotifier();
    });

class ToolIconsNotifier extends StateNotifier<Map<String, IconData>> {
  ToolIconsNotifier() : super(const {});

  IconData getIcon(String toolId, IconData defaultIcon) {
    return state[toolId] ?? defaultIcon;
  }

  Future<void> setIcon(String toolId, IconData icon) async {
    state = {...state, toolId: icon};
  }

  Future<void> resetIcon(String toolId) async {
    final next = {...state}..remove(toolId);
    state = next;
  }
}

class _ToolkitHero extends StatelessWidget {
  final bool isDesktop;
  final String styleId;

  const _ToolkitHero({required this.isDesktop, required this.styleId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isClay = styleId == StyleIds.clay;
    final claySurface = Color.lerp(
      cs.surface,
      cs.surfaceContainerHighest,
      0.32,
    )!;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: isClay ? claySurface : null,
        gradient: isClay
            ? null
            : const LinearGradient(
                colors: [
                  Color(0xFF1F2937),
                  Color(0xFF5B5CF6),
                  Color(0xFFFF6BAA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(
          isClay ? 32 : (isDesktop ? 28 : 24),
        ),
        border: isClay
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.4,
              )
            : null,
        boxShadow: [
          if (isClay) ...[
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.20),
              blurRadius: 26,
              spreadRadius: 1,
              offset: const Offset(12, 12),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.78),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(-12, -12),
            ),
          ] else
            BoxShadow(
              color: const Color(0xFF5B5CF6).withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '工具箱',
                  style: TextStyle(
                    fontSize: isDesktop ? 32 : 28,
                    fontWeight: FontWeight.w900,
                    color: isClay ? cs.onSurface : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '把拍题、出题、复盘、笔记和计划放进一个学习工作台。',
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 13,
                    color: isClay
                        ? cs.onSurfaceVariant
                        : Colors.white.withValues(alpha: 0.82),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 28),
            IconButton.filledTonal(
              onPressed: () => context.push(R.toolkitSettings),
              icon: const Icon(Icons.tune_rounded),
              tooltip: '工具设置',
              style: IconButton.styleFrom(
                backgroundColor: isClay
                    ? cs.surface.withValues(alpha: 0.60)
                    : Colors.white.withValues(alpha: 0.16),
                foregroundColor: isClay ? cs.primary : Colors.white,
              ),
            ),
          ],
          if (!isDesktop)
            IconButton(
              onPressed: () => context.push(R.toolkitSettings),
              icon: const Icon(Icons.tune_rounded),
              color: isClay ? cs.primary : Colors.white,
              tooltip: '工具设置',
            ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  final ToolItem item;
  final String styleId;

  const _ToolCard({required this.item, required this.styleId});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isClay = widget.styleId == StyleIds.clay;
    final radius = isClay ? 28.0 : 22.0;
    final cardColor = isClay
        ? Color.lerp(cs.surface, cs.surfaceContainerHighest, 0.30)!
        : cs.surface.withValues(alpha: 0.86);
    final showDiyBadge =
        widget.item.userCreated || widget.item.id == kWorkshopTool.id;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: () => navigateAppRoute(context, widget.item.route),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            padding: EdgeInsets.all(isClay ? 17 : 18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: isClay ? 0.92 : 0.62),
                width: isClay ? 1.35 : 1,
              ),
              boxShadow: [
                if (isClay) ...[
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.20),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(11, 11),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.78),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(-11, -11),
                  ),
                ] else
                  BoxShadow(
                    color: widget.item.colors.first.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: widget.item.colors),
                        borderRadius: BorderRadius.circular(isClay ? 18 : 16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.item.colors.first.withValues(
                              alpha: isClay ? 0.28 : 0.36,
                            ),
                            blurRadius: isClay ? 16 : 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _ToolIcon(item: widget.item, size: 25),
                    ),
                    const Spacer(),
                    Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (showDiyBadge)
                  const Positioned(top: 0, right: 0, child: DiyCornerBadge()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final ToolItem item;
  final double size;

  const _ToolIcon({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = item.iconAsset;
    if (asset != null && asset.isNotEmpty) {
      return Center(
        child: SvgPicture.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (_) =>
              Icon(item.icon, color: Colors.white, size: size),
        ),
      );
    }
    return Icon(item.icon, color: Colors.white, size: size);
  }
}
