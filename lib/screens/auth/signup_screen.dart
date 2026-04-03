import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../providers/auth_provider.dart';

// ============================================================
// signup_screen.dart
// ============================================================
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _isAdmin = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.neonGreen.withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.electricBlue.withOpacity(0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('Create Account', style: AppTextStyles.headlineLarge)
                      .animate().fadeIn().slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 6),
                  Text('Join QwikQ and skip the queue forever',
                      style: AppTextStyles.bodyMedium)
                      .animate(delay: 100.ms).fadeIn(),
                  const SizedBox(height: 32),
                  GlassCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(24),
                    borderColor: AppColors.neonGreen.withOpacity(0.3),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _field(_nameCtrl, 'Full Name', Icons.person_outline,
                              validator: (v) => (v?.isNotEmpty ?? false) ? null : 'Required'),
                          const SizedBox(height: 16),
                          _field(_emailCtrl, 'Email', Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v?.contains('@') ?? false) ? null : 'Invalid email'),
                          const SizedBox(height: 16),
                          _field(_phoneCtrl, 'Phone (optional)', Icons.phone_outlined,
                              keyboardType: TextInputType.phone),
                          const SizedBox(height: 16),
                          _field(_passCtrl, 'Password', Icons.lock_outline,
                              obscure: _obscurePass,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.textMuted, size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
                              validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Min 6 chars'),
                          const SizedBox(height: 16),
                          // Admin toggle
                          Row(
                            children: [
                              Switch(
                                value: _isAdmin,
                                onChanged: (v) => setState(() => _isAdmin = v),
                                activeColor: AppColors.electricBlue,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Register as Shop Owner', style: AppTextStyles.bodyLarge),
                                  Text('Manage your own queue', style: AppTextStyles.bodySmall),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: 'Create Account',
                            onTap: _signUp,
                            isLoading: _isLoading,
                            colors: AppColors.primaryGradient,
                          ),
                        ],
                      ),
                    ),
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ', style: AppTextStyles.bodyMedium),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: AppColors.primaryGradient,
                          ).createShader(b),
                          child: const Text('Sign In',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                    ],
                  ).animate(delay: 400.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.neonGreen, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
