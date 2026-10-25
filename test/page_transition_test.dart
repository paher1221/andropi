import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andropi/ui/theme.dart';

/// Kelivo configures no page transitions, so pages move with Flutter's stock
/// animation. This pins that down: the zoom/fade on Android, the Cupertino slide
/// (with edge-swipe back) on Apple platforms.
void main() {
  test('pages use the stock Flutter transitions, like Kelivo', () {
    final builders = buildTheme(Brightness.light).pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.android], isA<ZoomPageTransitionsBuilder>());
    expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
    expect(builders[TargetPlatform.macOS], isA<CupertinoPageTransitionsBuilder>());
  });
}
