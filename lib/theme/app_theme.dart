import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Njangi-Pay design tokens.
///
/// Palette grounded in Ndop cloth (indigo), a Cameroonian textile tied to
/// communal/ceremonial contexts â€” chosen deliberately over a generic
/// fintech blue to reflect the app's roots in a real community practice.
/// Colors are unchanged from earlier passes on purpose -- this file is a
/// polish pass on typography, elevation, and shape, not a repaint.
class AppColors {
  AppColors._();

  // Primary â€” trust, structure
  static const indigo = Color(0xFF22345C);
  static const indigoLight = Color(0xFF3A4F7E);

  // Accent â€” money, contributions, the rotation wheel
  static const gold = Color(0xFFC89B3C);
  static const goldLight = Color(0xFFE0BE6E);

  // Background â€” warm parchment, ledger-paper feel without being literal
  static const parchment = Color(0xFFF7F3EA);
  static const parchmentDeep = Color(0xFFEDE6D6);

  // Status
  static const green = Color(0xFF2F5D50); // paid / verified / on-track
  static const clay = Color(0xFFB4522F); // overdue / fine / flagged

  static const ink = Color(0xFF1A1A1A);
  static const inkMuted = Color(0xFF5C5A54);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      brightness: Brightness.light,
      primary: AppColors.indigo,
      secondary: AppColors.gold,
      surface: AppColors.parchment,
      error: AppColors.clay,
    );

    // Serif display face for headings (a small editorial touch that reads
    // as more considered than the default sans everywhere), paired with a
    // clean geometric sans for body/UI text so it stays easy to scan.
    final displayFont = GoogleFonts.playfairDisplayTextTheme();
    final bodyFont = GoogleFonts.manropeTextTheme();

    final textTheme = bodyFont.copyWith(
      displaySmall: displayFont.displaySmall?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: displayFont.headlineMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 24,
      ),
      titleLarge: bodyFont.titleLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 17,
        letterSpacing: -0.2,
      ),
      titleMedium: bodyFont.titleMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: bodyFont.bodyMedium?.copyWith(color: AppColors.ink, height: 1.45),
      bodySmall: bodyFont.bodySmall?.copyWith(color: AppColors.inkMuted, height: 1.4),
      labelLarge: bodyFont.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.parchment,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: displayFont.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shadowColor: AppColors.indigo.withOpacity(0.10),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 1,
          shadowColor: AppColors.indigo.withOpacity(0.35),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.indigo,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          side: const BorderSide(color: AppColors.parchmentDeep, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.indigo,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.parchmentDeep),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.parchmentDeep),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.indigo, width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColors.inkMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.parchmentDeep,
        labelStyle: const TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w600, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 3,
        highlightElevation: 5,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      dividerColor: AppColors.parchmentDeep,
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }

  /// Status color helper â€” used consistently across ledger, loans, reminders
  /// so "verified/paid" and "overdue/flagged" always mean the same color.
  static Color statusColor(String status) {
    switch (status) {
      case 'verified':
      case 'paid':
      case 'active':
      case 'on-track':
        return AppColors.green;
      case 'flagged':
      case 'overdue':
      case 'missed':
        return AppColors.clay;
      case 'pending':
        return AppColors.gold;
      default:
        return AppColors.inkMuted;
    }
  }
}