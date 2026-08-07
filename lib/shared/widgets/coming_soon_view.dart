import 'package:flutter/material.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';

/// Placeholder body for features not yet built (Scanner, Vault, Reports),
/// so navigation is fully wired end-to-end instead of dead routes while
/// each feature is implemented in its own phase.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.hourglass_top_rounded,
      title: title,
      message: message,
    );
  }
}
