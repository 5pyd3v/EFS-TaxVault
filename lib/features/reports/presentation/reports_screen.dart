import 'package:flutter/material.dart';
import 'package:fbr_taxvault/shared/widgets/coming_soon_view.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const ComingSoonView(
        title: 'No reports yet',
        message:
            'Once you have invoices in your vault, monthly, quarterly, and annual tax summaries will appear here.',
      ),
    );
  }
}
