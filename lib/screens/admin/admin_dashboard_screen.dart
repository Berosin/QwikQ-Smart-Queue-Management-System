import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../models/shop_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../core/utils/helpers.dart';

// ============================================================
// admin_dashboard_screen.dart
// ============================================================
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.darkBg,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text('Admin Panel', style: AppTextStyles.headlineMedium),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_business_outlined),
                onPressed: () => _showCreateShopDialog(context, ref),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: userAsync.when(
              data: (user) {
                if (user == null || !user.isAdmin) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        children: [
                          SizedBox(height: 80),
                          Icon(Icons.lock_outline, size: 64, color: AppColors.textMuted),
                          SizedBox(height: 16),
                          Text('Admin Access Only'),
                          SizedBox(height: 8),
                          Text('You need admin privileges'),
                        ],
                      ),
                    ),
                  );
                }

                final shopsAsync = ref.watch(adminOwnedShopsProvider(user.id));
                return shopsAsync.when(
                  data: (shops) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _AdminShopCard(shop: shops[i], index: i),
                      childCount: shops.length,
                    ),
                  ),
                  loading: () => const SliverToBoxAdapter(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.electricBlue)),
                  ),
                  error: (e, _) => SliverToBoxAdapter(child: Text('$e')),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.electricBlue)),
              ),
              error: (e, _) => SliverToBoxAdapter(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateShopDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateShopSheet(),
    );
  }
}

// ── Admin Shop Card ───────────────────────────────────────────
class _AdminShopCard extends StatelessWidget {
  final ShopModel shop;
  final int index;

  const _AdminShopCard({required this.shop, required this.index});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 20,
      borderColor: shop.isOpen
          ? AppColors.neonGreen.withOpacity(0.3)
          : AppColors.textMuted.withOpacity(0.2),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Helpers.categoryIcon(shop.category),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: AppTextStyles.headlineMedium),
                    Text(shop.address ?? '',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              // Open/Close toggle
              Consumer(
                builder: (ctx, ref, _) => GestureDetector(
                  onTap: () async {
                    await ref
                        .read(shopManagementProvider.notifier)
                        .toggleShopOpen(shop.id, isOpen: !shop.isOpen);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: shop.isOpen
                          ? const LinearGradient(
                              colors: AppColors.greenGradient)
                          : null,
                      color: shop.isOpen ? null : AppColors.darkBg3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: shop.isOpen
                            ? AppColors.neonGreen.withOpacity(0.5)
                            : AppColors.textMuted.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      shop.isOpen ? 'OPEN' : 'CLOSED',
                      style: TextStyle(
                        color:
                            shop.isOpen ? Colors.white : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _MiniStat(
                  label: 'Avg Time',
                  value: '${shop.avgServiceTimeMinutes}m',
                  color: AppColors.electricBlue),
              _divider(),
              _MiniStat(
                  label: 'Max/Day',
                  value: '${shop.maxTokensPerDay}',
                  color: AppColors.statusWaiting),
              _divider(),
              _MiniStat(
                  label: 'Rating',
                  value: shop.rating.toStringAsFixed(1),
                  color: AppColors.neonGreen),
            ],
          ),

          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: 'Control Queue',
                  height: 44,
                  onTap: () =>
                      context.push('/admin/queue/${shop.id}'),
                  colors: AppColors.primaryGradient,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  label: 'Analytics',
                  height: 44,
                  onTap: () =>
                      context.push('/admin/analytics/${shop.id}'),
                  colors: AppColors.blueGradient,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 100))
        .fadeIn()
        .slideY(begin: 0.1, end: 0);
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        color: Colors.white10,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: AppTextStyles.neonGlow(color, size: 20)),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      );
}

// ── Create Shop Bottom Sheet ──────────────────────────────────
class _CreateShopSheet extends ConsumerStatefulWidget {
  const _CreateShopSheet();

  @override
  ConsumerState<_CreateShopSheet> createState() => _CreateShopSheetState();
}

class _CreateShopSheetState extends ConsumerState<_CreateShopSheet> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _category = 'canteen';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(shopManagementProvider).isLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.darkBg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Create New Shop', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Shop name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Address'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            dropdownColor: AppColors.darkBg2,
            style: const TextStyle(color: Colors.white),
            items: [
              'canteen',
              'hospital',
              'bank',
              'clinic',
              'salon',
              'pharmacy',
              'government'
            ]
                .map((c) =>
                    DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
            decoration: const InputDecoration(hintText: 'Category'),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Create Shop',
            isLoading: isLoading,
            onTap: () async {
              final user = ref.read(userProfileProvider).value;
              if (user == null) return;
              final shop = await ref
                  .read(shopManagementProvider.notifier)
                  .createShop(
                    ownerId: user.id,
                    name: _nameCtrl.text.trim(),
                    category: _category,
                    address: _addressCtrl.text.trim(),
                  );
              if (shop != null && context.mounted) {
                Navigator.pop(context);
              }
            },
            colors: AppColors.primaryGradient,
          ),
        ],
      ),
    );
  }
}