import 'package:flutter/material.dart';

import '../../../../shared/widgets/wave_background/wave_background.dart';

/// Full-screen wave background for auth screens.
/// Provides a [Scaffold] with [SafeArea] and wave decoration.
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaveBackground(
        child: SafeArea(
          child: child,
        ),
      ),
    );
  }
}
