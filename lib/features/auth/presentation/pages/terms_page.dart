import 'package:flutter/material.dart';

import '../../../../l10n/loc.dart';

/// Plain-language summary of the merchant agreement. The full legal document
/// lives with the business; this screen gives the register flow something
/// honest to link to.
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.termsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _section(context, loc.termsAccountTitle, loc.termsAccountBody),
            _section(context, loc.termsDataTitle, loc.termsDataBody),
            _section(context, loc.termsPrivacyTitle, loc.termsPrivacyBody),
            _section(context, loc.termsPaymentsTitle, loc.termsPaymentsBody),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.termsOk),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
