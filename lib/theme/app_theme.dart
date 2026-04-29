import 'package:flutter/material.dart';

import '../models/baby_profile.dart';

class AppTheme {
  static ThemeData light(AppThemeColor accent) {
    final primary = _primaryForAccent(accent);
    const background = Color(0xFFF4F5F7);
    const foreground = Color(0xFF171A1D);
    const secondary = Color(0xFFFFFFFF);
    const muted = Color(0xFFEDEFF2);
    const mutedForeground = Color(0xFF717182);
    const destructive = Color(0xFFD4183D);
    const border = Color(0x1A000000);
    const input = Color(0xFFFFFFFF);
    const card = Color(0xFFFFFFFF);

    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: foreground,
      error: destructive,
      onError: Colors.white,
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: mutedForeground,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black.withValues(alpha: 0.06),
      scrim: Colors.black54,
      inverseSurface: foreground,
      onInverseSurface: background,
      inversePrimary: primary.withValues(alpha: 0.82),
      surfaceContainerHighest: muted,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          height: 1.25,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: mutedForeground,
          height: 1.45,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: foreground,
        contentTextStyle: const TextStyle(color: background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        labelStyle: const TextStyle(
          color: mutedForeground,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: mutedForeground),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: foreground,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: card,
          foregroundColor: foreground,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.45);
          }
          return const Color(0xFFCBCED4);
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary.withValues(alpha: 0.12);
            }
            return card;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return foreground;
          }),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: card,
        collapsedBackgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        iconColor: mutedForeground,
        collapsedIconColor: mutedForeground,
        textColor: foreground,
        collapsedTextColor: foreground,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: background,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w500
                    : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  static ThemeData dark(AppThemeColor accent) {
    final primary = _primaryForAccent(accent, dark: true);
    const background = Color(0xFF17171B);
    const foreground = Color(0xFFFAFAFA);
    const secondary = Color(0xFF2A2A30);
    const muted = Color(0xFF2A2A30);
    const mutedForeground = Color(0xFFB0B2BD);
    const destructive = Color(0xFF7B2334);
    const border = Color(0xFF2F3037);
    const input = Color(0xFF2A2A30);
    const card = Color(0xFF17171B);

    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: const Color(0xFF17171B),
      secondary: secondary,
      onSecondary: foreground,
      error: destructive,
      onError: const Color(0xFFFFD7DD),
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: mutedForeground,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black54,
      scrim: Colors.black54,
      inverseSurface: foreground,
      onInverseSurface: background,
      inversePrimary: primary.withValues(alpha: 0.82),
      surfaceContainerHighest: muted,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          height: 1.25,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: card,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        labelStyle: const TextStyle(
          color: mutedForeground,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: mutedForeground),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF17171B),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: const BorderSide(color: border),
          backgroundColor: card,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: background,
        indicatorColor: primary.withValues(alpha: 0.18),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: card,
        collapsedBackgroundColor: card,
        iconColor: mutedForeground,
        collapsedIconColor: mutedForeground,
        textColor: foreground,
        collapsedTextColor: foreground,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: const TextStyle(color: Color(0xFF17171B)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static Color _primaryForAccent(AppThemeColor accent, {bool dark = false}) {
    return switch (accent) {
      AppThemeColor.blue =>
        dark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
      AppThemeColor.pink =>
        dark ? const Color(0xFFF9A8D4) : const Color(0xFFDB2777),
      AppThemeColor.mint =>
        dark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
    };
  }
}
