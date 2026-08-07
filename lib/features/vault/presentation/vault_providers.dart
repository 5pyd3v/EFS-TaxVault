import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/vault/data/vault_repository_impl.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_repository.dart';

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepositoryImpl(ref.watch(supabaseClientProvider));
});
