import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/app.dart';
import 'package:fbr_taxvault/backend_not_configured_app.dart';
import 'package:fbr_taxvault/core/config/env_config.dart';
import 'package:fbr_taxvault/core/network/secure_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!EnvConfig.isSupabaseConfigured) {
    runApp(const BackendNotConfiguredApp());
    return;
  }

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
  );

  runApp(const ProviderScope(child: EfsTaxVaultApp()));
}
