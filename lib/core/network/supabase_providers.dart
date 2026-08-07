import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the [SupabaseClient] singleton created by `Supabase.initialize`
/// in `main.dart` (via [SecureSessionStorage]) to the rest of the app
/// through Riverpod, so repositories depend on this provider rather than
/// reaching for `Supabase.instance.client` directly.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Emits every auth state change (sign in, sign out, token refresh) so the
/// router and feature providers can react without polling.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});
