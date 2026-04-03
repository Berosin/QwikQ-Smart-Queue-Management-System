import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/crowd_density_badge.dart';
import '../../providers/shop_provider.dart';
import '../../models/shop_model.dart';
import '../../core/utils/helpers.dart';

class NearbyShopsScreen extends ConsumerStatefulWidget {
  const NearbyShopsScreen({super.key});

  @override
  ConsumerState<NearbyShopsScreen> createState() => _NearbyShopsScreenState();
}

class _NearbyShopsScreenState extends ConsumerState<NearbyShopsScreen> {
  String? _selectedCategory;
  final _searchCtrl = TextEditingController();

  final _categories = [
    {'label': 'All', 'value': null},
    {'label': 'Canteen', 'value': 'canteen'},
    {'label': 'Hospital', 'value': 'hospital'},
    {'label': 'Bank', 'value': 'bank'},
    {'label': 'Pharmacy', 'value': 'pharmacy'},
    {'label': 'Salon', 'value': 'salon'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Update filter when category or search changes
    final filter = ref.watch(shopFilterProvider);

    // Sync local state to filter provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(shopFilterProvider);
      if (current.category != _selectedCategory ||
          current.searchQuery != _searchCtrl.text) {
        ref.read(shopFilterProvider.notifier).update((s) => s.copyWith(
              category: _selectedCategory,
              clearCategory: _selectedCategory == null,
              searchQuery: _searchCtrl.text,
            ));
      }
    });

    final shopsAsync = ref.watch(nearbyShopsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppColors.darkBg,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text('Find Shops', style: AppTextStyles.headlineMedium),
              background: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.electricBlue.withOpacity(0.15),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) {
                  ref.read(shopFilterProvider.notifier).update((s) =>
                      s.copyWith(searchQuery: val));
                },
                decoration: const InputDecoration(
                  hintText: 'Search shops...',
                  prefixIcon: Icon(Icons.search, color: AppColors.electricBlue),
                  suffixIcon: Icon(Icons.tune, color: AppColors.textMuted, size: 20),
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          ),

          // Category chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat['value'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat['value'] as String?);
                      ref.read(shopFilterProvider.notifier).update((s) =>
                          s.copyWith(
                            category: cat['value'] as String?,
                            clearCategory: cat['value'] == null,
                          ));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(colors: AppColors.primaryGradient)
                            : null,
                        color: isSelected ? null : AppColors.darkBg2,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AppColors.electricBlue.withOpacity(0.2),
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(
                                color: AppColors.electricBlue.withOpacity(0.3),
                                blurRadius: 10)]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          cat['label'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ).animate(delay: 150.ms).fadeIn(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Shops list
          shopsAsync.when(
            data: (shops) {
              if (shops.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(Icons.storefront_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text('No shops found',
                              style: AppTextStyles.headlineMedium),
                          const SizedBox(height: 8),
                          Text('Try a different category',
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _ShopTile(shop: shops[i], index: i),
                  childCount: shops.length,
                ),
              );
            },
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ShopTileSkeleton(),
                childCount: 5,
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $e')),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final ShopModel shop;
  final int index;

  const _ShopTile({required this.shop, required this.index});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      borderRadius: 18,
      onTap: () => context.push('/shop/${shop.id}'),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x33007BFF), Color(0x1A00E676)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.electricBlue.withOpacity(0.3)),
            ),
            child: Center(
              child: Icon(shop.categoryIcon,
                  color: AppColors.electricBlue, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: shop.isOpen
                            ? AppColors.neonGreen.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        shop.isOpen ? 'OPEN' : 'CLOSED',
                        style: TextStyle(
                          color: shop.isOpen
                              ? AppColors.neonGreen
                              : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        shop.address ?? 'No address',
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (shop.distanceKm != null)
                      Text(
                        '${shop.distanceKm!.toStringAsFixed(1)} km',
                        style: AppTextStyles.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CrowdDensityBadge(queueCount: shop.totalWaiting ?? 0),
                    const SizedBox(width: 8),
                    const Icon(Icons.timer_outlined,
                        color: AppColors.textMuted, size: 14),
                    const SizedBox(width: 3),
                    Text('~${shop.avgServiceTimeMinutes} min',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 60))
        .fadeIn()
        .slideX(begin: 0.05, end: 0);
  }
}

class _ShopTileSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.darkBg2,
        borderRadius: BorderRadius.circular(18),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
        color: AppColors.electricBlue.withOpacity(0.1),
        duration: 1200.ms);
  }
}
