import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style_base.dart';
import 'colors.dart';

/// ============================================================
/// 默认风格 - 静谧学习 主题数据
/// ============================================================

class DefaultSpacing implements SpacingPack {
  const DefaultSpacing();

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

  // ─── 圆角常量 ──────────────────────────────────────────────
  @override
  double get radiusSm => 6.0;
  @override
  double get radiusMd => 12.0;
  @override
  double get radiusLg => 16.0;
  @override
  double get radiusXl => 24.0;
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

  // ─── 动画时长 ─────────────────────────────────────────────
  @override
  Duration get durationFast => const Duration(milliseconds: 150);
  @override
  Duration get durationNormal => const Duration(milliseconds: 300);
  @override
  Duration get durationSlow => const Duration(milliseconds: 500);

  // ─── 阴影 ─────────────────────────────────────────────────
  List<BoxShadow> get shadowSm => [
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ];

  List<BoxShadow> get shadowMd => [
        const BoxShadow(
          color: Color(0x12000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ];

  List<BoxShadow> get shadowLg => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 15,
          offset: Offset(0, 4),
        ),
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];

  List<BoxShadow> get shadowXl => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 25,
          offset: Offset(0, 10),
        ),
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ];

  List<BoxShadow> get shadowPrimary => [
        BoxShadow(
          color: DefaultColors().primary.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
}

/// 默认风格完整包
class DefaultStylePack extends StylePack {
  DefaultStylePack();

  @override
  String get id => StyleIds.defaultStyle;

  @override
  StyleMeta get meta => const StyleMeta(
        id: StyleIds.defaultStyle,
        name: '静谧学习',
        description: '深靛蓝/紫渐变配浮光球，专注学习氛围',
      );

  @override
  ThemeData get lightTheme => _buildLightTheme();
  @override
  ThemeData get darkTheme => _buildDarkTheme();
}

ThemeData _buildLightTheme() {
  final colors = const DefaultColors();
  final spacing = const DefaultSpacing();
  final textTheme = _buildTextTheme(colors);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: Brightness.light,
    primary: colors.primary,
    onPrimary: colors.textOnPrimary,
    primaryContainer: colors.primaryLight.withValues(alpha: 0.15),
    onPrimaryContainer: colors.primaryDark,
    secondary: colors.secondary,
    onSecondary: colors.textOnPrimary,
    secondaryContainer: colors.secondaryLight.withValues(alpha: 0.15),
    onSecondaryContainer: colors.secondary,
    tertiary: colors.accent,
    onTertiary: colors.textOnPrimary,
    tertiaryContainer: colors.accentLight.withValues(alpha: 0.15),
    onTertiaryContainer: colors.accent,
    error: colors.error,
    onError: colors.textOnPrimary,
    errorContainer: colors.errorLight.withValues(alpha: 0.15),
    onErrorContainer: colors.error,
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
    textTheme: textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    scaffoldBackgroundColor: colors.background,
    appBarTheme: _buildAppBarTheme(colors, textTheme, Brightness.light),
    cardTheme: _buildCardTheme(colors, spacing),
    elevatedButtonTheme: _buildElevatedButtonTheme(colors, textTheme, Brightness.light),
    filledButtonTheme: _buildFilledButtonTheme(colors, textTheme, Brightness.light),
    outlinedButtonTheme: _buildOutlinedButtonTheme(colors, textTheme, Brightness.light),
    textButtonTheme: _buildTextButtonTheme(colors, textTheme, Brightness.light),
    iconButtonTheme: _buildIconButtonTheme(colors),
    floatingActionButtonTheme: _buildFabTheme(colors, spacing),
    inputDecorationTheme: _buildInputTheme(colors, spacing, textTheme, Brightness.light),
    navigationBarTheme: _buildNavBarTheme(colors, textTheme, Brightness.light),
    dividerTheme: _buildDividerTheme(colors),
    progressIndicatorTheme: _buildProgressTheme(colors),
    chipTheme: _buildChipTheme(colors, textTheme, Brightness.light),
    snackBarTheme: _buildSnackBarTheme(colors, textTheme),
    dialogTheme: _buildDialogTheme(colors, textTheme, spacing),
    bottomSheetTheme: _buildBottomSheetTheme(colors, spacing),
    tabBarTheme: _buildTabBarTheme(colors, textTheme),
  );
}

