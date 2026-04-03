import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/neon_text.dart';
import '../../models/token_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/token_provider.dart';
import '../../services/review_service.dart';

class TokenDetailScreen extends ConsumerWidget {
  final String tokenId;
  const TokenDetailScreen({super.key, required this.tokenId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenAsync = ref.watch(liveTokenProvider(tokenId));
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: tokenAsync.when(
        data: (token) => token == null
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Token not found', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Go Home')),
              ]))
            : _Body(token: token),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricBlue)),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text('$e', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Go Home')),
        ])),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final TokenModel token;
  const _Body({required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = Helpers.statusColor(token.status.name);
    final position = token.positionInQueue.clamp(0, 999);
    final estWait = token.estimatedWaitMinutes ?? (position * 5);

    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: AppColors.darkBg,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16)),
        ),
        title: Text('Token #${token.tokenNumber}', style: AppTextStyles.headlineMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusLabel(status: token.isActive ? 'LIVE' : token.status.name, color: statusColor, pulsing: token.isActive),
          ),
        ],
      ),
      SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverList(delegate: SliverChildListDelegate([

          // Shop card
          GlassCard(
            borderRadius: 18,
            borderColor: statusColor.withOpacity(0.3),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Helpers.categoryIcon(token.shopCategory ?? ''),
                  size: 32,
                  color: AppColors.electricBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(token.shopName ?? 'Shop', style: AppTextStyles.headlineMedium),
                Text(DateFormat('EEE, d MMM · hh:mm a').format(token.createdAt), style: AppTextStyles.bodySmall),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(token.status.name.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ).animate().fadeIn(),

          const SizedBox(height: 20),

          // Big token number
          Center(child: Column(children: [
            Text('YOUR TOKEN NUMBER', style: AppTextStyles.labelSmall),
            const SizedBox(height: 8),
            TokenDisplay(tokenNumber: token.tokenNumber, color: statusColor, size: 80),
            if (token.isPriority) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: const Text('🚨 EMERGENCY PRIORITY',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ])).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 20),

          // 3 stat boxes
          Row(children: [
            Expanded(child: _StatBox(icon: Icons.tag_rounded, label: 'POSITION',
                value: position == 0 ? 'Now!' : Helpers.ordinal(position), color: statusColor)),
            const SizedBox(width: 12),
            Expanded(child: _StatBox(icon: Icons.timer_outlined, label: 'EST. WAIT',
                value: Helpers.formatWaitTime(estWait), color: AppColors.electricBlue)),
            const SizedBox(width: 12),
            Expanded(child: _StatBox(icon: Icons.people_outline, label: 'GROUP',
                value: '${token.groupSize}', color: AppColors.neonGreen)),
          ]).animate(delay: 150.ms).fadeIn(),

          const SizedBox(height: 20),

          // Timeline
          _Timeline(token: token).animate(delay: 200.ms).fadeIn(),

          const SizedBox(height: 20),

          // QR Code
          GlassCard(
            borderRadius: 20,
            child: Column(children: [
              Row(children: [
                const Icon(Icons.qr_code_2_rounded, color: AppColors.electricBlue, size: 20),
                const SizedBox(width: 8),
                Text('Entry QR Code', style: AppTextStyles.bodyLarge),
                const Spacer(),
                Text('Show at counter', style: AppTextStyles.bodySmall),
              ]),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(14),
                child: QrImageView(
                  data: token.qrCode ?? token.id,
                  version: QrVersions.auto,
                  size: 150,
                  foregroundColor: AppColors.darkBg,
                ),
              ),
              const SizedBox(height: 10),
              Text('Token ID: ${token.id.substring(0, 8).toUpperCase()}', style: AppTextStyles.bodySmall),
            ]),
          ).animate(delay: 250.ms).fadeIn(),

          const SizedBox(height: 20),

          // Action buttons
          if (token.isActive) ...[
            GradientButton(
              label: 'View Live Queue',
              onTap: () => context.push('/live-queue/${token.id}'),
              colors: AppColors.primaryGradient,
            ).animate(delay: 300.ms).fadeIn(),
            const SizedBox(height: 12),
            GradientButton(
              label: 'Cancel Token',
              outlined: true,
              colors: AppColors.dangerGradient,
              onTap: () async {
                final confirm = await Helpers.showConfirmDialog(
                  context, title: 'Cancel Token?',
                  message: 'Token #${token.tokenNumber} will be cancelled and removed from the queue.',
                  confirmLabel: 'Yes, Cancel', destructive: true,
                );
                if (confirm == true) {
                  await ref.read(queueServiceProvider).cancelToken(token.id);
                  // Refresh active tokens list immediately
                  ref.invalidate(activeTokensProvider);
                  if (context.mounted) context.go('/home');
                }
              },
            ).animate(delay: 350.ms).fadeIn(),
          ],

          // Completed — show rating
          if (token.status == TokenStatus.completed) ...[
            const SizedBox(height: 8),
            _RatingWidget(token: token),
          ],

          const SizedBox(height: 60),
        ])),
      ),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatBox({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 5),
      NeonText(value, color: color, fontSize: 15),
      const SizedBox(height: 2),
      Text(label, style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
    ]),
  );
}

