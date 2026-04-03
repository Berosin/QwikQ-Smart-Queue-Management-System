import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/token_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/token_provider.dart';

class MyTokensScreen extends ConsumerStatefulWidget {
  const MyTokensScreen({super.key});

  @override
  ConsumerState<MyTokensScreen> createState() => _MyTokensScreenState();
}

class _MyTokensScreenState extends ConsumerState<MyTokensScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('MY TOKENS', style: AppTextStyles.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.electricBlue,
          labelColor: AppColors.electricBlue,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActiveTokensList(),
          _TokenHistoryList(),
        ],
      ),
    );
  }
}

class _ActiveTokensList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsync = ref.watch(activeTokensProvider);

    return tokensAsync.when(
      data: (tokens) {
        if (tokens.isEmpty) {
          return _EmptyState(
            icon: Icons.confirmation_number_outlined,
            message: 'No active tokens',
            actionLabel: 'Book a Token',
            onAction: () => context.push('/shops'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: tokens.length,
          itemBuilder: (context, index) => _TokenCard(token: tokens[index], isActive: true),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricBlue)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
    );
  }
}

class _TokenHistoryList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    if (user == null) return const SizedBox();

    final historyAsync = ref.watch(tokenHistoryNotifierProvider(user.id));

    return historyAsync.when(
      data: (tokens) {
        if (tokens.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            message: 'No token history yet',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: tokens.length,
          itemBuilder: (context, index) => _TokenCard(token: tokens[index], isActive: false),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricBlue)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
    );
  }
}

class _TokenCard extends StatelessWidget {
  final TokenModel token;
  final bool isActive;

  const _TokenCard({required this.token, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final statusColor = Helpers.statusColor(token.status.name);
    
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      onTap: () => context.push(isActive ? '/live-queue/${token.id}' : '/token/${token.id}'),
      child: Row(
        children: [
          // Token Number Circle
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
            ),
            child: Center(
              child: Text(
                '${token.tokenNumber}',
                style: AppTextStyles.neonGlow(statusColor, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(token.shopName ?? 'Shop', style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  // FIX: Convert UTC time from Supabase to Local Time before formatting
                  DateFormat('MMM d, h:mm a').format(token.createdAt.toLocal()),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          // Status Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  token.status.name.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted)),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