ThemeData _buildDarkTheme() {
  final colors = const DefaultColors();
  final spacing = const DefaultSpacing();
  final textTheme = _buildTextTheme(colors);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: Brightness.dark,
    primary: colors.primaryLight,
    onPrimary: colors.backgroundDark,
    primaryContainer: colors.primaryDark.withValues(alpha: 0.3),
    onPrimaryContainer: colors.primaryLight,
    secondary: colors.secondaryLight,
    onSecondary: colors.backgroundDark,
    secondaryContainer: colors.secondary.withValues(alpha: 0.3),
    onSecondaryContainer: colors.secondaryLight,
    tertiary: colors.accentLight,
    onTertiary: colors.backgroundDark,
    tertiaryContainer: colors.accent.withValues(alpha: 0.3),
    onTertiaryContainer: colors.accentLight,
    error: colors.errorLight,
    onError: colors.backgroundDark,
    errorContainer: colors.error.withValues(alpha: 0.3),
    onErrorContainer: colors.errorLight,
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
    textTheme: textTheme.apply(
      bodyColor: colors.textPrimaryDark,
      displayColor: colors.textPrimaryDark,
    ),
    scaffoldBackgroundColor: colors.backgroundDark,
    appBarTheme: _buildAppBarTheme(colors, textTheme, Brightness.dark),
    cardTheme: _buildCardThemeDark(colors, spacing),
    elevatedButtonTheme: _buildElevatedButtonTheme(colors, textTheme, Brightness.dark),
    filledButtonTheme: _buildFilledButtonTheme(colors, textTheme, Brightness.dark),
    outlinedButtonTheme: _buildOutlinedButtonTheme(colors, textTheme, Brightness.dark),
    textButtonTheme: _buildTextButtonTheme(colors, textTheme, Brightness.dark),
    iconButtonTheme: _buildIconButtonThemeDark(colors),
    floatingActionButtonTheme: _buildFabThemeDark(colors, spacing),
    inputDecorationTheme: _buildInputThemeDark(colors, spacing, textTheme),
    navigationBarTheme: _buildNavBarTheme(colors, textTheme, Brightness.dark),
    dividerTheme: _buildDividerThemeDark(colors),
    progressIndicatorTheme: _buildProgressThemeDark(colors),
    chipTheme: _buildChipThemeDark(colors, textTheme),
    snackBarTheme: _buildSnackBarThemeDark(colors, textTheme),
    dialogTheme: _buildDialogThemeDark(colors, textTheme, spacing),
    bottomSheetTheme: _buildBottomSheetThemeDark(colors, spacing),
    tabBarTheme: _buildTabBarThemeDark(colors, textTheme),
  );
}

TextTheme _buildTextTheme(DefaultColors colors) {
  return TextTheme(
    displayLarge: TextStyle(
      fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.02, height: 1.2,
      color: colors.textPrimary,
    ),
    displayMedium: TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.01, height: 1.25,
      color: colors.textPrimary,
    ),
    displaySmall: TextStyle(
      fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.01, height: 1.3,
      color: colors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontSize: 22, fontWeight: FontWeight.w600, height: 1.35, color: colors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, color: colors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: colors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: colors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, color: colors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500, height: 1.5, color: colors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: colors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: colors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.01, height: 1.5,
      color: colors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: colors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: colors.textPrimary,
    ),
    labelSmall: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.02, height: 1.4,
      color: colors.textSecondary,
    ),
  );
}

AppBarTheme _buildAppBarTheme(DefaultColors c, TextTheme t, Brightness brightness) {
  return AppBarTheme(
    elevation: 0, scrolledUnderElevation: 0.5,
    backgroundColor: brightness == Brightness.dark ? c.backgroundDark : c.background,
    foregroundColor: brightness == Brightness.dark ? c.textPrimaryDark : c.textPrimary,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    titleTextStyle: t.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: brightness == Brightness.dark ? c.textPrimaryDark : c.textPrimary,
    ),
    iconTheme: IconThemeData(
      color: brightness == Brightness.dark ? c.textPrimaryDark : c.textPrimary, size: 24,
    ),
  );
}

CardThemeData _buildCardTheme(DefaultColors c, DefaultSpacing s) {
  return CardThemeData(
    elevation: 0, color: c.surface, surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: s.borderRadiusMd,
      side: BorderSide(color: c.border, width: 1),
    ),
    margin: EdgeInsets.zero,
  );
}

CardThemeData _buildCardThemeDark(DefaultColors c, DefaultSpacing s) {
  return CardThemeData(
    elevation: 0, color: c.surfaceDark, surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: s.borderRadiusMd,
      side: BorderSide(color: c.borderDark, width: 1),
    ),
    margin: EdgeInsets.zero,
  );
}

ElevatedButtonThemeData _buildElevatedButtonTheme(DefaultColors c, TextTheme t, Brightness brightness) {
  final bgColor = brightness == Brightness.dark ? c.primaryLight : c.primary;
  final fgColor = brightness == Brightness.dark ? c.backgroundDark : c.textOnPrimary;
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0, backgroundColor: bgColor, foregroundColor: fgColor,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: t.labelLarge?.copyWith(color: fgColor, fontWeight: FontWeight.w600),
    ),
  );
}

