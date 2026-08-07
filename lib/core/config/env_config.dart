/// Build-time configuration. Defaults point at the project's real Supabase
/// instance so `flutter run` works with no extra flags; pass `--dart-define`
/// to point at a different project (e.g. a separate staging instance)
/// without touching this file:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// Nothing sensitive lives in the Flutter bundle either way: the Supabase
/// anon/publishable key is safe to ship because RLS is what actually
/// protects data, and the Gemini API key never enters this app at all — it
/// stays server-side in a Supabase Edge Function.
abstract final class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wahobeoikyasfsmjpitr.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2AGRb_VfWREPQ35nOHHh0g_9yTLYXnt',
  );

  /// False until a real project is wired up via --dart-define. The app
  /// still boots in this state and shows a "backend not configured" screen
  /// instead of crashing, so the UI/design system stays reviewable before
  /// a Supabase project exists.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
