import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/queue/book_token_screen.dart';
import '../screens/queue/live_queue_screen.dart';
import '../screens/queue/token_detail_screen.dart';
import '../screens/queue/qr_scan_screen.dart';
import '../screens/shops/nearby_shops_screen.dart';
import '../screens/shops/shop_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/tokens/my_tokens_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/queue_control_screen.dart';
import '../screens/admin/analytics_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // Auth redirect logic handled in splash
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(
          phone: state.extra as String,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/shops',
        builder: (_, __) => const NearbyShopsScreen(),
      ),
      GoRoute(
        path: '/shop/:id',
        builder: (_, state) => ShopDetailScreen(
          shopId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/book/:shopId',
        builder: (_, state) => BookTokenScreen(
          shopId: state.pathParameters['shopId']!,
        ),
      ),
      GoRoute(
        path: '/live-queue/:tokenId',
        builder: (_, state) => LiveQueueScreen(
          tokenId: state.pathParameters['tokenId']!,
        ),
      ),
      GoRoute(
        path: '/token/:tokenId',
        builder: (_, state) => TokenDetailScreen(
          tokenId: state.pathParameters['tokenId']!,
        ),
      ),
      GoRoute(
        path: '/my-tokens',
        builder: (_, __) => const MyTokensScreen(),
      ),
      GoRoute(
        path: '/qr-scan',
        builder: (_, __) => const QrScanScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      // Admin routes
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/queue/:shopId',
        builder: (_, state) => QueueControlScreen(
          shopId: state.pathParameters['shopId']!,
        ),
      ),
      GoRoute(
        path: '/admin/analytics/:shopId',
        builder: (_, state) => AnalyticsScreen(
          shopId: state.pathParameters['shopId']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});