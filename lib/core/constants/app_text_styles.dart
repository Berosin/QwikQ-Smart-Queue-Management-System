import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Display
  static TextStyle get displayLarge => GoogleFonts.rajdhani(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 1.5,
      );

  static TextStyle get displayMedium => GoogleFonts.rajdhani(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 1.2,
      );

  // Headline
  static TextStyle get headlineLarge => GoogleFonts.rajdhani(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      );

  static TextStyle get headlineMedium => GoogleFonts.rajdhani(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // Token Number (big display)
  static TextStyle get tokenNumber => GoogleFonts.rajdhani(
        fontSize: 80,
        fontWeight: FontWeight.w700,
        color: AppColors.neonGreen,
        letterSpacing: -2,
        shadows: [
          Shadow(
            color: AppColors.neonGreen.withOpacity(0.6),
            blurRadius: 20,
          ),
        ],
      );

  // Body
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textMuted,
      );

  // Label
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
        textBaseline: TextBaseline.alphabetic,
      );

  // Neon glow text
  static TextStyle neonGlow(Color color, {double size = 18}) => GoogleFonts.rajdhani(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        shadows: [
          Shadow(color: color.withOpacity(0.8), blurRadius: 12),
          Shadow(color: color.withOpacity(0.4), blurRadius: 24),
        ],
      );
}