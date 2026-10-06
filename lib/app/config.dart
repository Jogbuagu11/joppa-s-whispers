// App-safe configuration. Service-role key is NEVER here.
// Values are loaded from .env at build time via --dart-define.
// For local dev, values are hardcoded below (anon key is safe in app).
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sincvubcsnqzjefzsifq.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpbmN2dWJjc25xemplZnpzaWZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTExNDQxMDUsImV4cCI6MjEwNjcyMDEwNX0.hUOLkC_F_iV3-aH4X3zO9uGc9eTS7Q4W4agQOOv9RNk',
  );

  // Google Sign-In client IDs (public identifiers, safe in the app).
  // The iOS one must also be in ios/Runner/Info.plist (GIDClientID + URL scheme).
  static const String googleIosClientId =
      '913228851937-io3n800iu6ek0c29ch1p2o3i4nqn83vo.apps.googleusercontent.com';

  /// The "web" client: the one Supabase checks sign-in tokens against.
  static const String googleWebClientId =
      '913228851937-g1lai48o6vv1fej5cmpimn0l135ogv1p.apps.googleusercontent.com';

  // AdMob IDs — filled in at Milestone 18
  static const String admobAppIdIos = '';
  static const String admobAppIdAndroid = '';
}