FilledButtonThemeData _buildFilledButtonTheme(DefaultColors c, TextTheme t, Brightness brightness) {
  final bgColor = brightness == Brightness.dark ? c.primaryLight : c.primary;
  final fgColor = brightness == Brightness.dark ? c.backgroundDark : c.textOnPrimary;
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      elevation: 0, backgroundColor: bgColor, foregroundColor: fgColor,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: t.labelLarge?.copyWith(color: fgColor, fontWeight: FontWeight.w600),
    ),
  );
}

OutlinedButtonThemeData _buildOutlinedButtonTheme(DefaultColors c, TextTheme t, Brightness brightness) {
  final color = brightness == Brightness.dark ? c.primaryLight : c.primary;
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      elevation: 0, foregroundColor: color,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: color, width: 1.5),
      textStyle: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

TextButtonThemeData _buildTextButtonTheme(DefaultColors c, TextTheme t, Brightness brightness) {
  final color = brightness == Brightness.dark ? c.primaryLight : c.primary;
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      textStyle: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w500),
    ),
  );
}

IconButtonThemeData _buildIconButtonTheme(DefaultColors c) {
  return IconButtonThemeData(
    style: IconButton.styleFrom(foregroundColor: c.textSecondary, minimumSize: const Size(40, 40)),
  );
}

IconButtonThemeData _buildIconButtonThemeDark(DefaultColors c) {
  return IconButtonThemeData(
    style: IconButton.styleFrom(foregroundColor: c.textSecondaryDark, minimumSize: const Size(40, 40)),
  );
}

FloatingActionButtonThemeData _buildFabTheme(DefaultColors c, DefaultSpacing s) {
  return FloatingActionButtonThemeData(
    elevation: 4, backgroundColor: c.primary, foregroundColor: c.textOnPrimary,
    shape: RoundedRectangleBorder(borderRadius: s.borderRadiusMd),
  );
}

FloatingActionButtonThemeData _buildFabThemeDark(DefaultColors c, DefaultSpacing s) {
  return FloatingActionButtonThemeData(
    elevation: 4, backgroundColor: c.primaryLight, foregroundColor: c.backgroundDark,
    shape: RoundedRectangleBorder(borderRadius: s.borderRadiusMd),
  );
}

InputDecorationTheme _buildInputTheme(DefaultColors c, DefaultSpacing s, TextTheme t, Brightness brightness) {
  return InputDecorationTheme(
    filled: true, fillColor: c.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.border)),
    enabledBorder: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.border)),
    focusedBorder: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.primary, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.error)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.error, width: 2)),
    hintStyle: t.bodyMedium?.copyWith(color: c.textTertiary),
    labelStyle: t.bodyMedium?.copyWith(color: c.textSecondary),
    errorStyle: t.bodySmall?.copyWith(color: c.error),
  );
}

InputDecorationTheme _buildInputThemeDark(DefaultColors c, DefaultSpacing s, TextTheme t) {
  return InputDecorationTheme(
    filled: true, fillColor: c.surfaceElevatedDark,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.borderDark)),
    enabledBorder: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.borderDark)),
    focusedBorder: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.primaryLight, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.errorLight)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: s.borderRadiusMd, borderSide: BorderSide(color: c.errorLight, width: 2)),
    hintStyle: t.bodyMedium?.copyWith(color: c.textTertiaryDark),
    labelStyle: t.bodyMedium?.copyWith(color: c.textSecondaryDark),
    errorStyle: t.bodySmall?.copyWith(color: c.errorLight),
  );
}

NavigationBarThemeData _buildNavBarTheme(DefaultColors c, TextTheme t, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final selectedColor = isDark ? c.primaryLight : c.primary;
  final unselectedColor = isDark ? c.textSecondaryDark : c.textSecondary;
  final indicatorColor = isDark ? c.primaryDark.withValues(alpha: 0.3) : c.primaryLight.withValues(alpha: 0.15);
  final bgColor = isDark ? c.surfaceDark.withValues(alpha: 0.9) : c.surface.withValues(alpha: 0.85);

  return NavigationBarThemeData(
    elevation: 0, backgroundColor: bgColor, surfaceTintColor: Colors.transparent, height: 80,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    indicatorColor: indicatorColor,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return IconThemeData(color: selectedColor, size: 24);
      return IconThemeData(color: unselectedColor, size: 24);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return t.labelSmall?.copyWith(color: selectedColor, fontWeight: FontWeight.w600);
      }
      return t.labelSmall?.copyWith(color: unselectedColor);
    }),
  );
}

