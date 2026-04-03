import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/crowd_density_badge.dart';
import '../../services/ai_prediction_service.dart';
import '../../providers/shop_provider.dart'; 
import '../../core/utils/helpers.dart';

// ============================================================
// shop_detail_screen.dart
// ============================================================
class ShopDetailScreen extends ConsumerWidget {
  final String shopId;
  const ShopDetailScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopDetailProvider(shopId));

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: shopAsync.when(
        data: (shop) => _ShopDetailBody(shop: shop),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electricBlue),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ShopDetailBody extends ConsumerStatefulWidget {
  final Map<String, dynamic> shop;
  const _ShopDetailBody({required this.shop});

  @override
  ConsumerState<_ShopDetailBody> createState() => _ShopDetailBodyState();
}

class _ShopDetailBodyState extends ConsumerState<_ShopDetailBody> {
  int? _aiPredictedWait;
  bool _loadingPrediction = true;

  @override
  void initState() {
    super.initState();
    _loadAiPrediction();
  }

  Future<void> _loadAiPrediction() async {
    try {
      final queue = widget.shop['queues'] as Map? ?? {};
      final waiting = (queue['total_waiting'] as int?) ?? 0;
      final avgTime = (queue['avg_service_time'] as num?)?.toDouble() ?? 5.0;
      final predicted = await AiPredictionService().predictWaitTime(
        shopId: widget.shop['id'],
        queueLength: waiting,
        currentAvgServiceTime: avgTime,
      );
      if (mounted) setState(() {
        _aiPredictedWait = predicted;
        _loadingPrediction = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPrediction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.shop['queues'] as Map? ?? {};
    final totalWaiting = (queue['total_waiting'] as int?) ?? 0;
    final currentToken = (queue['current_token'] as int?) ?? 0;
    final isOpen = widget.shop['is_open'] as bool? ?? false;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.darkBg,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B3E), AppColors.darkBg],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.electricBlue.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.electricBlue.withOpacity(0.3)),
                        ),
                        child: Icon(
                          Helpers.categoryIcon(widget.shop['category'] ?? ''),
                          size: 52,
                          color: AppColors.electricBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.shop['name'] ?? '',
                        style: AppTextStyles.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {},
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status row
                Row(
                  children: [
                    CrowdDensityBadge(queueCount: totalWaiting),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? AppColors.neonGreen.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOpen ? AppColors.neonGreen : Colors.red,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isOpen ? AppColors.neonGreen : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOpen ? 'OPEN NOW' : 'CLOSED',
                            style: TextStyle(
                              color: isOpen ? AppColors.neonGreen : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.shop['rating'] ?? 0}',
                          style: AppTextStyles.bodyLarge,
                        ),
                        Text(
                          ' (${widget.shop['total_ratings'] ?? 0})',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(),

                const SizedBox(height: 20),

                // Queue stats grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _StatBox(
                      label: 'NOW SERVING',
                      value: '$currentToken',
                      color: AppColors.neonGreen,
                      icon: Icons.play_circle_outline,
                    ),
                    _StatBox(
                      label: 'WAITING',
                      value: '$totalWaiting',
                      color: AppColors.statusWaiting,
                      icon: Icons.hourglass_bottom,
                    ),
                    _StatBox(
                      label: 'AI WAIT',
                      value: _loadingPrediction
                          ? '...'
                          : '~${_aiPredictedWait ?? 0}m',
                      color: AppColors.electricBlue,
                      icon: Icons.psychology_outlined,
                    ),
                  ],
                ).animate(delay: 150.ms).fadeIn(),

                const SizedBox(height: 20),

                // Address
                GlassCard(
                  borderRadius: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.electricBlue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.shop['address'] ?? 'No address',
                                style: AppTextStyles.bodyLarge),
                            Text(widget.shop['city'] ?? '',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.directions_outlined,
                          color: AppColors.textMuted),
                    ],
                  ),
                ).animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: 20),

                if (_aiPredictedWait != null)
  Animate(
    delay: 300.ms,
    effects: const [FadeEffect()],
    child: GlassCard(
      borderRadius: 16,
      borderColor: AppColors.electricBlue.withOpacity(0.3),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.electricBlue, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI-Predicted Wait Time',
                    style: AppTextStyles.bodyLarge),
                Text(
                  'Estimated wait: ~$_aiPredictedWait min (based on current rush)',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),

                const SizedBox(height: 28),

                // Book button
                if (isOpen)
                  GradientButton(
                    label: 'Get Token Now',
                    onTap: () => context.push('/book/${widget.shop['id']}'),
                    colors: AppColors.primaryGradient,
                    icon: const Icon(Icons.confirmation_number_outlined,
                        color: Colors.white, size: 20),
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.15, end: 0)
                else
                  GradientButton(
                    label: 'Shop is Closed',
                    onTap: null,
                    colors: [AppColors.textMuted, AppColors.textMuted],
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.neonGlow(color, size: 18)),
          const SizedBox(height: 3),
          Text(label,
              style: AppTextStyles.labelSmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
