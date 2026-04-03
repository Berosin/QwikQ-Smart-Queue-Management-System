import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    final auth = ref.read(authServiceProvider);
    if (auth.isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Animated background particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(_particleController.value),
              size: MediaQuery.of(context).size,
            ),
          ),
          // Radial glow center
          Center(
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.electricBlue.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content: logo + slogan
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Splash logo
                Image.asset(
                  'assets/images/splash_logo.png', // <-- your splash image
                  width: 450, // Increased size to make it "very big"
                  height: 450,
                  fit: BoxFit.contain,
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.3, 0.3),
                      end: const Offset(1.0, 1.0),
                      duration: 700.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 12), // Reduced spacing slightly for the bigger logo

                // App name
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: AppColors.primaryGradient,
                  ).createShader(bounds),
                  child: Text(
                    'QwikQ',
                    style: AppTextStyles.displayMedium.copyWith(
                      color: Colors.white,
                      fontSize: 48,
                      letterSpacing: 4,
                    ),
                  ),
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 8),

                // Slogan
                Text(
                  'Skip the line. Save your time.', // <-- slogan
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                )
                    .animate(delay: 600.ms)
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 40), // Adjusted spacing

                // Loading indicator
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.neonGreen,
                    ),
                  ),
                )
                    .animate(delay: 900.ms)
                    .fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> _particles = List.generate(
    30,
    (i) => _Particle(seed: i),
  );

  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress + p.offset) % 1.0;
      final x = size.width * p.x;
      final y = size.height - (size.height * t * p.speed);
      final opacity = (sin(t * pi) * p.alpha).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = (p.isBlue ? AppColors.electricBlue : AppColors.neonGreen)
            .withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

class _Particle {
  final double x;
  final double offset;
  final double speed;
  final double alpha;
  final double radius;
  final bool isBlue;

  _Particle({required int seed})
      : x = (seed * 0.0731 + 0.1) % 1.0,
        offset = (seed * 0.137) % 1.0,
        speed = 0.3 + (seed % 5) * 0.14,
        alpha = 0.1 + (seed % 4) * 0.15,
        radius = 1.5 + (seed % 3) * 1.2,
        isBlue = seed % 2 == 0;
}
