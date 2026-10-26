import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andropi/agent/agent_client.dart';
import 'package:andropi/agent/agent_controller.dart';
import 'package:andropi/ui/skills_screen.dart';
import 'package:andropi/ui/theme.dart';

import 'skills_rebuild_test.dart' show FakeClient;

void main() {
  testWidgets('the list is put back when the system scrolls it to top after resume', (tester) async {
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
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: SkillsScreen(agent: agent, embedded: true))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    double offset() => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    final list = find.byType(ListView);

    await tester.drag(list, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    final before = offset();
    expect(before, greaterThan(300));

    // Background the app, then come back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // The system's scroll-to-top lands ~1s after focus.
    await tester.pump(const Duration(milliseconds: 1100));
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pump();

    // The undo pass runs at +1.3s.
    await tester.pump(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('offset after system jump + undo: ${offset()}');
    expect(offset(), closeTo(before, 1), reason: 'the pre-background offset must be restored');
  });

  testWidgets('no restore when the user is already scrolling after resume', (tester) async {
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
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: SkillsScreen(agent: agent, embedded: true))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    double offset() => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    final list = find.byType(ListView);

    await tester.drag(list, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    final before = offset();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // The user scrolls on their own after coming back; no system jump happens.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    final userOffset = offset();
    expect(userOffset, greaterThan(before));

    await tester.pump(const Duration(milliseconds: 400));
    expect(offset(), closeTo(userOffset, 1), reason: 'user scrolling after resume must not be disturbed');
  });
}
