import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style_base.dart';
import 'colors.dart';

/// ============================================================
/// 黏土风 - 间距与圆角常量
/// ============================================================

class ClaySpacing implements SpacingPack {
  const ClaySpacing();

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

  // ─── 圆角常量 (黏土风需要超大圆角，像鹅卵石) ────────────────
  @override
  double get radiusSm => 12.0;
  @override
  double get radiusMd => 20.0;
  @override
  double get radiusLg => 32.0;
  @override
  double get radiusXl => 40.0;
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
  Duration get durationFast => const Duration(milliseconds: 100);
  @override
  Duration get durationNormal => const Duration(milliseconds: 200);
  @override
  Duration get durationSlow => const Duration(milliseconds: 400);

  // ─── 黏土风核心阴影 ────────────────────────────────────────
  /// 右下角的柔和暗面阴影 + 左上角的强高光
  List<BoxShadow> get clayShadow => [
        BoxShadow(
          color: const ClayColors().shadowDark,
          blurRadius: 12,
          offset: const Offset(6, 6),
        ),
        BoxShadow(
          color: Colors.white,
          blurRadius: 10,
          offset: const Offset(-6, -6),
        ),
      ];

  /// 深色模式黏土阴影
  List<BoxShadow> get clayShadowDark => [
        BoxShadow(
          color: const ClayColors().shadowDarkNight,
          blurRadius: 12,
          offset: const Offset(6, 6),
        ),
        BoxShadow(
          color: const ClayColors().shadowLightNight,
          blurRadius: 10,
          offset: const Offset(-4, -4),
        ),
      ];

  /// 按钮按压下去的"内凹"效果
  List<BoxShadow> get clayShadowPressed => [
        BoxShadow(
          color: const ClayColors().shadowDark,
          blurRadius: 4,
          offset: const Offset(2, 2),
        ),
        BoxShadow(
          color: Colors.white,
          blurRadius: 4,
          offset: const Offset(-2, -2),
        ),
      ];

  /// 浅色模式标准阴影
  List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: const ClayColors().shadowDark,
          blurRadius: 4,
          offset: const Offset(2, 2),
        ),
      ];

  List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: const ClayColors().shadowDark,
          blurRadius: 8,
          offset: const Offset(4, 4),
        ),
        const BoxShadow(
          color: Colors.white,
          blurRadius: 6,
          offset: Offset(-3, -3),
        ),
      ];

  List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: const ClayColors().shadowDark,
          blurRadius: 16,
          offset: const Offset(8, 8),
        ),
        const BoxShadow(
          color: Colors.white,
          blurRadius: 12,
          offset: Offset(-6, -6),
        ),
      ];

  List<BoxShadow> get shadowPrimary => [
        BoxShadow(
          color: const ClayColors().primary.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
}

/// 黏土风完整包
class ClayStylePack extends StylePack {
  ClayStylePack();

  @override
  String get id => StyleIds.clay;

  @override
  StyleMeta get meta => const StyleMeta(
        id: StyleIds.clay,
        name: '黏土风',
        description: '柔和糖果感，微凸体积感，像鹅卵石一样圆润',
      );

  @override
  ThemeData get lightTheme => _buildLightTheme();
  @override
  ThemeData get darkTheme => _buildDarkTheme();
}

ThemeData _buildLightTheme() {
  final colors = const ClayColors();
  final spacing = const ClaySpacing();
  final textTheme = _buildTextTheme(colors);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: Brightness.light,
    primary: colors.primary,
    onPrimary: colors.textOnPrimary,
    primaryContainer: colors.primaryLight.withValues(alpha: 0.2),
    onPrimaryContainer: colors.primaryDark,
    secondary: colors.secondary,
    onSecondary: colors.textOnPrimary,
    secondaryContainer: colors.secondaryLight.withValues(alpha: 0.2),
    onSecondaryContainer: colors.secondary,
    tertiary: colors.accent,
    onTertiary: colors.textOnPrimary,
    tertiaryContainer: colors.accentLight.withValues(alpha: 0.2),
    onTertiaryContainer: colors.accent,
    error: colors.error,
    onError: colors.textOnPrimary,
    errorContainer: colors.errorLight.withValues(alpha: 0.2),
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
    textTheme: textTheme.apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary),
    scaffoldBackgroundColor: colors.background,
    appBarTheme: _buildAppBarTheme(colors, textTheme, Brightness.light),
    cardTheme: _buildCardTheme(colors, spacing),
    elevatedButtonTheme: _buildElevatedButtonTheme(colors, textTheme),
    filledButtonTheme: _buildFilledButtonTheme(colors, textTheme),
    outlinedButtonTheme: _buildOutlinedButtonTheme(colors, textTheme),
    textButtonTheme: _buildTextButtonTheme(colors, textTheme),
    iconButtonTheme: _buildIconButtonTheme(colors),
    floatingActionButtonTheme: _buildFabTheme(colors, spacing),
    inputDecorationTheme: _buildInputTheme(colors, spacing, textTheme),
    navigationBarTheme: _buildNavBarTheme(colors, textTheme, Brightness.light),
    dividerTheme: _buildDividerTheme(colors),
    progressIndicatorTheme: _buildProgressTheme(colors),
    chipTheme: _buildChipTheme(colors, textTheme),
    snackBarTheme: _buildSnackBarTheme(colors, textTheme),
    dialogTheme: _buildDialogTheme(colors, textTheme, spacing),
    bottomSheetTheme: _buildBottomSheetTheme(colors, spacing),
    tabBarTheme: _buildTabBarTheme(colors, textTheme),
  );
}

