import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/vault/data/vault_repository_impl.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_repository.dart';

enum VaultView { documents, bankTransactions }

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepositoryImpl(ref.watch(supabaseClientProvider));
});

/// Which segment of the merged Vault screen is showing — Documents
/// (invoices/receipts) or Bank Transactions. Bank-transaction scan/review
/// screens set this before navigating back to Vault so the user lands on
/// the segment they were working in.
final selectedVaultViewProvider = StateProvider<VaultView>(
  (ref) => VaultView.documents,
);
