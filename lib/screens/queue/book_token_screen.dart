import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/crowd_density_badge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/shop_provider.dart';
import '../../models/shop_model.dart';

class BookTokenScreen extends ConsumerStatefulWidget {
  final String shopId;
  const BookTokenScreen({super.key, required this.shopId});

  @override
  ConsumerState<BookTokenScreen> createState() => _BookTokenScreenState();
}

class _BookTokenScreenState extends ConsumerState<BookTokenScreen>
    with SingleTickerProviderStateMixin {
  int _groupSize = 1;
  bool _isPriority = false;
  String _bookingType = 'token'; // 'token' or 'slot'
  DateTime? _selectedSlotStart;
  DateTime? _selectedSlotEnd;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      setState(() => _bookingType = _tabCtrl.index == 0 ? 'token' : 'slot');
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) {
      Helpers.showSnack(context, 'Please log in first', isError: true);
      return;
    }

    final notifier = ref.read(bookingProvider(user.id).notifier);

    if (_bookingType == 'token') {
      await notifier.bookToken(
        shopId: widget.shopId,
        groupSize: _groupSize,
        isPriority: _isPriority,
        priorityReason: _isPriority ? 'Emergency / Priority' : null,
      );
    } else {
      if (_selectedSlotStart == null || _selectedSlotEnd == null) {
        Helpers.showSnack(context, 'Please select a time slot', isError: true);
        return;
      }
      await notifier.bookSlot(
        shopId: widget.shopId,
        slotStart: _selectedSlotStart!,
        slotEnd: _selectedSlotEnd!,
      );
    }

    final state = ref.read(bookingProvider(user.id));
    if (state.isSuccess && state.token != null) {
      if (mounted) {
        context.pushReplacement('/live-queue/${state.token!.id}');
      }
    } else if (state.hasError) {
      if (mounted) {
        Helpers.showSnack(context, state.errorMessage ?? 'Booking failed', isError: true);
        notifier.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopByIdProvider(widget.shopId));
    final user = ref.watch(userProfileProvider).value;
    final bookingState = user != null ? ref.watch(bookingProvider(user.id)) : null;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Book Token')),
      body: shopAsync.when(
        data: (shop) {
          final queue = ref.watch(liveQueueProvider(widget.shopId));
          final totalWaiting = queue.queue?.totalWaiting ?? shop.totalWaiting ?? 0;
          final estWait = queue.queue?.estimatedWaitFor(
                  (queue.queue?.lastTokenNumber ?? 0) + 1) ??
              shop.estimatedWaitMinutes;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop info card
                _ShopSummaryCard(shop: shop, totalWaiting: totalWaiting, estWait: estWait),
                const SizedBox(height: 24),

                // Booking type tabs (only if slot booking enabled)
                if (shop.allowSlotBooking) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(4),
                    borderRadius: 14,
                    child: TabBar(
                      controller: _tabCtrl,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.primaryGradient),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: '🎫  Token Queue'),
                        Tab(text: '📅  Time Slot'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Token options
                if (_bookingType == 'token') ...[
                  _GroupSizeSelector(
                    value: _groupSize,
                    onChanged: (v) => setState(() => _groupSize = v),
                    max: shop.maxTokensPerUser,
                  ),
                  const SizedBox(height: 16),

                  // Priority toggle (hospitals/clinics)
                  if (shop.category == 'hospital' || shop.category == 'clinic')
                    _PriorityToggle(
                      value: _isPriority,
                      onChanged: (v) => setState(() => _isPriority = v),
                    ),
                ] else ...[
                  // Slot picker
                  _SlotPicker(
                    shopId: widget.shopId,
                    slotDuration: shop.slotDurationMinutes,
                    onSlotSelected: (start, end) => setState(() {
                      _selectedSlotStart = start;
                      _selectedSlotEnd = end;
                    }),
                    selectedStart: _selectedSlotStart,
                  ),
                ],

                const SizedBox(height: 24),

                // Summary card
                _BookingSummary(
                  shop: shop,
                  groupSize: _groupSize,
                  bookingType: _bookingType,
                  isPriority: _isPriority,
                  estWait: estWait,
                  slotStart: _selectedSlotStart,
                  slotEnd: _selectedSlotEnd,
                ),

                const SizedBox(height: 28),

                // Confirm button
                GradientButton(
                  label: 'Confirm & Get Token',
                  onTap: shop.isOpen ? _confirmBooking : null,
                  isLoading: bookingState?.isLoading ?? false,
                  colors: shop.isOpen ? AppColors.primaryGradient : [AppColors.textMuted, AppColors.textMuted],
                ).animate(delay: 200.ms).fadeIn(),

                if (!shop.isOpen) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${shop.name} is currently closed',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.electricBlue)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Shop summary card ──────────────────────────────────────────
class _ShopSummaryCard extends StatelessWidget {
  final ShopModel shop;
  final int totalWaiting;
  final int estWait;

  const _ShopSummaryCard({
    required this.shop,
    required this.totalWaiting,
    required this.estWait,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      borderColor: AppColors.electricBlue.withOpacity(0.3),
      child: Column(children: [
        Row(children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.primaryGradient),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                shop.categoryIcon,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(shop.name, style: AppTextStyles.headlineMedium),
            Text(shop.address ?? '', style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          CrowdDensityBadge(queueCount: totalWaiting),
        ]),
        const Divider(color: Colors.white10, height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _Mini(label: 'Waiting', value: '$totalWaiting', color: AppColors.statusWaiting),
          _Mini(label: 'Est. Wait', value: Helpers.formatWaitTime(estWait), color: AppColors.electricBlue),
          _Mini(label: 'Avg Service', value: '${shop.avgServiceTimeMinutes}m', color: AppColors.neonGreen),
        ]),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Mini({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: AppTextStyles.neonGlow(color, size: 16)),
        Text(label, style: AppTextStyles.bodySmall),
      ]);
}

// ── Group size selector ───────────────────────────────────────
class _GroupSizeSelector extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _GroupSizeSelector({required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.people_outline, color: AppColors.electricBlue, size: 20),
          const SizedBox(width: 8),
          Text('GROUP SIZE', style: AppTextStyles.labelSmall),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Number of people', style: AppTextStyles.bodyLarge),
          Row(children: [
            _CountBtn(icon: Icons.remove, onTap: value > 1 ? () => onChanged(value - 1) : null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$value', style: AppTextStyles.neonGlow(AppColors.neonGreen, size: 24)),
            ),
            _CountBtn(icon: Icons.add, onTap: value < max ? () => onChanged(value + 1) : null),
          ]),
        ]),
        const SizedBox(height: 8),
        if (value > 1)
          Text('Booking for $value people · 1 token for the group',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.electricBlue)),
      ]),
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CountBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: onTap != null
                ? AppColors.electricBlue.withOpacity(0.15)
                : Colors.white10,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: onTap != null
                  ? AppColors.electricBlue.withOpacity(0.4)
                  : Colors.transparent,
            ),
          ),
          child: Icon(icon,
              color: onTap != null ? AppColors.electricBlue : AppColors.textMuted,
              size: 18),
        ),
      );
}

