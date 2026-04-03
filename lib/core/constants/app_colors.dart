import 'package:flutter/material.dart';

class AppColors {
  // ── Brand Core ──────────────────────────────────────────────
  static const electricBlue = Color(0xFF007BFF);
  static const neonGreen = Color(0xFF00E676);

  // ── Dark Background System ──────────────────────────────────
  static const darkBg = Color(0xFF050A18);
  static const darkBg2 = Color(0xFF0A1628);
  static const darkBg3 = Color(0xFF0F1E35);
  static const cardBg = Color(0x1AFFFFFF);
  static const cardBorder = Color(0x33007BFF);

  // ── Gradient Palettes ────────────────────────────────────────
  static const List<Color> primaryGradient = [
    Color(0xFF007BFF),
    Color(0xFF00E676),
  ];

  static const List<Color> blueGradient = [
    Color(0xFF0047FF),
    Color(0xFF007BFF),
  ];

  static const List<Color> greenGradient = [
    Color(0xFF00C853),
    Color(0xFF00E676),
  ];

  static const List<Color> purpleAccent = [
    Color(0xFF7C3AED),
    Color(0xFF007BFF),
  ];

  static const List<Color> dangerGradient = [
    Color(0xFFFF1744),
    Color(0xFFFF5252),
  ];

  static const List<Color> warningGradient = [
    Color(0xFFFF6D00),
    Color(0xFFFFAB00),
  ];

  static const List<Color> darkGlassGradient = [
    Color(0x33007BFF),
    Color(0x1A00E676),
  ];

  // ── Crowd Density Colors ─────────────────────────────────────
  static const crowdLow = Color(0xFF00E676);    // Green
  static const crowdMedium = Color(0xFFFFAB00); // Amber
  static const crowdHigh = Color(0xFFFF1744);   // Red

  // ── Text Colors ──────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0BEC5);
  static const textMuted = Color(0xFF546E7A);

  // ── Status Colors ────────────────────────────────────────────
  static const statusWaiting = Color(0xFFFFAB00);
  static const statusCalled = Color(0xFF007BFF);
  static const statusServing = Color(0xFF00E676);
  static const statusCompleted = Color(0xFF546E7A);
  static const statusCancelled = Color(0xFFFF1744);
  static const statusExpired = Color(0xFF795548);

  // ── Glass morphism ───────────────────────────────────────────
  static const glassBg = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x40FFFFFF);
  static const glassBlue = Color(0x26007BFF);
  static const glassGreen = Color(0x2600E676);
}