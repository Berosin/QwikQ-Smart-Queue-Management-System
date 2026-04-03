import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

// ============================================================
// supabase_service.dart
// ============================================================
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }
}

// ============================================================
// auth_service.dart
// ============================================================
class AuthService {
  final _client = SupabaseService.client;

  // Current user
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // Auth state stream
  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  // Sign up with email
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    bool isAdmin = false,
  }) async {
    // 1. Clear any existing session first to prevent account mixing
    await signOut();

    // 2. Perform signup
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName, 
        'phone': phone,
        'role': isAdmin ? 'admin' : 'user',
      },
    );

    // 3. Ensure the public.users record is updated with the correct role immediately
    if (response.user != null) {
      await _client.from('users').update({
        'role': isAdmin ? 'admin' : 'user',
        'full_name': fullName,
        'email': email,
        'phone': phone,
      }).eq('id', response.user!.id);
    }
    
    return response;
  }

  // Sign in with email
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with phone OTP
  Future<void> signInWithPhone(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  // Verify OTP
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) async {
    return _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Get user profile
  Future<UserModel?> getUserProfile(String userId) async {
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return data != null ? UserModel.fromJson(data) : null;
  }

  // Update FCM token
  Future<void> updateFcmToken(String fcmToken) async {
    if (currentUser == null) return;
    await _client
        .from('users')
        .update({'fcm_token': fcmToken})
        .eq('id', currentUser!.id);
  }

  // Update profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (currentUser == null) return;
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    updates['updated_at'] = DateTime.now().toIso8601String();

    await _client.from('users').update(updates).eq('id', currentUser!.id);
  }
}
