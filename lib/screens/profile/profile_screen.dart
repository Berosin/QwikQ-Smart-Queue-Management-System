import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/neon_text.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/token_provider.dart';
import '../../services/review_service.dart';
import '../../services/supabase_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = Tween(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _confetti.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(UserModel user) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 500,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'avatars/$fileName';

      // 1. Upload to Supabase Storage (profiles bucket)
      final url = await SupabaseService.uploadFile(
        bucket: 'profiles',
        path: path,
        bytes: bytes,
      );

      // 2. Update user profile in database
      await ref.read(authServiceProvider).updateProfile(avatarUrl: url);

      if (mounted) {
        Helpers.showSnack(context, 'Profile photo updated!');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnack(context, 'Upload failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 25,
              gravity: 0.2,
              emissionFrequency: 0.25,
              colors: const [AppColors.electricBlue, AppColors.neonGreen, Colors.white, Colors.amber],
            ),
          ),
          userAsync.when(
            data: (user) => user == null
                ? const Center(child: Text('Not logged in', style: TextStyle(color: Colors.white)))
                : _buildBody(user),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricBlue)),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(UserModel user) {
    final statsAsync = ref.watch(tokenStatsProvider(user.id));
    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 240,
        pinned: true,
        backgroundColor: AppColors.darkBg,
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditProfile(user)),
          IconButton(icon: const Icon(Icons.logout_outlined), onPressed: _confirmSignOut),
        ],
        flexibleSpace: FlexibleSpaceBar(background: _buildHero(user)),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            statsAsync.when(
              data: (s) => _buildStats(s),
              loading: () => _StatsShimmer(),
              error: (_, __) => const SizedBox(),
            ).animate().fadeIn(),
            const SizedBox(height: 24),
            _buildPointsCard(user),
            const SizedBox(height: 20),
            if (user.badges.isNotEmpty) ...[_buildBadges(user), const SizedBox(height: 20)],
            if (user.isAdmin) ...[_buildAdminCard(), const SizedBox(height: 20)],
            _buildMenu(user),
            const SizedBox(height: 80),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildHero(UserModel user) {
    return Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(
        animation: _glowAnim,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.electricBlue.withOpacity(0.18 + _glowAnim.value * 0.1), AppColors.darkBg],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      Positioned(top: -30, right: -30, child: Container(
        width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [AppColors.neonGreen.withOpacity(0.1), Colors.transparent])),
      )),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () => _pickAndUploadImage(user),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, child) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.electricBlue.withOpacity(_glowAnim.value * 0.5), blurRadius: 24, spreadRadius: 2)],
                  ),
                  child: child,
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.darkBg2,
                  child: _isUploading
                    ? const CircularProgressIndicator(color: AppColors.electricBlue)
                    : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? ClipOval(child: CachedNetworkImage(imageUrl: user.avatarUrl!, width: 92, height: 92, fit: BoxFit.cover, errorWidget: (_, __, ___) => _AvatarFallback(name: user.fullName)))
                        : _AvatarFallback(name: user.fullName)),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.electricBlue, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: AppColors.primaryGradient).createShader(b),
          child: Text(user.fullName, style: AppTextStyles.headlineLarge.copyWith(color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(user.email ?? user.phone ?? '', style: AppTextStyles.bodySmall),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: user.isAdmin ? AppColors.electricBlue.withOpacity(0.15) : Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: user.isAdmin ? AppColors.electricBlue.withOpacity(0.4) : Colors.white),
          ),
          child: Text(user.isAdmin ? 'ADMIN' : 'USER',
              style: TextStyle(color: user.isAdmin ? AppColors.electricBlue : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
      ])),
    ]);
  }

  Widget _buildStats(TokenStats stats) => Row(children: [
    Expanded(child: _StatCard(value: '${stats.total}', label: 'TOKENS', color: AppColors.electricBlue, icon: Icons.confirmation_number_outlined)),
    const SizedBox(width: 12),
    Expanded(child: _StatCard(value: '${stats.completed}', label: 'DONE', color: AppColors.neonGreen, icon: Icons.check_circle_outline)),
    const SizedBox(width: 12),
    Expanded(child: _StatCard(value: '${stats.avgWaitMinutes.round()}m', label: 'AVG WAIT', color: AppColors.statusWaiting, icon: Icons.timer_outlined)),
  ]);

  Widget _buildPointsCard(UserModel user) {
    final level = Helpers.pointsLabel(user.points);
    final levelColor = Helpers.pointsColor(user.points);
    final thresholds = [0, 100, 500, 1000, 5000, 999999];
    final idx = thresholds.indexWhere((t) => user.points < t) - 1;
    final nextT = idx + 1 < thresholds.length ? thresholds[idx + 1] : thresholds.last;
    final currT = idx >= 0 ? thresholds[idx] : 0;
    final progress = ((user.points - currT) / (nextT - currT).clamp(1, 999999)).clamp(0.0, 1.0);

    return GlassCard(
      borderRadius: 18,
      borderColor: levelColor.withOpacity(0.3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [levelColor.withOpacity(0.3), levelColor.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: levelColor.withOpacity(0.4)),
            ),
            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('POINTS & LEVEL', style: AppTextStyles.labelSmall),
            Row(children: [
              NeonText('${user.points}', color: levelColor, fontSize: 22),
              const SizedBox(width: 6),
              Text('pts', style: AppTextStyles.bodyMedium),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: levelColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: levelColor.withOpacity(0.4))),
            child: Text(level, style: TextStyle(color: levelColor, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(levelColor), minHeight: 6),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$currT pts', style: AppTextStyles.bodySmall),
          Text('Next level: $nextT pts', style: AppTextStyles.bodySmall),
        ]),
      ]),
    ).animate(delay: 100.ms).fadeIn();
  }

  Widget _buildBadges(UserModel user) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('MY BADGES', style: AppTextStyles.labelSmall),
      GestureDetector(
        onTap: () => _confetti.play(),
        child: Text('Celebrate', style: TextStyle(color: AppColors.electricBlue, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    ]),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8, runSpacing: 8,
      children: user.badges.asMap().entries.map((e) => _BadgeTile(badge: e.value)
          .animate(delay: Duration(milliseconds: e.key * 60)).fadeIn().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1))).toList(),
    ),
  ]);

  Widget _buildAdminCard() => GlassCard(
    borderRadius: 16,
    borderColor: AppColors.electricBlue.withOpacity(0.4),
    onTap: () => context.push('/admin'),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.electricBlue.withOpacity(0.4), blurRadius: 12)],
        ),
        child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Admin Dashboard', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        Text('Manage shops, queues & analytics', style: AppTextStyles.bodySmall),
      ])),
      const Icon(Icons.chevron_right, color: AppColors.textMuted),
    ]),
  ).animate(delay: 150.ms).fadeIn();

  Widget _buildMenu(UserModel user) {
    final items = [
      _MI(Icons.history_outlined, 'Token History', '${user.totalTokensBooked} total bookings', () => context.push('/my-tokens')),
      _MI(Icons.notifications_outlined, 'Notifications', 'Alerts & queue updates', () {}),
      _MI(Icons.star_outline_rounded, 'My Reviews', 'Rate your experiences', () => _showMyReviews(user.id)),
      _MI(Icons.location_on_outlined, 'Saved Locations', 'Favourite shops & addresses', () {}),
      _MI(Icons.security_outlined, 'Privacy & Security', 'Account security settings', () {}),
      _MI(Icons.help_outline_rounded, 'Help & Support', 'FAQs and contact us', () {}),
      _MI(Icons.info_outline_rounded, 'About QwikQ', 'v1.0.0 — Skip the line.', () {}),
    ];
    return Column(children: items.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: e.value.onTap,
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.electricBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(e.value.icon, color: AppColors.electricBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.value.label, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
            Text(e.value.subtitle, style: AppTextStyles.bodySmall),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ).animate(delay: Duration(milliseconds: 200 + e.key * 50)).fadeIn().slideX(begin: 0.05, end: 0),
    )).toList());
  }

  void _showMyReviews(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: AppColors.darkBg2, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('My Reviews', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ReviewService().getUserReviews(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final reviews = snapshot.data ?? [];
                if (reviews.isEmpty) return const Center(child: Text('No reviews yet.'));
                return ListView.builder(
                  itemCount: reviews.length,
                  itemBuilder: (ctx, i) {
                    final r = reviews[i];
                    final shop = r['shops'] as Map? ?? {};
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(shop['name'] ?? 'Shop', style: AppTextStyles.bodyLarge),
                          Row(children: List.generate(5, (idx) => Icon(Icons.star, color: idx < (r['rating'] ?? 0) ? Colors.amber : Colors.white10, size: 14))),
                        ]),
                        if (r['comment'] != null && r['comment'].toString().isNotEmpty) ...[const SizedBox(height: 6), Text(r['comment'], style: AppTextStyles.bodySmall)],
                        const SizedBox(height: 4),
                        Text(Helpers.timeAgo(DateTime.parse(r['created_at'])), style: TextStyle(color: Colors.white24, fontSize: 10)),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showEditProfile(UserModel user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.darkBg2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Edit Profile', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline, color: AppColors.electricBlue)),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Save Changes',
              onTap: () async {
                await ref.read(authServiceProvider).updateProfile(fullName: nameCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                Helpers.showSnack(context, 'Profile updated!');
              },
            ),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
  }

  void _confirmSignOut() async {
    final confirm = await Helpers.showConfirmDialog(
      context, title: 'Sign Out?',
      message: 'You will need to sign in again to use QwikQ.',
      confirmLabel: 'Sign Out', destructive: true,
    );
    if (confirm == true && mounted) {
      await ref.read(authServiceProvider).signOut();
      context.go('/login');
    }
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) => Container(
    width: 92, height: 92,
    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: AppColors.primaryGradient)),
    child: Center(child: Text(Helpers.initials(name), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white))),
  );
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatCard({required this.value, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 6),
      NeonText(value, color: color, fontSize: 18),
      const SizedBox(height: 3),
      Text(label, style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
    ]),
  );
}

class _BadgeTile extends StatelessWidget {
  final String badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0x2A007BFF), Color(0x1A00E676)]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.electricBlue.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('🏆', style: TextStyle(fontSize: 13)),
      const SizedBox(width: 5),
      Text(badge, style: TextStyle(color: AppColors.electricBlue, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _MI {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  const _MI(this.icon, this.label, this.subtitle, this.onTap);
}

class _StatsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: List.generate(3, (i) => Expanded(
    child: Container(
      margin: EdgeInsets.only(left: i > 0 ? 12 : 0),
      height: 80,
      decoration: BoxDecoration(color: AppColors.darkBg2, borderRadius: BorderRadius.circular(14)),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(color: AppColors.electricBlue.withOpacity(0.1), duration: 1200.ms),
  )));
}