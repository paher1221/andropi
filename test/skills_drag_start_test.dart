import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:andropi/agent/agent_controller.dart';
import 'package:andropi/ui/home_shell.dart';
import 'package:andropi/ui/theme.dart';

import 'skills_rebuild_test.dart' show FakeClient;

void main() {
  testWidgets('drags starting from different heights on the skills tab', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('andropi/agent'),
      (call) async => null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );

    final agent = AgentController(FakeClient());
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: HomeShell(agent: agent)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(LucideIcons.compass));
    await tester.pump(const Duration(milliseconds: 400));

    double offset() => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

    Future<void> dragFrom(double startY, double dy) async {
      final gesture = await tester.startGesture(Offset(200, startY));
      await gesture.moveBy(Offset(0, dy));
      await tester.pump();
      await gesture.moveBy(Offset(0, dy));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      // ignore: avoid_print
      print('drag from y=$startY dy=$dy -> offset ${offset()}');
    }

    // Scroll down a bit first (mid-screen swipe).
    await dragFrom(400, -300);
    // Now the natural thumb swipes: starting low, various heights.
    // The nav pill's background must not eat the drag starting over it.
    await dragFrom(760, -500);
    expect(offset(), greaterThan(300), reason: 'a swipe starting on the nav pill must scroll the page');
    await dragFrom(700, -500); // inside the nav bar zone
    await dragFrom(700, -500); // just above the nav bar
    await dragFrom(600, -500);
    await dragFrom(400, -500);
    // A fast fling from the bottom area.
    final gesture = await tester.startGesture(const Offset(200, 740));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    // ignore: avoid_print
    print('after fast bottom fling -> offset ${offset()}');
  });
}
