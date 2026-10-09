import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 人情记视觉令牌：玉色雾面、纸感层次，避免通用紫渐变与默认系统字体感。
abstract final class AppColors {
  static const jade = Color(0xFF0F5C4C);
  static const jadeDeep = Color(0xFF0A4036);
  static const jadeSoft = Color(0xFFD7E8E2);
  static const mist = Color(0xFFF2F6F4);
  static const mistDeep = Color(0xFFE4EDE8);
  static const ink = Color(0xFF1A2421);
  static const inkMuted = Color(0xFF5C6B65);
  static const amber = Color(0xFFB86A2D);
  static const receive = Color(0xFF0F5C4C);
  static const give = Color(0xFF8A5A2B);
  static const line = Color(0x1A0F5C4C);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.jade,
    onPrimary: Colors.white,
    primaryContainer: AppColors.jadeSoft,
    onPrimaryContainer: AppColors.jadeDeep,
    secondary: AppColors.amber,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF3E2D2),
    onSecondaryContainer: Color(0xFF4A2E12),
    surface: AppColors.mist,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    error: Color(0xFFB3261E),
    onError: Colors.white,
    outline: Color(0xFF9AAEA5),
    outlineVariant: Color(0xFFD0DDD6),
    surfaceContainerHighest: Color(0xFFE8F0EC),
  );

  final serif = GoogleFonts.notoSerifScTextTheme();
  final sans = GoogleFonts.notoSansScTextTheme();

  final textTheme = sans.copyWith(
    displaySmall: serif.displaySmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: AppColors.ink,
      height: 1.2,
    ),
    headlineMedium: serif.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.25,
    ),
    headlineSmall: serif.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleLarge: serif.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleMedium: sans.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleSmall: sans.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: sans.bodyLarge?.copyWith(color: AppColors.ink, height: 1.45),
    bodyMedium: sans.bodyMedium?.copyWith(color: AppColors.ink, height: 1.45),
    bodySmall: sans.bodySmall?.copyWith(color: AppColors.inkMuted, height: 1.4),
    labelLarge: sans.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    labelMedium: sans.labelMedium?.copyWith(color: AppColors.inkMuted),
    labelSmall: sans.labelSmall?.copyWith(color: AppColors.inkMuted),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: textTheme.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.jadeSoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? AppColors.jade : AppColors.inkMuted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.jade : AppColors.inkMuted,
          size: 22,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.jade,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.jade,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.jadeDeep,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: Color(0x660F5C4C)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.jade, width: 1.4),
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.7),
      selectedColor: AppColors.jadeSoft,
      side: const BorderSide(color: AppColors.line),
      labelStyle: textTheme.labelMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.inkMuted,
        height: 1.5,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
  );
}
