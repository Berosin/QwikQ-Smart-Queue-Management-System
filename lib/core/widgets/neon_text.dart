import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

// ── Static neon text with glow shadow ─────────────────────────
class NeonText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final double glowRadius;
  final bool useRajdhani;

  const NeonText(
    this.text, {
    super.key,
    this.color = AppColors.electricBlue,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w700,
    this.textAlign = TextAlign.start,
    this.glowRadius = 12,
    this.useRajdhani = true,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: AppTextStyles.neonGlow(color, size: fontSize).copyWith(
        fontWeight: fontWeight,
        shadows: [
          Shadow(color: color.withOpacity(0.9), blurRadius: glowRadius),
          Shadow(color: color.withOpacity(0.5), blurRadius: glowRadius * 2),
          Shadow(color: color.withOpacity(0.2), blurRadius: glowRadius * 4),
        ],
      ),
    );
  }
}

// ── Pulsing neon text (for live indicators) ───────────────────
class PulsingNeonText extends StatefulWidget {
  final String text;
  final Color color;
  final double fontSize;

  const PulsingNeonText(
    this.text, {
    super.key,
    this.color = AppColors.neonGreen,
    this.fontSize = 16,
  });

  @override
  State<PulsingNeonText> createState() => _PulsingNeonTextState();
}

class _PulsingNeonTextState extends State<PulsingNeonText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glow = Tween(begin: 6.0, end: 20.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Text(
        widget.text,
        style: AppTextStyles.neonGlow(widget.color, size: widget.fontSize).copyWith(
          shadows: [
            Shadow(color: widget.color.withOpacity(0.9), blurRadius: _glow.value),
            Shadow(color: widget.color.withOpacity(0.4), blurRadius: _glow.value * 2),
          ],
        ),
      ),
    );
  }
}

// ── Gradient shimmer text ─────────────────────────────────────
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;
  final TextAlign textAlign;

  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.colors = AppColors.primaryGradient,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        style: (style ?? AppTextStyles.headlineLarge).copyWith(color: Colors.white),
      ),
    );
  }
}

// ── Animated counting number ──────────────────────────────────
class AnimatedCountText extends StatelessWidget {
  final int value;
  final Color color;
  final double fontSize;
  final String? suffix;
  final String? prefix;

  const AnimatedCountText({
    super.key,
    required this.value,
    this.color = AppColors.electricBlue,
    this.fontSize = 28,
    this.suffix,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (_, animValue, __) {
        return NeonText(
          '${prefix ?? ''}$animValue${suffix ?? ''}',
          color: color,
          fontSize: fontSize,
        );
      },
    );
  }
}

// ── Status label with coloured dot ────────────────────────────
class StatusLabel extends StatelessWidget {
  final String status;
  final Color color;
  final bool pulsing;

  const StatusLabel({
    super.key,
    required this.status,
    required this.color,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 6)],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pulsing
            ? dot
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.5, duration: 800.ms)
                .fadeIn()
            : dot,
        const SizedBox(width: 6),
        Text(
          status.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Token number big display ──────────────────────────────────
class TokenDisplay extends StatelessWidget {
  final int tokenNumber;
  final Color color;
  final double size;
  final bool animate;

  const TokenDisplay({
    super.key,
    required this.tokenNumber,
    this.color = AppColors.neonGreen,
    this.size = 80,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final widget = NeonText(
      '$tokenNumber',
      color: color,
      fontSize: size,
      glowRadius: 20,
    );

    if (!animate) return widget;

    return widget
        .animate()
        .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1),
            duration: 600.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 300.ms);
  }
}