import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style_base.dart';
import 'colors.dart';

/// ============================================================
/// 极简风格 - 间距与圆角常量
/// ============================================================

class MinimalSpacing implements SpacingPack {
  const MinimalSpacing();

  // ─── 间距常量 ──────────────────────────────────────────────
  @override
  double get spaceXs => 4.0;
  @override
  double get spaceSm => 8.0;
  @override
  double get spaceMd => 12.0;
  @override
  double get spaceLg => 16.0;
  @override
  double get spaceXl => 24.0;
  @override
  double get space2xl => 32.0;
  @override
  double get space3xl => 48.0;

  // ─── 圆角常量 (极小或无) ──────────────────────────────────
  @override
  double get radiusSm => 4.0;
  @override
  double get radiusMd => 8.0;
  @override
  double get radiusLg => 12.0;
  @override
  double get radiusXl => 16.0;
  @override
  double get radiusFull => 999.0;

  // ─── BorderRadius ─────────────────────────────────────────
  @override
  BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  @override
  BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  @override
  BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  @override
  BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);

  // ─── 动画时长 (快速) ─────────────────────────────────────
  @override
  Duration get durationFast => const Duration(milliseconds: 100);
  @override
  Duration get durationNormal => const Duration(milliseconds: 200);
  @override
  Duration get durationSlow => const Duration(milliseconds: 300);

  // ─── 阴影 (几乎无阴影) ───────────────────────────────────
  List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: const MinimalColors().shadowDark,
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: const MinimalColors().shadowDark,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: const MinimalColors().shadowDark,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  List<BoxShadow> get shadowPrimary => [
        BoxShadow(
          color: const MinimalColors().primary.withValues(alpha: 0.1),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
}

/// 极简风格完整包
class MinimalStylePack extends StylePack {
  MinimalStylePack();

  @override
  String get id => StyleIds.minimal;

  @override
  StyleMeta get meta => const StyleMeta(
        id: StyleIds.minimal,
        name: '极简',
        description: '无装饰，纯粹干净，专注内容',
      );

  @override
  ThemeData get lightTheme => _buildLightTheme();
  @override
  ThemeData get darkTheme => _buildDarkTheme();
}

ThemeData _buildLightTheme() {
  final colors = const MinimalColors();
  final spacing = const MinimalSpacing();
  final textTheme = _buildTextTheme(colors);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: Brightness.light,
    primary: colors.primary,
    onPrimary: colors.textOnPrimary,
    primaryContainer: colors.surfaceContainer,
    onPrimaryContainer: colors.textPrimary,
    secondary: colors.secondary,
    onSecondary: colors.textOnPrimary,
    tertiary: colors.accent,
    onTertiary: colors.textOnPrimary,
    error: colors.error,
    onError: colors.textOnPrimary,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    surfaceContainerHighest: colors.surfaceContainerHigh,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.border,
    outlineVariant: colors.borderLight,
    shadow: colors.shadowDark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Noto Sans SC',
    textTheme: textTheme.apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary),
    scaffoldBackgroundColor: colors.background,
    appBarTheme: AppBarTheme(
      elevation: 0, scrolledUnderElevation: 0, backgroundColor: colors.background,
      foregroundColor: colors.textPrimary, surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500, color: colors.textPrimary),
      iconTheme: const IconThemeData(color: Colors.black, size: 24),
    ),
    cardTheme: CardThemeData(
      elevation: 0, color: colors.surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: spacing.borderRadiusMd, side: BorderSide(color: colors.border, width: 1)),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0, backgroundColor: colors.primary, foregroundColor: colors.textOnPrimary,
        minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: textTheme.labelLarge?.copyWith(color: colors.textOnPrimary, fontWeight: FontWeight.w500),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0, backgroundColor: colors.primary, foregroundColor: colors.textOnPrimary,
        minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: textTheme.labelLarge?.copyWith(color: colors.textOnPrimary, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0, foregroundColor: colors.primary,
        minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: colors.border, width: 1),
        textStyle: textTheme.labelLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: textTheme.labelLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: colors.textSecondary, minimumSize: const Size(40, 40)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0, backgroundColor: colors.primary, foregroundColor: colors.textOnPrimary,
      shape: RoundedRectangleBorder(borderRadius: spacing.borderRadiusMd),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: spacing.borderRadiusMd, borderSide: BorderSide(color: colors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: spacing.borderRadiusMd, borderSide: BorderSide(color: colors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: spacing.borderRadiusMd, borderSide: BorderSide(color: colors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: spacing.borderRadiusMd, borderSide: BorderSide(color: colors.error)),
      hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0, height: 64,
      backgroundColor: colors.surface, surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: colors.surfaceContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(color: states.contains(WidgetState.selected) ? colors.primary : colors.textSecondary, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected) ? colors.primary : colors.textSecondary,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w500 : FontWeight.w400,
        );
      }),
    ),
    dividerTheme: DividerThemeData(color: colors.divider, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary, linearTrackColor: colors.surfaceContainerHigh,
    ),
    chipTheme: ChipThemeData(
      elevation: 0, pressElevation: 0, backgroundColor: colors.surfaceContainer,
      labelStyle: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide.none, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.textPrimary, contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      elevation: 0, backgroundColor: colors.surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: spacing.borderRadiusLg),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.primary, unselectedLabelColor: colors.textSecondary,
      labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500), unselectedLabelStyle: textTheme.labelLarge,
      indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Colors.black, width: 2)),
      indicatorSize: TabBarIndicatorSize.label,
    ),
  );
}

