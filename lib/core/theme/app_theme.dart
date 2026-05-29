import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 12.0;
  static const spaceLg = 16.0;
  static const spaceXl = 24.0;
  static const space2xl = 32.0;
  static const space3xl = 48.0;

  static const radiusSm = 6.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 16.0;
  static const radiusFull = 999.0;

  static BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);

  static const durationFast = Duration(milliseconds: 150);
  static const durationNormal = Duration(milliseconds: 240);
  static const durationSlow = Duration(milliseconds: 360);

  static List<BoxShadow> get shadowSm => const [
    BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> get shadowMd => const [
    BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get shadowLg => const [
    BoxShadow(color: Color(0x16000000), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const _primary = Color(0xFF2563EB);
  static const _secondary = Color(0xFF0F766E);
  static const _tertiary = Color(0xFFB45309);
  static const _lightBackground = Color(0xFFF6F8FB);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _darkBackground = Color(0xFF0F172A);
  static const _darkSurface = Color(0xFF111827);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFF7BA7FF) : _primary,
          secondary: isDark ? const Color(0xFF5EEAD4) : _secondary,
          tertiary: isDark ? const Color(0xFFFBBF24) : _tertiary,
          surface: isDark ? _darkSurface : _lightSurface,
          onSurface: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
          surfaceContainerHighest: isDark
              ? const Color(0xFF1F2937)
              : const Color(0xFFE8EDF5),
          onSurfaceVariant: isDark
              ? const Color(0xFFAAB3C2)
              : const Color(0xFF4B5563),
          outline: isDark ? const Color(0xFF334155) : const Color(0xFFD6DDE8),
          outlineVariant: isDark
              ? const Color(0xFF263244)
              : const Color(0xFFE5EAF2),
        );
    final textTheme = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: isDark ? _darkBackground : _lightBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: _inputBorder(scheme.outline),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 1.4),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.4),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.10),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        pressElevation: 0,
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      dialogTheme: DialogThemeData(
        elevation: 16,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 12,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF111827),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFF111827) : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = Typography.material2021(
      platform: TargetPlatform.android,
      colorScheme: scheme,
    ).black;
    final color = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    TextStyle clean(TextStyle? style, Color c) {
      return (style ?? const TextStyle()).copyWith(color: c, letterSpacing: 0);
    }

    return base.copyWith(
      displayLarge: clean(
        base.displayLarge,
        color,
      ).copyWith(fontSize: 32, fontWeight: FontWeight.w800, height: 1.16),
      displayMedium: clean(
        base.displayMedium,
        color,
      ).copyWith(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
      displaySmall: clean(
        base.displaySmall,
        color,
      ).copyWith(fontSize: 24, fontWeight: FontWeight.w800, height: 1.24),
      headlineLarge: clean(
        base.headlineLarge,
        color,
      ).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
      headlineMedium: clean(
        base.headlineMedium,
        color,
      ).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      headlineSmall: clean(
        base.headlineSmall,
        color,
      ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleLarge: clean(
        base.titleLarge,
        color,
      ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: clean(
        base.titleMedium,
        color,
      ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: clean(
        base.titleSmall,
        color,
      ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: clean(
        base.bodyLarge,
        color,
      ).copyWith(fontSize: 16, height: 1.5),
      bodyMedium: clean(
        base.bodyMedium,
        color,
      ).copyWith(fontSize: 14, height: 1.5),
      bodySmall: clean(
        base.bodySmall,
        muted,
      ).copyWith(fontSize: 12, height: 1.45),
      labelLarge: clean(
        base.labelLarge,
        color,
      ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: clean(
        base.labelMedium,
        muted,
      ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
      labelSmall: clean(
        base.labelSmall,
        muted,
      ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
    );
  }
}