class _Timeline extends StatelessWidget {
  final TokenModel token;
  const _Timeline({required this.token});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step('Booked', Icons.confirmation_number_outlined, AppColors.electricBlue, true, token.createdAt),
      _Step('Called', Icons.campaign_outlined, AppColors.statusWaiting,
          [TokenStatus.called, TokenStatus.serving, TokenStatus.completed].contains(token.status), null),
      _Step('Serving', Icons.play_circle_outline, AppColors.neonGreen,
          [TokenStatus.serving, TokenStatus.completed].contains(token.status), token.servedAt),
      _Step('Done', Icons.check_circle_outline, AppColors.neonGreen,
          token.status == TokenStatus.completed, token.completedAt),
    ];

    return GlassCard(
      borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timeline_rounded, color: AppColors.electricBlue, size: 18),
          const SizedBox(width: 8),
          Text('TOKEN JOURNEY', style: AppTextStyles.labelSmall),
        ]),
        const SizedBox(height: 14),
        ...steps.asMap().entries.map((e) {
          final s = e.value;
          final isLast = e.key == steps.length - 1;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.done ? s.color.withOpacity(0.2) : Colors.white10,
                  border: Border.all(color: s.done ? s.color : Colors.white24, width: s.done ? 1.5 : 1),
                ),
                child: Icon(s.icon, color: s.done ? s.color : AppColors.textMuted, size: 16),
              ),
              if (!isLast) Container(width: 2, height: 28, color: s.done ? s.color.withOpacity(0.4) : Colors.white12),
            ]),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.label, style: TextStyle(color: s.done ? Colors.white : AppColors.textMuted, fontWeight: s.done ? FontWeight.w600 : FontWeight.w400, fontSize: 14)),
                if (s.time != null) Text(DateFormat('hh:mm a').format(s.time!), style: AppTextStyles.bodySmall.copyWith(color: s.color)),
              ]),
            ),
          ]);
        }),
      ]),
    );
  }
}

class _Step {
  final String label;
  final IconData icon;
  final Color color;
  final bool done;
  final DateTime? time;
  const _Step(this.label, this.icon, this.color, this.done, this.time);
}

class _RatingWidget extends ConsumerStatefulWidget {
  final TokenModel token;
  const _RatingWidget({required this.token});

  @override
  ConsumerState<_RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends ConsumerState<_RatingWidget> {
  int _rating = 0;
  bool _submitted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingReview();
  }

  Future<void> _checkExistingReview() async {
    try {
      final review = await ReviewService().getReviewForToken(widget.token.id);
      if (review != null && mounted) {
        setState(() {
          _rating = review['rating'];
          _submitted = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _submitReview() async {
    if (_rating == 0) return;
    
    setState(() => _isLoading = true);
    try {
      final user = ref.read(userProfileProvider).value;
      if (user == null) throw Exception('User not found');

      await ReviewService().submitReview(
        shopId: widget.token.shopId,
        userId: user.id,
        tokenId: widget.token.id,
        rating: _rating,
      );

      if (mounted) {
        setState(() {
          _submitted = true;
          _isLoading = false;
        });
        Helpers.showSnack(context, 'Review submitted successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Helpers.showSnack(context, 'Failed to submit review: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return GlassCard(
        borderColor: AppColors.neonGreen.withOpacity(0.3),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_outline, color: AppColors.neonGreen, size: 20),
              const SizedBox(width: 8),
              Text('Your Review', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.neonGreen)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => Icon(
                i < _rating ? Icons.star_rounded : Icons.star_border_rounded, 
                color: Colors.amber, 
                size: 24,
              )),
            ),
          ],
        ),
      );
    }
    return GlassCard(
      borderRadius: 16,
      child: Column(children: [
        Text('Rate your experience', style: AppTextStyles.bodyLarge),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => GestureDetector(
            onTap: _isLoading ? null : () => setState(() => _rating = i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(i < _rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 34),
            ),
          )),
        ),
        if (_rating > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: GradientButton(
              label: 'Submit Rating',
              height: 44,
              isLoading: _isLoading,
              onTap: _submitReview,
            ),
          ),
        ],
      ]),
    );
  }
}