ThemeData _buildDarkTheme() {
  final colors = const ClayColors();
  final spacing = const ClaySpacing();
  final textTheme = _buildTextThemeDark(colors);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: Brightness.dark,
    primary: colors.primaryLight,
    onPrimary: colors.backgroundDark,
    primaryContainer: colors.primaryDark.withValues(alpha: 0.4),
    onPrimaryContainer: colors.primaryLight,
    secondary: colors.secondaryLight,
    onSecondary: colors.backgroundDark,
    secondaryContainer: colors.secondary.withValues(alpha: 0.4),
    onSecondaryContainer: colors.secondaryLight,
    tertiary: colors.accentLight,
    onTertiary: colors.backgroundDark,
    tertiaryContainer: colors.accent.withValues(alpha: 0.4),
    onTertiaryContainer: colors.accentLight,
    error: colors.errorLight,
    onError: colors.backgroundDark,
    errorContainer: colors.error.withValues(alpha: 0.4),
    onErrorContainer: colors.errorLight,
    surface: colors.surfaceDark,
    onSurface: colors.textPrimaryDark,
    surfaceContainerHighest: colors.surfaceContainerHighDark,
    onSurfaceVariant: colors.textSecondaryDark,
    outline: colors.borderDark,
    outlineVariant: colors.borderDark.withValues(alpha: 0.5),
    shadow: colors.shadowDarkNight,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Noto Sans SC',
    textTheme: textTheme.apply(bodyColor: colors.textPrimaryDark, displayColor: colors.textPrimaryDark),
    scaffoldBackgroundColor: colors.backgroundDark,
    appBarTheme: _buildAppBarTheme(colors, textTheme, Brightness.dark),
    cardTheme: _buildCardThemeDark(colors, spacing),
    elevatedButtonTheme: _buildElevatedButtonThemeDark(colors, textTheme),
    filledButtonTheme: _buildFilledButtonThemeDark(colors, textTheme),
    outlinedButtonTheme: _buildOutlinedButtonThemeDark(colors, textTheme),
    textButtonTheme: _buildTextButtonThemeDark(colors, textTheme),
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

TextTheme _buildTextTheme(ClayColors c) => TextTheme(
  displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.02, height: 1.2, color: c.textPrimary),
  displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.01, height: 1.25, color: c.textPrimary),
  displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.01, height: 1.3, color: c.textPrimary),
  headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.35, color: c.textPrimary),
  headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimary),
  headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimary),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimary),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, color: c.textPrimary),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5, color: c.textPrimary),
  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: c.textPrimary),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: c.textPrimary),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.01, height: 1.5, color: c.textSecondary),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimary),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimary),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.02, height: 1.4, color: c.textSecondary),
);

