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

  // AdMob IDs — filled in at Milestone 18
  static const String admobAppIdIos = '';
  static const String admobAppIdAndroid = '';
}
