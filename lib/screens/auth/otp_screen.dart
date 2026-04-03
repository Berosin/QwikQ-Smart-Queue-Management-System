import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldown = 60;
  Timer? _timer;

  String get _otp => _ctrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startCooldown();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_resendCooldown > 0) _resendCooldown--; else t.cancel(); });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < digits.length && i + index < 6; i++) {
        _ctrls[index + i].text = digits[i];
      }
      final next = (index + digits.length).clamp(0, 5);
      _focusNodes[next].requestFocus();
      if (_otp.length == 6) _verify();
      return;
    }
    if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
    if (value.isNotEmpty && index == 5 && _otp.length == 6) _verify();
    setState(() {});
  }

  void _onKeyEvent(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _ctrls[index - 1].clear();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (_otp.length != 6) return;
    setState(() => _isVerifying = true);
    try {
      await ref.read(authServiceProvider).verifyOtp(
            phone: widget.phone, token: _otp);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        Helpers.showSnack(context, 'Invalid OTP. Please try again.', isError: true);
        for (final c in _ctrls) c.clear();
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await ref.read(authServiceProvider).signInWithPhone(widget.phone);
      _startCooldown();
      if (mounted) Helpers.showSnack(context, 'OTP resent!');
    } catch (_) {
      if (mounted) Helpers.showSnack(context, 'Failed to resend.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(children: [
        Positioned(
          top: -60,
          left: MediaQuery.of(context).size.width / 2 - 160,
          child: Container(
            width: 320, height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.electricBlue.withOpacity(0.15), Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    AppColors.electricBlue.withOpacity(0.2),
                    AppColors.neonGreen.withOpacity(0.2),
                  ]),
                  border: Border.all(color: AppColors.electricBlue.withOpacity(0.5), width: 1.5),
                  boxShadow: [BoxShadow(color: AppColors.electricBlue.withOpacity(0.3), blurRadius: 24)],
                ),
                child: const Icon(Icons.sms_outlined, color: AppColors.electricBlue, size: 40),
              ).animate().scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 28),
              Text('Verify Phone', style: AppTextStyles.headlineLarge)
                  .animate(delay: 150.ms).fadeIn().slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              Text('Enter the 6-digit code sent to', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center)
                  .animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 4),
              Text(
                Helpers.maskPhone(widget.phone),
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.electricBlue, fontWeight: FontWeight.w600),
              ).animate(delay: 250.ms).fadeIn(),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _ctrls[i],
                  focusNode: _focusNodes[i],
                  hasValue: _ctrls[i].text.isNotEmpty,
                  onChanged: (v) => _onDigitChanged(i, v),
                  onKey: (e) => _onKeyEvent(i, e),
                )),
              ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.15, end: 0),
              const SizedBox(height: 48),
              GradientButton(
                label: 'Verify OTP',
                onTap: _otp.length == 6 ? _verify : null,
                isLoading: _isVerifying,
                colors: AppColors.primaryGradient,
                icon: const Icon(Icons.verified_outlined, color: Colors.white, size: 20),
              ).animate(delay: 450.ms).fadeIn(),
              const SizedBox(height: 28),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Didn't receive code? ", style: AppTextStyles.bodyMedium),
                GestureDetector(
                  onTap: _resendCooldown == 0 ? _resend : null,
                  child: _isResending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue))
                      : Text(
                          _resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend',
                          style: TextStyle(
                            color: _resendCooldown > 0 ? AppColors.textMuted : AppColors.electricBlue,
                            fontWeight: FontWeight.w600, fontSize: 14,
                          ),
                        ),
                ),
              ]).animate(delay: 550.ms).fadeIn(),
              const SizedBox(height: 32),
              GlassCard(
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.security_outlined, color: AppColors.neonGreen, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('This code expires in 10 minutes and is only valid once.', style: AppTextStyles.bodySmall)),
                ]),
              ).animate(delay: 650.ms).fadeIn(),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<RawKeyEvent> onKey;

  const _OtpBox({
    required this.controller, required this.focusNode,
    required this.hasValue, required this.onChanged, required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: onKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48, height: 58,
        decoration: BoxDecoration(
          color: hasValue ? AppColors.electricBlue.withOpacity(0.12) : AppColors.darkBg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasValue ? AppColors.electricBlue : AppColors.electricBlue.withOpacity(0.25),
            width: hasValue ? 1.5 : 1,
          ),
          boxShadow: hasValue ? [BoxShadow(color: AppColors.electricBlue.withOpacity(0.3), blurRadius: 12)] : null,
        ),
        child: Center(
          child: TextField(
            controller: controller, focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            style: TextStyle(
              color: AppColors.neonGreen, fontSize: 24, fontWeight: FontWeight.w700,
              shadows: [Shadow(color: AppColors.neonGreen.withOpacity(0.8), blurRadius: 10)],
            ),
            onChanged: onChanged,
            decoration: const InputDecoration(counterText: '', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero),
          ),
        ),
      ),
    );
  }
}