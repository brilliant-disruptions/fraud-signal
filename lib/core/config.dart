/// Build-time configuration.
///
/// Pass Supabase credentials with dart-define to run against production:
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
/// Without them the app runs on the in-memory demo repository.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get useSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static const appName = 'Fraud Signal';

  /// Demo only: sign in as this demo account on launch (for screenshots and
  /// walkthroughs). Ignored when Supabase is configured.
  static const demoAutoSignIn = String.fromEnvironment('DEMO_AUTO_SIGNIN');
}