ThemeData _buildDarkTheme() {
  final colors = const MinimalColors();
  final spacing = const MinimalSpacing();
  final textTheme = _buildTextThemeDark(colors);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: Brightness.dark,
    primary: colors.textPrimaryDark,
    onPrimary: colors.backgroundDark,
    primaryContainer: colors.surfaceElevatedDark,
    onPrimaryContainer: colors.textPrimaryDark,
    secondary: colors.textSecondaryDark,
    onSecondary: colors.backgroundDark,
    tertiary: colors.textTertiaryDark,
    onTertiary: colors.backgroundDark,
    error: colors.errorLight,
    onError: colors.backgroundDark,
    surface: colors.surfaceDark,
    onSurface: colors.textPrimaryDark,
    surfaceContainerHighest: colors.surfaceContainerHighDark,
    onSurfaceVariant: colors.textSecondaryDark,
    outline: colors.borderDark,
    outlineVariant: colors.borderDark.withValues(alpha: 0.5),
    shadow: Colors.black,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Noto Sans SC',
    textTheme: textTheme.apply(bodyColor: colors.textPrimaryDark, displayColor: colors.textPrimaryDark),
    scaffoldBackgroundColor: colors.backgroundDark,
    appBarTheme: AppBarTheme(
      elevation: 0, scrolledUnderElevation: 0, backgroundColor: colors.backgroundDark,
      foregroundColor: colors.textPrimaryDark, surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500, color: colors.textPrimaryDark),
      iconTheme: const IconThemeData(color: Colors.white, size: 24),
    ),
    cardTheme: CardThemeData(
      elevation: 0, color: colors.surfaceDark, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: spacing.borderRadiusMd, side: BorderSide(color: colors.borderDark, width: 1)),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0, backgroundColor: colors.textPrimaryDark, foregroundColor: colors.backgroundDark,
        minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: textTheme.labelLarge?.copyWith(color: colors.backgroundDark, fontWeight: FontWeight.w500),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0, backgroundColor: colors.textPrimaryDark, foregroundColor: colors.backgroundDark,
        minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: textTheme.labelLarge?.copyWith(color: colors.backgroundDark, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0, foregroundColor: colors.textPrimaryDark,
        minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: colors.borderDark, width: 1),
        textStyle: textTheme.labelLarge?.copyWith(color: colors.textPrimaryDark, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.textPrimaryDark, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: textTheme.labelLarge?.copyWith(color: colors.textPrimaryDark, fontWeight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: colors.textSecondaryDark, minimumSize: const Size(40, 40)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0, backgroundColor: colors.textPrimaryDark, foregroundColor: colors.backgroundDark,
      shape: RoundedRectangleBorder(borderRadius: spacing.borderRadiusMd),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: colors.surfaceElevatedDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: spacing.borderRadiusMd, borderSide: BorderSide(color: colors.borderDark)),
      enabledBorder: OutlineInputBorder(borderRadius: spacing.borderRadiusMd, borderSide: BorderSide(color: colors.borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: spacing.borderRadiusMd, borderSide: BorderSide(color: colors.textPrimaryDark, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: spacing.borderRadiusMd, borderSide: BorderSide(color: colors.errorLight)),
      hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textTertiaryDark),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondaryDark),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0, height: 64,
      backgroundColor: colors.surfaceDark.withValues(alpha: 0.95), surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: colors.surfaceElevatedDark,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(color: states.contains(WidgetState.selected) ? colors.textPrimaryDark : colors.textSecondaryDark, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected) ? colors.textPrimaryDark : colors.textSecondaryDark,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w500 : FontWeight.w400,
        );
      }),
    ),
    dividerTheme: DividerThemeData(color: colors.dividerDark, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.textPrimaryDark, linearTrackColor: colors.surfaceContainerHighDark,
    ),
    chipTheme: ChipThemeData(
      elevation: 0, pressElevation: 0, backgroundColor: colors.surfaceElevatedDark,
      labelStyle: textTheme.labelMedium?.copyWith(color: colors.textSecondaryDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: colors.borderDark), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surfaceElevatedDark, contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.textPrimaryDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      elevation: 0, backgroundColor: colors.surfaceDark, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: spacing.borderRadiusLg),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colors.textPrimaryDark, fontWeight: FontWeight.w500),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondaryDark),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceDark, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.textPrimaryDark, unselectedLabelColor: colors.textSecondaryDark,
      labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500), unselectedLabelStyle: textTheme.labelLarge,
      indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Colors.white, width: 2)),
      indicatorSize: TabBarIndicatorSize.label,
    ),
  );
}

TextTheme _buildTextTheme(MinimalColors c) => TextTheme(
  displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.02, height: 1.2, color: c.textPrimary),
  displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.01, height: 1.25, color: c.textPrimary),
  displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.01, height: 1.3, color: c.textPrimary),
  headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.35, color: c.textPrimary),
  headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimary),
  headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimary),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimary),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, color: c.textPrimary),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5, color: c.textPrimary),
  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: c.textPrimary),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: c.textPrimary),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.01, height: 1.5, color: c.textSecondary),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimary),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimary),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.02, height: 1.4, color: c.textSecondary),
);

TextTheme _buildTextThemeDark(MinimalColors c) => TextTheme(
  displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.02, height: 1.2, color: c.textPrimaryDark),
  displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.01, height: 1.25, color: c.textPrimaryDark),
  displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.01, height: 1.3, color: c.textPrimaryDark),
  headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.35, color: c.textPrimaryDark),
  headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimaryDark),
  headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimaryDark),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimaryDark),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, color: c.textPrimaryDark),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5, color: c.textPrimaryDark),
  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: c.textPrimaryDark),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: c.textPrimaryDark),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.01, height: 1.5, color: c.textSecondaryDark),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimaryDark),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimaryDark),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.02, height: 1.4, color: c.textSecondaryDark),
);