TextTheme _buildTextThemeDark(ClayColors c) => TextTheme(
  displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.02, height: 1.2, color: c.textPrimaryDark),
  displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.01, height: 1.25, color: c.textPrimaryDark),
  displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.01, height: 1.3, color: c.textPrimaryDark),
  headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.35, color: c.textPrimaryDark),
  headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimaryDark),
  headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimaryDark),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: c.textPrimaryDark),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, color: c.textPrimaryDark),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5, color: c.textPrimaryDark),
  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: c.textPrimaryDark),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: c.textPrimaryDark),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.01, height: 1.5, color: c.textSecondaryDark),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimaryDark),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: c.textPrimaryDark),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.02, height: 1.4, color: c.textSecondaryDark),
);

AppBarTheme _buildAppBarTheme(ClayColors c, TextTheme t, Brightness brightness) {
  final bgColor = brightness == Brightness.dark ? c.backgroundDark : c.background;
  final fgColor = brightness == Brightness.dark ? c.textPrimaryDark : c.textPrimary;
  return AppBarTheme(
    elevation: 0, scrolledUnderElevation: 0.5, backgroundColor: bgColor, foregroundColor: fgColor,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    titleTextStyle: t.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: fgColor),
    iconTheme: IconThemeData(color: fgColor, size: 24),
  );
}

CardThemeData _buildCardTheme(ClayColors c, ClaySpacing s) => CardThemeData(
  elevation: 0, color: c.surface, surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(borderRadius: s.borderRadiusMd), margin: EdgeInsets.zero,
);

CardThemeData _buildCardThemeDark(ClayColors c, ClaySpacing s) => CardThemeData(
  elevation: 0, color: c.surfaceDark, surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(borderRadius: s.borderRadiusMd), margin: EdgeInsets.zero,
);

ElevatedButtonThemeData _buildElevatedButtonTheme(ClayColors c, TextTheme t) => ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    elevation: 0, backgroundColor: c.primary, foregroundColor: c.textOnPrimary,
    minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: t.labelLarge?.copyWith(color: c.textOnPrimary, fontWeight: FontWeight.w600),
  ),
);

ElevatedButtonThemeData _buildElevatedButtonThemeDark(ClayColors c, TextTheme t) => ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    elevation: 0, backgroundColor: c.primaryLight, foregroundColor: c.backgroundDark,
    minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: t.labelLarge?.copyWith(color: c.backgroundDark, fontWeight: FontWeight.w600),
  ),
);

FilledButtonThemeData _buildFilledButtonTheme(ClayColors c, TextTheme t) => FilledButtonThemeData(
  style: FilledButton.styleFrom(
    elevation: 0, backgroundColor: c.primary, foregroundColor: c.textOnPrimary,
    minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: t.labelLarge?.copyWith(color: c.textOnPrimary, fontWeight: FontWeight.w600),
  ),
);

FilledButtonThemeData _buildFilledButtonThemeDark(ClayColors c, TextTheme t) => FilledButtonThemeData(
  style: FilledButton.styleFrom(
    elevation: 0, backgroundColor: c.primaryLight, foregroundColor: c.backgroundDark,
    minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: t.labelLarge?.copyWith(color: c.backgroundDark, fontWeight: FontWeight.w600),
  ),
);

OutlinedButtonThemeData _buildOutlinedButtonTheme(ClayColors c, TextTheme t) => OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    elevation: 0, foregroundColor: c.primary,
    minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide(color: c.primary, width: 1.5),
    textStyle: t.labelLarge?.copyWith(color: c.primary, fontWeight: FontWeight.w600),
  ),
);

