import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/neon_text.dart';
import '../../core/widgets/crowd_density_badge.dart';
import '../../models/token_model.dart';
import '../../providers/queue_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/supabase_service.dart';

class QueueControlScreen extends ConsumerStatefulWidget {
  final String shopId;
  const QueueControlScreen({super.key, required this.shopId});

  @override
  ConsumerState<QueueControlScreen> createState() => _QueueControlScreenState();
}

class _QueueControlScreenState extends ConsumerState<QueueControlScreen>
    with SingleTickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  List<TokenModel> _tokens = [];
  int _currentToken = 0;
  int _totalWaiting = 0;
  bool _isAdvancing = false;
  bool _isPaused = false;
  late AnimationController _pulseCtrl;
  dynamic _queueChannel;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _initTts();
    _loadTokens();
    _subscribeQueue();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _loadTokens() async {
    try {
      final service = ref.read(queueServiceProvider);
      
      // Fetch shop tokens
      final tokens = await service.getShopTokens(widget.shopId);
      
      // Fetch queue state directly from Supabase
      final queueData = await SupabaseService.client
          .from('queues')
          .select()
          .eq('shop_id', widget.shopId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _tokens = tokens;
          if (queueData != null) {
            _currentToken = queueData['current_token'] as int? ?? 0;
            _totalWaiting = queueData['total_waiting'] as int? ?? 0;
            _isPaused = queueData['is_paused'] as bool? ?? false;
          }
        });
      }
    } catch (e) {
      if (mounted) Helpers.showSnack(context, 'Failed to load tokens: $e', isError: true);
    }
  }

  void _subscribeQueue() {
    final service = ref.read(queueServiceProvider);
    _queueChannel = service.watchQueue(widget.shopId, (data) {
      if (!mounted) return;
      setState(() {
        _currentToken = data['current_token'] as int? ?? _currentToken;
        _totalWaiting = data['total_waiting'] as int? ?? _totalWaiting;
        _isPaused = data['is_paused'] as bool? ?? _isPaused;
      });
      _loadTokens();
    });
  }

  Future<void> _callNext() async {
    if (_isAdvancing) return;
    
    // Logic check: Is there anyone waiting?
    final hasWaiting = _tokens.any((t) => t.status == TokenStatus.waiting);
    if (!hasWaiting) {
      Helpers.showSnack(context, 'Queue is empty. No tokens to call.', isError: true);
      return;
    }

    setState(() => _isAdvancing = true);
    try {
      final notifier = ref.read(adminQueueProvider.notifier);
      final next = await notifier.callNext(widget.shopId);
      if (next != null) {
        if (next != _currentToken) {
          setState(() => _currentToken = next);
          await _announce(next);
        }
        await _loadTokens();
      }
    } catch (e) {
      if (mounted) Helpers.showSnack(context, 'Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isAdvancing = false);
    }
  }

  Future<void> _completeToken(TokenModel token) async {
    try {
      await ref.read(adminQueueProvider.notifier).completeToken(token.id);
      await _loadTokens();
      if (mounted) Helpers.showSnack(context, 'Token #${token.tokenNumber} completed');
    } catch (e) {
      if (mounted) Helpers.showSnack(context, 'Failed: $e', isError: true);
    }
  }

  Future<void> _announce(int token) async {
    await _tts.speak(
      'Token number $token. Please proceed to the counter. Token $token, your turn now.',
    );
  }

  Future<void> _togglePause() async {
    final notifier = ref.read(adminQueueProvider.notifier);
    if (_isPaused) {
      await notifier.resumeQueue(widget.shopId);
      Helpers.showSnack(context, 'Queue resumed');
    } else {
      await notifier.pauseQueue(widget.shopId, reason: 'Admin paused');
      Helpers.showSnack(context, 'Queue paused');
    }
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _skipToken(TokenModel token) async {
    await ref.read(adminQueueProvider.notifier).skipToken(token.id);
    await _loadTokens();
    Helpers.showSnack(context, 'Token #${token.tokenNumber} skipped');
  }

  Future<void> _markPriority(TokenModel token) async {
    await ref.read(adminQueueProvider.notifier).markPriority(token.id, 'Admin priority');
    await _loadTokens();
    Helpers.showSnack(context, 'Token #${token.tokenNumber} marked priority');
  }

  @override
  void dispose() {
    _tts.stop();
    _queueChannel?.unsubscribe();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopByIdProvider(widget.shopId));

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: shopAsync.when(
          data: (s) => Text(s.name, style: AppTextStyles.headlineMedium),
          loading: () => const Text('Queue Control'),
          error: (_, __) => const Text('Queue Control'),
        ),
        actions: [
          GestureDetector(
            onTap: _togglePause,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isPaused ? AppColors.neonGreen.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isPaused ? AppColors.neonGreen : Colors.red),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: _isPaused ? AppColors.neonGreen : Colors.red, size: 18),
                const SizedBox(width: 4),
                Text(_isPaused ? 'RESUME' : 'PAUSE',
                    style: TextStyle(color: _isPaused ? AppColors.neonGreen : Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadTokens),
        ],
      ),
      body: Column(
        children: [
          if (_isPaused)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.orange.withOpacity(0.15),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.pause_circle, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Text('QUEUE IS PAUSED', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ]),
            ).animate().fadeIn(),

          _buildCurrentTokenPanel(),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: GradientButton(
                  label: '▶  CALL NEXT TOKEN',
                  onTap: _isPaused ? null : _callNext,
                  isLoading: _isAdvancing,
                  height: 58,
                  colors: _isPaused
                      ? [AppColors.textMuted, AppColors.textMuted]
                      : AppColors.primaryGradient,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _announce(_currentToken),
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.electricBlue.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.volume_up_rounded, color: AppColors.electricBlue, size: 26),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => context.push('/admin/analytics/${widget.shopId}'),
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.neonGreen.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: AppColors.neonGreen, size: 26),
                ),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('QUEUE LIST', style: AppTextStyles.labelSmall),
              Row(children: [
                CrowdDensityBadge(queueCount: _totalWaiting),
                const SizedBox(width: 8),
                Text('$_totalWaiting waiting', style: AppTextStyles.bodySmall),
              ]),
            ]),
          ),

          Expanded(
            child: _tokens.isEmpty
                ? _buildEmptyQueue()
                : RefreshIndicator(
                    onRefresh: _loadTokens,
                    color: AppColors.electricBlue,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: _tokens.length,
                      itemBuilder: (_, i) => _TokenRow(
                        token: _tokens[i],
                        isCurrent: _tokens[i].tokenNumber == _currentToken,
                        index: i,
                        onSkip: () => _skipToken(_tokens[i]),
                        onPriority: () => _markPriority(_tokens[i]),
                        onAnnounce: () => _announce(_tokens[i].tokenNumber),
                        onComplete: () => _completeToken(_tokens[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTokenPanel() {
    final nextToken = _tokens.where((t) => t.status == TokenStatus.waiting).isNotEmpty
        ? _tokens.where((t) => t.status == TokenStatus.waiting).first.tokenNumber
        : '-';

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [AppColors.electricBlue.withOpacity(0.18), AppColors.neonGreen.withOpacity(0.08)],
        ),
        border: Border.all(color: AppColors.electricBlue.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: AppColors.electricBlue.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(children: [
            Text('NOW SERVING', style: AppTextStyles.labelSmall),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Text(
                '$_currentToken',
                style: AppTextStyles.tokenNumber.copyWith(
                  fontSize: 64,
                  shadows: [Shadow(color: AppColors.neonGreen.withOpacity(0.5 + _pulseCtrl.value * 0.3), blurRadius: 20)],
                ),
              ),
            ),
          ]),
          Container(width: 1, height: 70, color: Colors.white10),
          Column(children: [
            Text('WAITING', style: AppTextStyles.labelSmall),
            const SizedBox(height: 4),
            NeonText('$_totalWaiting', color: AppColors.statusWaiting, fontSize: 48),
            Text('in queue', style: AppTextStyles.bodySmall),
          ]),
          Container(width: 1, height: 70, color: Colors.white10),
          Column(children: [
            Text('NEXT UP', style: AppTextStyles.labelSmall),
            const SizedBox(height: 4),
            NeonText('$nextToken', color: AppColors.electricBlue, fontSize: 48),
            Text('token', style: AppTextStyles.bodySmall),
          ]),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEmptyQueue() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_outline, size: 64, color: AppColors.neonGreen).animate().scale(curve: Curves.elasticOut),
        const SizedBox(height: 16),
        Text('Queue is Empty!', style: AppTextStyles.headlineMedium).animate(delay: 200.ms).fadeIn(),
        const SizedBox(height: 8),
        Text('No one is waiting right now.', style: AppTextStyles.bodyMedium).animate(delay: 300.ms).fadeIn(),
      ]),
    );
  }
}