DividerThemeData _buildDividerTheme(DefaultColors c) {
  return DividerThemeData(color: c.divider, thickness: 1, space: 1);
}

DividerThemeData _buildDividerThemeDark(DefaultColors c) {
  return DividerThemeData(color: c.dividerDark, thickness: 1, space: 1);
}

ProgressIndicatorThemeData _buildProgressTheme(DefaultColors c) {
  return ProgressIndicatorThemeData(
    color: c.primary, linearTrackColor: c.surfaceContainerHigh, circularTrackColor: c.surfaceContainerHigh,
  );
}

ProgressIndicatorThemeData _buildProgressThemeDark(DefaultColors c) {
  return ProgressIndicatorThemeData(
    color: c.primaryLight, linearTrackColor: c.surfaceContainerHighDark, circularTrackColor: c.surfaceContainerHighDark,
  );
}

ChipThemeData _buildChipTheme(DefaultColors c, TextTheme t, Brightness brightness) {
  final selectedColor = brightness == Brightness.dark ? c.primaryDark.withValues(alpha: 0.3) : c.primaryLight.withValues(alpha: 0.15);
  return ChipThemeData(
    elevation: 0, pressElevation: 0, backgroundColor: c.surfaceContainer,
    selectedColor: selectedColor,
    labelStyle: t.labelMedium?.copyWith(color: c.textSecondary),
    secondaryLabelStyle: t.labelMedium?.copyWith(color: c.primary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    side: BorderSide.none, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

ChipThemeData _buildChipThemeDark(DefaultColors c, TextTheme t) {
  return ChipThemeData(
    elevation: 0, pressElevation: 0, backgroundColor: c.surfaceElevatedDark,
    selectedColor: c.primaryDark.withValues(alpha: 0.3),
    labelStyle: t.labelMedium?.copyWith(color: c.textSecondaryDark),
    secondaryLabelStyle: t.labelMedium?.copyWith(color: c.primaryLight),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    side: BorderSide(color: c.borderDark), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

SnackBarThemeData _buildSnackBarTheme(DefaultColors c, TextTheme t) {
  return SnackBarThemeData(
    backgroundColor: c.textPrimary, contentTextStyle: t.bodyMedium?.copyWith(color: c.surface),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating,
  );
}

SnackBarThemeData _buildSnackBarThemeDark(DefaultColors c, TextTheme t) {
  return SnackBarThemeData(
    backgroundColor: c.surfaceElevatedDark, contentTextStyle: t.bodyMedium?.copyWith(color: c.textPrimaryDark),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating,
  );
}

DialogThemeData _buildDialogTheme(DefaultColors c, TextTheme t, DefaultSpacing s) {
  return DialogThemeData(
    elevation: 8, backgroundColor: c.surface, surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: s.borderRadiusLg),
    titleTextStyle: t.titleLarge?.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
    contentTextStyle: t.bodyMedium?.copyWith(color: c.textSecondary),
  );
}

DialogThemeData _buildDialogThemeDark(DefaultColors c, TextTheme t, DefaultSpacing s) {
  return DialogThemeData(
    elevation: 8, backgroundColor: c.surfaceDark, surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: s.borderRadiusLg),
    titleTextStyle: t.titleLarge?.copyWith(color: c.textPrimaryDark, fontWeight: FontWeight.w600),
    contentTextStyle: t.bodyMedium?.copyWith(color: c.textSecondaryDark),
  );
}

BottomSheetThemeData _buildBottomSheetTheme(DefaultColors c, DefaultSpacing s) {
  return BottomSheetThemeData(
    backgroundColor: c.surface, surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  );
}

BottomSheetThemeData _buildBottomSheetThemeDark(DefaultColors c, DefaultSpacing s) {
  return BottomSheetThemeData(
    backgroundColor: c.surfaceDark, surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  );
}

TabBarThemeData _buildTabBarTheme(DefaultColors c, TextTheme t) {
  return TabBarThemeData(
    labelColor: c.primary, unselectedLabelColor: c.textSecondary,
    labelStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600), unselectedLabelStyle: t.labelLarge,
    indicator: UnderlineTabIndicator(borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2), borderRadius: BorderRadius.circular(1)),
    indicatorSize: TabBarIndicatorSize.label,
  );
}

TabBarThemeData _buildTabBarThemeDark(DefaultColors c, TextTheme t) {
  return TabBarThemeData(
    labelColor: c.primaryLight, unselectedLabelColor: c.textSecondaryDark,
    labelStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600), unselectedLabelStyle: t.labelLarge,
    indicator: UnderlineTabIndicator(borderSide: BorderSide(color: c.primaryLight, width: 2), borderRadius: BorderRadius.circular(1)),
    indicatorSize: TabBarIndicatorSize.label,
  );
}