// ── Priority toggle ───────────────────────────────────────────
class _PriorityToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PriorityToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? Colors.red.withOpacity(0.5) : Colors.white10,
            width: value ? 1.5 : 1,
          ),
          color: value ? Colors.red.withOpacity(0.08) : AppColors.darkBg2,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Text('🚨', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Emergency Priority', style: AppTextStyles.bodyLarge.copyWith(
                color: value ? Colors.red : Colors.white,
              )),
              Text('Mark if urgent medical condition', style: AppTextStyles.bodySmall),
            ])),
            Switch(
              value: value, onChanged: onChanged,
              activeColor: Colors.red,
              activeTrackColor: Colors.red.withOpacity(0.3),
            ),
          ]),
        ),
      );
}

// ── Slot picker ───────────────────────────────────────────────
class _SlotPicker extends StatelessWidget {
  final String shopId;
  final int slotDuration;
  final void Function(DateTime, DateTime) onSlotSelected;
  final DateTime? selectedStart;

  const _SlotPicker({
    required this.shopId,
    required this.slotDuration,
    required this.onSlotSelected,
    this.selectedStart,
  });

  @override
  Widget build(BuildContext context) {
    // Generate slots for today (9am–5pm)
    final now = DateTime.now();
    final slots = <DateTime>[];
    var slot = DateTime(now.year, now.month, now.day, 9, 0);
    final end = DateTime(now.year, now.month, now.day, 17, 0);
    while (slot.isBefore(end)) {
      if (slot.isAfter(now)) slots.add(slot);
      slot = slot.add(Duration(minutes: slotDuration));
    }

    if (slots.isEmpty) {
      return GlassCard(
        child: Center(
          child: Text('No more slots available today', style: AppTextStyles.bodyMedium),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SELECT TIME SLOT', style: AppTextStyles.labelSmall),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
        ),
        itemCount: slots.length,
        itemBuilder: (_, i) {
          final s = slots[i];
          final isSelected = selectedStart == s;
          return GestureDetector(
            onTap: () => onSlotSelected(s, s.add(Duration(minutes: slotDuration))),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: AppColors.primaryGradient)
                    : null,
                color: isSelected ? null : AppColors.darkBg2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : AppColors.electricBlue.withOpacity(0.2),
                ),
              ),
              child: Center(
                child: Text(
                  DateFormat('h:mm a').format(s),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ]);
  }
}

// ── Booking summary card ──────────────────────────────────────
class _BookingSummary extends StatelessWidget {
  final ShopModel shop;
  final int groupSize, estWait;
  final bool isPriority;
  final String bookingType;
  final DateTime? slotStart, slotEnd;

  const _BookingSummary({
    required this.shop, required this.groupSize, required this.estWait,
    required this.isPriority, required this.bookingType,
    this.slotStart, this.slotEnd,
  });

  @override
  Widget build(BuildContext context) {
    return NeonBorderCard(
      neonColor: AppColors.neonGreen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.neonGreen, size: 18),
          const SizedBox(width: 8),
          Text('BOOKING SUMMARY', style: AppTextStyles.labelSmall.copyWith(color: AppColors.neonGreen)),
        ]),
        const SizedBox(height: 12),
        _SummaryRow('Shop', shop.name),
        _SummaryRow('Type', bookingType == 'slot' ? 'Time Slot' : 'Queue Token'),
        _SummaryRow('Group Size', '$groupSize ${groupSize == 1 ? 'person' : 'people'}'),
        if (bookingType == 'token')
          _SummaryRow('Est. Wait', Helpers.formatWaitTime(estWait)),
        if (bookingType == 'slot' && slotStart != null && slotEnd != null)
          _SummaryRow('Slot', Helpers.formatSlotRange(slotStart!, slotEnd!)),
        if (isPriority)
          _SummaryRow('Priority', 'Emergency', valueColor: Colors.red),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _SummaryRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            Text(value,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      );
}

class NeonBorderCard extends StatelessWidget {
  final Widget child;
  final Color neonColor;
  const NeonBorderCard({super.key, required this.child, required this.neonColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neonColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: neonColor.withOpacity(0.1), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
