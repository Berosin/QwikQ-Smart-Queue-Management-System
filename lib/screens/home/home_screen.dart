import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/token_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../core/utils/helpers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          _buildMeshBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(userAsync)),
                SliverToBoxAdapter(child: _buildActiveTokensBanner()),
                SliverToBoxAdapter(child: _buildQuickActions()),
                SliverToBoxAdapter(child: _buildCategoryGrid()),
                SliverToBoxAdapter(child: _buildNearbyShopsPreview()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildMeshBackground() {
    return Stack(
      children: [
        Container(color: AppColors.darkBg),
        Positioned(
          top: -40,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.electricBlue.withOpacity(0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          top: 180,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.neonGreen.withOpacity(0.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AsyncValue userAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good ${Helpers.greeting().split(' ').last} !', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 4),
                userAsync.when(
                  data: (user) => Text(
                    user?.fullName.split(' ').first ?? 'User',
                    style: AppTextStyles.headlineLarge,
                  ),
                  loading: () => const SizedBox(height: 28),
                  error: (_, __) => Text('User', style: AppTextStyles.headlineLarge),
                ),
              ],
            ),
          ),
          // Points badge
          userAsync.when(
            data: (user) => GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              borderColor: AppColors.neonGreen.withOpacity(0.3),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.neonGreen, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${user?.points ?? 0} pts',
                    style: AppTextStyles.neonGlow(AppColors.neonGreen, size: 14),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(width: 10),
          // Notifications
          GlowIconButton(
            icon: Icons.notifications_outlined,
            onTap: () {},
          ),
          const SizedBox(width: 10),
          // QR Scan
          GlowIconButton(
            icon: Icons.qr_code_scanner,
            color: AppColors.neonGreen,
            onTap: () => context.push('/qr-scan'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildActiveTokensBanner() {
  final tokensAsync = ref.watch(activeTokensProvider);
  return tokensAsync.when(
    data: (tokens) {
      if (tokens.isEmpty) return const SizedBox();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR ACTIVE TOKENS', style: AppTextStyles.labelSmall),
            const SizedBox(height: 10),
            ...tokens.map((t) => _ActiveTokenCard(token: t)).toList(),
          ],
        ),
      );
    },
    loading: () => const SizedBox(),
    error: (_, __) => const SizedBox(),
  );
}

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK ACTIONS', style: AppTextStyles.labelSmall),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.add_circle_outline,
                  label: 'Book Token',
                  gradient: AppColors.primaryGradient,
                  onTap: () => context.push('/shops'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.qr_code_scanner,
                  label: 'Scan QR',
                  gradient: [const Color(0xFF7C3AED), AppColors.electricBlue],
                  onTap: () => context.push('/qr-scan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.history,
                  label: 'History',
                  gradient: [AppColors.electricBlue, const Color(0xFF0047FF)],
                  onTap: () => context.push('/my-tokens'),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {'label': 'Canteen', 'value': 'canteen'},
      {'label': 'Hospital', 'value': 'hospital'},
      {'label': 'Bank', 'value': 'bank'},
      {'label': 'Pharmacy', 'value': 'pharmacy'},
      {'label': 'Salon', 'value': 'salon'},
      {'label': 'Govt', 'value': 'government'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CATEGORIES', style: AppTextStyles.labelSmall),
              GestureDetector(
                onTap: () => context.push('/shops'),
                child: Text('See All',
                    style: TextStyle(color: AppColors.electricBlue, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final cat = categories[i];
              final icon = Helpers.categoryIcon(cat['value']!);
              return GlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.all(12),
                onTap: () => context.push('/shops?category=${cat['value']}'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 28, color: AppColors.electricBlue),
                    const SizedBox(height: 8),
                    Text(cat['label']!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: Duration(milliseconds: 300 + i * 50))
                  .fadeIn().scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyShopsPreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NEARBY SHOPS', style: AppTextStyles.labelSmall),
              GestureDetector(
                onTap: () => context.push('/shops'),
                child: Text('View All',
                    style: TextStyle(color: AppColors.electricBlue, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Placeholder tiles
          ...List.generate(
            3,
            (i) => _ShopPreviewTile(index: i),
          ),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn();
  }

  Widget _buildNavBar() {
    const items = [
      {'icon': Icons.home_outlined, 'label': 'Home'},
      {'icon': Icons.store_outlined, 'label': 'Shops'},
      {'icon': Icons.confirmation_number_outlined, 'label': 'Tokens'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBg2,
        border: Border(top: BorderSide(color: AppColors.electricBlue.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricBlue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSelected = _selectedIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = i);
                  if (i == 0) context.go('/home');
                  if (i == 1) context.push('/shops');
                  if (i == 2) context.push('/my-tokens');
                  if (i == 3) context.push('/profile');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: isSelected
                      ? BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0x33007BFF),
                              Color(0x1A00E676),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.electricBlue.withOpacity(0.4),
                          ),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected ? AppColors.electricBlue : AppColors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? AppColors.electricBlue : AppColors.textMuted,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Active Token Card ──────────────────────────────────────────
class _ActiveTokenCard extends ConsumerWidget {
  final TokenModel token;
  const _ActiveTokenCard({required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = Helpers.statusColor(token.status.name);
    return GestureDetector(
      onTap: () => context.push('/live-queue/${token.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              statusColor.withOpacity(0.15),
              AppColors.darkBg2,
            ],
          ),
          border: Border.all(color: statusColor.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: statusColor.withOpacity(0.2), blurRadius: 12),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Token number
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    '${token.tokenNumber}',
                    style: AppTextStyles.neonGlow(statusColor, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(token.shopName ?? 'Shop', style: AppTextStyles.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      '~${token.estimatedWaitMinutes ?? 0} min wait',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: token.status),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TokenStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.name.toUpperCase();
    final color = Helpers.statusColor(status.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ShopPreviewTile extends StatelessWidget {
  final int index;
  const _ShopPreviewTile({required this.index});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: 16,
      onTap: () => context.push('/shops'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.electricBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store_outlined, color: AppColors.electricBlue, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Browse nearby shops', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                Text('Tap to explore', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// re-export widget used in home
class GlowIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  const GlowIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color = AppColors.electricBlue,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}