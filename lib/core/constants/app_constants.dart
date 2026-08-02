class AppConstants {
  // Supabase — injected at build time via --dart-define, never hardcoded
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Queue
  static const int defaultAvgServiceMinutes = 5;
  static const int nearTurnThreshold = 3;
  static const int tokenExpiryMinutes = 30;
  static const int maxGroupSize = 10;
  static const int maxTokensPerUser = 3;

  // Geo-fencing
  static const double geofenceRadiusMeters = 200;

  // Gamification
  static const int pointsOnTimeArrival = 10;
  static const int pointsFirstToken = 50;
  static const int pointsReview = 5;

  // Badges
  static const String badgeFirstToken = 'First Timer';
  static const String badgePunctual = 'Always On Time';
  static const String badgeLoyalist = 'Loyalist';
  static const String badgeGroupLeader = 'Group Leader';
  static const String badge10Tokens = '10 Tokens';
  static const String badge50Tokens = '50 Tokens';

  // Crowd levels
  static const int crowdLowMax = 5;
  static const int crowdMediumMax = 15;

  // Pagination
  static const int pageSize = 20;

  // App
  static const String appName = 'QwikQ';
  static const String appTagline = 'Skip the line. Save your time.';
}