OutlinedButtonThemeData _buildOutlinedButtonThemeDark(ClayColors c, TextTheme t) => OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    elevation: 0, foregroundColor: c.primaryLight,
    minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide(color: c.primaryLight, width: 1.5),
    textStyle: t.labelLarge?.copyWith(color: c.primaryLight, fontWeight: FontWeight.w600),
  ),
);

TextButtonThemeData _buildTextButtonTheme(ClayColors c, TextTheme t) => TextButtonThemeData(
  style: TextButton.styleFrom(
    foregroundColor: c.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    textStyle: t.labelLarge?.copyWith(color: c.primary, fontWeight: FontWeight.w500),
  ),
);

TextButtonThemeData _buildTextButtonThemeDark(ClayColors c, TextTheme t) => TextButtonThemeData(
  style: TextButton.styleFrom(
    foregroundColor: c.primaryLight, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    textStyle: t.labelLarge?.copyWith(color: c.primaryLight, fontWeight: FontWeight.w500),
  ),
);

IconButtonThemeData _buildIconButtonTheme(ClayColors c) => IconButtonThemeData(
  style: IconButton.styleFrom(foregroundColor: c.textSecondary, minimumSize: const Size(44, 44)),
);

IconButtonThemeData _buildIconButtonThemeDark(ClayColors c) => IconButtonThemeData(
  style: IconButton.styleFrom(foregroundColor: c.textSecondaryDark, minimumSize: const Size(44, 44)),
);

FloatingActionButtonThemeData _buildFabTheme(ClayColors c, ClaySpacing s) => FloatingActionButtonThemeData(
  elevation: 4, backgroundColor: c.primary, foregroundColor: c.textOnPrimary,
  shape: RoundedRectangleBorder(borderRadius: s.borderRadiusMd),
);

FloatingActionButtonThemeData _buildFabThemeDark(ClayColors c, ClaySpacing s) => FloatingActionButtonThemeData(
  elevation: 4, backgroundColor: c.primaryLight, foregroundColor: c.backgroundDark,
  shape: RoundedRectangleBorder(borderRadius: s.borderRadiusMd),
);

InputDecorationTheme _buildInputTheme(ClayColors c, ClaySpacing s, TextTheme t) => InputDecorationTheme(
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

InputDecorationTheme _buildInputThemeDark(ClayColors c, ClaySpacing s, TextTheme t) => InputDecorationTheme(
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

NavigationBarThemeData _buildNavBarTheme(ClayColors c, TextTheme t, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return NavigationBarThemeData(
    elevation: 0, height: 80,
    backgroundColor: (isDark ? c.surfaceDark : c.surface).withValues(alpha: 0.9),
    surfaceTintColor: Colors.transparent, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    indicatorColor: (isDark ? c.primaryDark : c.primaryLight).withValues(alpha: 0.2),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final color = isDark ? c.primaryLight : c.primary;
      return IconThemeData(color: states.contains(WidgetState.selected) ? color : (isDark ? c.textSecondaryDark : c.textSecondary), size: 24);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final color = isDark ? c.primaryLight : c.primary;
      return t.labelSmall?.copyWith(
        color: states.contains(WidgetState.selected) ? color : (isDark ? c.textSecondaryDark : c.textSecondary),
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
      );
    }),
  );
}

DividerThemeData _buildDividerTheme(ClayColors c) => DividerThemeData(color: c.divider, thickness: 1, space: 1);
DividerThemeData _buildDividerThemeDark(ClayColors c) => DividerThemeData(color: c.dividerDark, thickness: 1, space: 1);

ProgressIndicatorThemeData _buildProgressTheme(ClayColors c) => ProgressIndicatorThemeData(
  color: c.primary, linearTrackColor: c.surfaceContainerHigh, circularTrackColor: c.surfaceContainerHigh,
);

