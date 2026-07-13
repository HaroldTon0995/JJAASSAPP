class AppConstants {
  // App general info
  static const String appName = 'JJaass App';

  // Role Names
  static const String roleCustomer = 'customer';
  static const String roleDriver = 'driver';
  static const String roleAdmin = 'admin';

  // Mock latencies and timings
  static const Duration apiMockDelay = Duration(milliseconds: 800);
  static const Duration splashDelay = Duration(seconds: 2);

  // Layout limits & Padding values
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double borderRadius = 12.0;

  // Shared Preferences or Storage Keys (if needed)
  static const String keyUserRole = 'user_role';
  static const String keyIsLoggedIn = 'is_logged_in';

  // Supabase Configuration
  // IMPORTANT: Replace these placeholders with your actual Supabase project credentials.
  static const String supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_PROJECT_ANON_KEY';
}
