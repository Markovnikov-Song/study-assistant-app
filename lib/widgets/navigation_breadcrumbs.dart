import 'package:flutter/material.dart';

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbItem({required this.label, this.onTap});
}

class NavigationBreadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final Widget? trailing;

  const NavigationBreadcrumbs({super.key, required this.items, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleItems = items
        .where((item) => item.label.trim().isNotEmpty)
        .toList(growable: false);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...visibleItems.indexed.expand((entry) {
            final index = entry.$1;
            final item = entry.$2;
            final isLast = index == visibleItems.length - 1;
            return [
              if (index > 0)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              _BreadcrumbButton(item: item, isLast: isLast),
            ];
          }),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _BreadcrumbButton extends StatelessWidget {
  final BreadcrumbItem item;
  final bool isLast;

  const _BreadcrumbButton({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 18,
        fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
        color: item.onTap == null ? cs.onSurface : cs.primary,
      ),
    );

    if (item.onTap == null) return text;

    return TextButton(
      onPressed: item.onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: text,
    );
  }
}
