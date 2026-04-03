import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../models/token_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/queue_service.dart';
import '../../providers/queue_provider.dart'; // ← add this


class LiveQueueScreen extends ConsumerStatefulWidget {
  final String tokenId;
  const LiveQueueScreen({super.key, required this.tokenId});

  @override
  ConsumerState<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends ConsumerState<LiveQueueScreen>
    with TickerProviderStateMixin {
  TokenModel? _token;
  int _currentQueueToken = 0;
  bool _isLoading = true;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  dynamic _tokenChannel;
  dynamic _queueChannel;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _initData();
  }

  Future<void> _initData() async {
    final service = ref.read(queueServiceProvider);
    // Subscribe to token updates
    _tokenChannel = service.watchToken(widget.tokenId, (token) {
      if (mounted) setState(() => _token = token);
    });
    // Load initial token data
    try {
      final tokens = await service.getUserActiveTokens(
        ref.read(userProfileProvider).value?.id ?? '',
      );
      final token = tokens.firstWhere(
        (t) => t.id == widget.tokenId,
        orElse: () => throw Exception('Token not found'),
      );
      if (mounted) {
        setState(() {
          _token = token;
          _currentQueueToken = token.currentQueueToken ?? 0;
          _isLoading = false;
        });
        // Subscribe to queue changes
        _queueChannel = service.watchQueue(token.shopId, (data) {
          if (mounted) {
            setState(() => _currentQueueToken = data['current_token'] ?? _currentQueueToken);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _tokenChannel?.unsubscribe();
    _queueChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
          : _token == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Token not found', style: TextStyle(color: Colors.white)),
                      TextButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Go Home'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final token = _token!;
    final position = (token.tokenNumber - _currentQueueToken).clamp(0, 999);
    final estimatedWait = token.estimatedWaitMinutes ?? (position * 5);

    return Stack(
      children: [
        _buildAnimatedBackground(),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 28),
                _buildStatusBanner(token),
                const SizedBox(height: 24),
                _buildTokenCircle(token, position, estimatedWait),
                const SizedBox(height: 24),
                _buildQueueProgress(token, position),
                const SizedBox(height: 20),
                _buildInfoRow(token, estimatedWait),
                const SizedBox(height: 20),
                _buildQrCode(token),
                const SizedBox(height: 20),
                if (token.isActive) _buildCancelButton(token),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        Container(color: AppColors.darkBg),
        AnimatedBuilder(
          animation: _rotateController,
          builder: (_, __) => Positioned(
            top: -100,
            right: -100 + sin(_rotateController.value * 2 * pi) * 20,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.electricBlue.withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _rotateController,
          builder: (_, __) => Positioned(
            bottom: -80,
            left: -80 + cos(_rotateController.value * 2 * pi) * 15,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.neonGreen.withOpacity(0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_token!.shopName ?? 'Queue', style: AppTextStyles.headlineMedium),
              Text('Live Queue Tracking', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        // Realtime dot
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.neonGreen.withOpacity(0.1 + _pulseController.value * 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neonGreen.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.neonGreen, blurRadius: 6 * _pulseController.value)],
                  ),
                ),
                const SizedBox(width: 5),
                const Text('LIVE', style: TextStyle(color: AppColors.neonGreen, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildStatusBanner(TokenModel token) {
    final isYourTurn = token.status == TokenStatus.called || token.status == TokenStatus.serving;
    if (!isYourTurn) return const SizedBox();

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.neonGreen.withOpacity(0.15 + _pulseController.value * 0.1),
              AppColors.electricBlue.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.neonGreen.withOpacity(0.5 + _pulseController.value * 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonGreen.withOpacity(0.3 * _pulseController.value),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('🔔', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.status == TokenStatus.called ? 'IT\'S YOUR TURN!' : 'YOU\'RE BEING SERVED',
                    style: AppTextStyles.neonGlow(AppColors.neonGreen, size: 16),
                  ),
                  Text('Please proceed to the counter now', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  Widget _buildTokenCircle(TokenModel token, int position, int estimatedWait) {
    final progress = position == 0 ? 1.0 : (1.0 / (position + 1)).clamp(0.0, 1.0);
    final statusColor = _statusColor(token.status);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 220 + _pulseController.value * 10,
              height: 220 + _pulseController.value * 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  statusColor.withOpacity(0.08 * _pulseController.value),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          CircularPercentIndicator(
            radius: 100,
            lineWidth: 8,
            percent: progress,
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: statusColor,
            backgroundColor: statusColor.withOpacity(0.1),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('TOKEN', style: AppTextStyles.labelSmall),
                Text('${token.tokenNumber}', style: AppTextStyles.tokenNumber),
                Text('~$estimatedWait min', style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    token.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), duration: 700.ms, curve: Curves.elasticOut);
  }

  Widget _buildQueueProgress(TokenModel token, int position) {
    return GlassCard(
      borderRadius: 16,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT', style: AppTextStyles.labelSmall),
                  Text('$_currentQueueToken',
                      style: AppTextStyles.neonGlow(AppColors.neonGreen, size: 28)),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.double_arrow, color: AppColors.electricBlue, size: 28),
                  Text('$position ahead', style: AppTextStyles.bodySmall),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('YOUR TOKEN', style: AppTextStyles.labelSmall),
                  Text('${token.tokenNumber}',
                      style: AppTextStyles.neonGlow(AppColors.electricBlue, size: 28)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Visual token bars
          _TokenBar(current: _currentQueueToken, target: token.tokenNumber),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn();
  }

  Widget _buildInfoRow(TokenModel token, int estimatedWait) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                const Icon(Icons.people_outline, color: AppColors.electricBlue, size: 22),
                const SizedBox(height: 6),
                Text('${token.groupSize}', style: AppTextStyles.neonGlow(AppColors.electricBlue, size: 18)),
                Text('in group', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.all(14),
            borderColor: AppColors.neonGreen.withOpacity(0.3),
            child: Column(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.neonGreen, size: 22),
                const SizedBox(height: 6),
                Text('~$estimatedWait', style: AppTextStyles.neonGlow(AppColors.neonGreen, size: 18)),
                Text('minutes', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                const Icon(Icons.confirmation_number_outlined,
                    color: AppColors.statusWaiting, size: 22),
                const SizedBox(height: 6),
                Text(
                  token.isPriority ? 'PRIO' : 'STD',
                  style: AppTextStyles.neonGlow(AppColors.statusWaiting, size: 18),
                ),
                Text('priority', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ),
      ],
    ).animate(delay: 300.ms).fadeIn();
  }

  Widget _buildQrCode(TokenModel token) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, color: AppColors.electricBlue, size: 20),
              const SizedBox(width: 8),
              Text('Entry QR Code', style: AppTextStyles.bodyLarge),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: token.qrCode ?? token.id,
              version: QrVersions.auto,
              size: 140,
              foregroundColor: AppColors.darkBg,
            ),
          ),
          const SizedBox(height: 12),
          Text('Show this to the staff when called',
              style: AppTextStyles.bodySmall),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn();
  }

  Widget _buildCancelButton(TokenModel token) {
    return GradientButton(
      label: 'Cancel Token',
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.darkBg2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Cancel Token?', style: TextStyle(color: Colors.white)),
            content: Text(
              'Are you sure you want to cancel token #${token.tokenNumber}?',
              style: AppTextStyles.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No, Keep It'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          await ref.read(queueServiceProvider).cancelToken(token.id);
          context.go('/home');
        }
      },
      colors: AppColors.dangerGradient,
      outlined: true,
    ).animate(delay: 500.ms).fadeIn();
  }

  Color _statusColor(TokenStatus status) {
    return switch (status) {
      TokenStatus.waiting => AppColors.statusWaiting,
      TokenStatus.called => AppColors.electricBlue,
      TokenStatus.serving => AppColors.neonGreen,
      TokenStatus.completed => AppColors.statusCompleted,
      _ => AppColors.textMuted,
    };
  }
}

class _TokenBar extends StatelessWidget {
  final int current;
  final int target;

  const _TokenBar({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final visibleRange = 7;
    final start = current;
    final end = (target + 2).clamp(start, start + visibleRange * 2);
    final tokens = List.generate(end - start + 1, (i) => start + i);

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tokens.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final t = tokens[i];
          final isCurrent = t == current;
          final isTarget = t == target;
          Color color;
          if (isCurrent) color = AppColors.neonGreen;
          else if (isTarget) color = AppColors.electricBlue;
          else if (t < target) color = AppColors.textMuted;
          else color = AppColors.textMuted.withOpacity(0.3);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isTarget || isCurrent ? 36 : 28,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(isCurrent || isTarget ? 0.2 : 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(isCurrent || isTarget ? 0.7 : 0.2)),
              boxShadow: (isCurrent || isTarget)
                  ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: Text(
                '$t',
                style: TextStyle(
                  color: color,
                  fontSize: isCurrent || isTarget ? 12 : 10,
                  fontWeight: isCurrent || isTarget ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}