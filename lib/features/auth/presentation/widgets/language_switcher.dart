import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/local/locale_store.dart';
import '../../../../l10n/loc.dart';

/// EN/SW toggle shown on the public auth screens. Switching is instant —
/// [MaterialApp] rebuilds from the locale provider.
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final loc = context.loc;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'sw',
          label: Text(loc.languageSwahili),
        ),
        ButtonSegment(
          value: 'en',
          label: Text(loc.languageEnglish),
        ),
      ],
      selected: {locale.languageCode},
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      onSelectionChanged: (selection) {
        ref.read(localeControllerProvider.notifier).setLocale(
              Locale(selection.first),
            );
      },
    );
  }
}