ProgressIndicatorThemeData _buildProgressThemeDark(ClayColors c) => ProgressIndicatorThemeData(
  color: c.primaryLight, linearTrackColor: c.surfaceContainerHighDark, circularTrackColor: c.surfaceContainerHighDark,
);

ChipThemeData _buildChipTheme(ClayColors c, TextTheme t) => ChipThemeData(
  elevation: 0, pressElevation: 0, backgroundColor: c.surfaceContainer,
  selectedColor: c.primaryLight.withValues(alpha: 0.2),
  labelStyle: t.labelMedium?.copyWith(color: c.textSecondary),
  secondaryLabelStyle: t.labelMedium?.copyWith(color: c.primary),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  side: BorderSide.none, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
);

ChipThemeData _buildChipThemeDark(ClayColors c, TextTheme t) => ChipThemeData(
  elevation: 0, pressElevation: 0, backgroundColor: c.surfaceElevatedDark,
  selectedColor: c.primaryDark.withValues(alpha: 0.4),
  labelStyle: t.labelMedium?.copyWith(color: c.textSecondaryDark),
  secondaryLabelStyle: t.labelMedium?.copyWith(color: c.primaryLight),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  side: BorderSide(color: c.borderDark), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
);

SnackBarThemeData _buildSnackBarTheme(ClayColors c, TextTheme t) => SnackBarThemeData(
  backgroundColor: c.textPrimary, contentTextStyle: t.bodyMedium?.copyWith(color: c.surface),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), behavior: SnackBarBehavior.floating,
);

SnackBarThemeData _buildSnackBarThemeDark(ClayColors c, TextTheme t) => SnackBarThemeData(
  backgroundColor: c.surfaceElevatedDark, contentTextStyle: t.bodyMedium?.copyWith(color: c.textPrimaryDark),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), behavior: SnackBarBehavior.floating,
);

DialogThemeData _buildDialogTheme(ClayColors c, TextTheme t, ClaySpacing s) => DialogThemeData(
  elevation: 8, backgroundColor: c.surface, surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(borderRadius: s.borderRadiusLg),
  titleTextStyle: t.titleLarge?.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
  contentTextStyle: t.bodyMedium?.copyWith(color: c.textSecondary),
);

DialogThemeData _buildDialogThemeDark(ClayColors c, TextTheme t, ClaySpacing s) => DialogThemeData(
  elevation: 8, backgroundColor: c.surfaceDark, surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(borderRadius: s.borderRadiusLg),
  titleTextStyle: t.titleLarge?.copyWith(color: c.textPrimaryDark, fontWeight: FontWeight.w600),
  contentTextStyle: t.bodyMedium?.copyWith(color: c.textSecondaryDark),
);

BottomSheetThemeData _buildBottomSheetTheme(ClayColors c, ClaySpacing s) => BottomSheetThemeData(
  backgroundColor: c.surface, surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
);

BottomSheetThemeData _buildBottomSheetThemeDark(ClayColors c, ClaySpacing s) => BottomSheetThemeData(
  backgroundColor: c.surfaceDark, surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
);

TabBarThemeData _buildTabBarTheme(ClayColors c, TextTheme t) => TabBarThemeData(
  labelColor: c.primary, unselectedLabelColor: c.textSecondary,
  labelStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600), unselectedLabelStyle: t.labelLarge,
  indicator: UnderlineTabIndicator(borderSide: BorderSide(color: c.primary, width: 3), borderRadius: BorderRadius.circular(2)),
  indicatorSize: TabBarIndicatorSize.label,
);

TabBarThemeData _buildTabBarThemeDark(ClayColors c, TextTheme t) => TabBarThemeData(
  labelColor: c.primaryLight, unselectedLabelColor: c.textSecondaryDark,
  labelStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600), unselectedLabelStyle: t.labelLarge,
  indicator: UnderlineTabIndicator(borderSide: BorderSide(color: c.primaryLight, width: 3), borderRadius: BorderRadius.circular(2)),
  indicatorSize: TabBarIndicatorSize.label,
);
