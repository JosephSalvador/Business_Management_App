import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/system_font_service.dart';

/// Holds the user's system font scale factor.
///
/// Font SIZE scaling is handled automatically by Flutter's MediaQuery.
/// This provider is available as a backup for custom use cases.
final systemFontScaleProvider = FutureProvider<double>((ref) async {
  return SystemFontService.getFontScale();
});
