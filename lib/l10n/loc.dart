import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// Convenience access to the localizations with a Swahili fallback so widget
/// tests (and any context outside MaterialApp delegates) still resolve text.
extension LocX on BuildContext {
  AppLocalizations get loc =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('sw'));
}
