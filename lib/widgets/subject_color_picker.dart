import 'package:flutter/material.dart';
import '../core/theme/subject_gradients.dart';

/// 科目卡片配色选择器（用于编辑科目）
class SubjectColorPicker extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String previewName;

  const SubjectColorPicker({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.previewName = '科',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final previewChar = previewName.isNotEmpty ? previewName[0] : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('卡片颜色', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const Spacer(),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: SubjectGradients.palette[selectedIndex],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                previewChar,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(SubjectGradients.paletteSize, (index) {
            final colors = SubjectGradients.palette[index];
            final selected = index == selectedIndex;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.onSurface : Colors.transparent,
                    width: selected ? 2.5 : 0,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: colors.first.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}