class _TokenRow extends StatelessWidget {
  final TokenModel token;
  final bool isCurrent;
  final int index;
  final VoidCallback onSkip;
  final VoidCallback onPriority;
  final VoidCallback onAnnounce;
  final VoidCallback onComplete;

  const _TokenRow({
    required this.token,
    required this.isCurrent,
    required this.index,
    required this.onSkip,
    required this.onPriority,
    required this.onAnnounce,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = Helpers.statusColor(token.status.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isCurrent ? AppColors.neonGreen.withOpacity(0.08) : AppColors.darkBg2,
        border: Border.all(
          color: token.isPriority
              ? Colors.red.withOpacity(0.5)
              : isCurrent
                  ? AppColors.neonGreen.withOpacity(0.4)
                  : Colors.white10,
          width: isCurrent || token.isPriority ? 1.5 : 1,
        ),
        boxShadow: isCurrent
            ? [BoxShadow(color: AppColors.neonGreen.withOpacity(0.15), blurRadius: 12)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.neonGreen.withOpacity(0.15) : statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isCurrent ? AppColors.neonGreen.withOpacity(0.5) : statusColor.withOpacity(0.3)),
            ),
            child: Center(child: NeonText(
              '${token.tokenNumber}',
              color: isCurrent ? AppColors.neonGreen : statusColor,
              fontSize: 16,
            )),
          ),
          const SizedBox(width: 12),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Group of ${token.groupSize}', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
              if (token.isPriority) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('PRIORITY', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(token.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(Helpers.timeAgo(token.createdAt), style: AppTextStyles.bodySmall),
            ]),
          ])),

          Row(mainAxisSize: MainAxisSize.min, children: [
            if (token.status == TokenStatus.serving || token.status == TokenStatus.called)
              _ActionBtn(icon: Icons.check_circle_rounded, color: AppColors.neonGreen, onTap: onComplete, tooltip: 'Complete'),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.volume_up_rounded, color: AppColors.electricBlue, onTap: onAnnounce, tooltip: 'Announce'),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.priority_high_rounded, color: Colors.red, onTap: onPriority, tooltip: 'Priority'),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.skip_next_rounded, color: AppColors.textMuted, onTap: onSkip, tooltip: 'Skip'),
          ]),
        ]),
      ),
    ).animate(delay: Duration(milliseconds: index * 40)).fadeIn().slideX(begin: 0.05, end: 0);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionBtn({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    ),
  );
}
