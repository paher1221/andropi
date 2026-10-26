import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andropi/agent/agent_client.dart';
import 'package:andropi/agent/agent_controller.dart';
import 'package:andropi/ui/skills_screen.dart';
import 'package:andropi/ui/theme.dart';

import 'skills_rebuild_test.dart' show FakeClient;

/// Lets the test animate [MediaQueryData.viewInsets], like a real keyboard.
class InsetHarness extends StatefulWidget {
  const InsetHarness({super.key, required this.agent});
  final AgentController agent;

  @override
  State<InsetHarness> createState() => _InsetHarnessState();
}

class _InsetHarnessState extends State<InsetHarness> {
  double inset = 0;

  void set(double v) => setState(() => inset = v);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
      child: Scaffold(body: SkillsScreen(agent: widget.agent, embedded: true)),
    );
  }
}

void main() {
  testWidgets('skills list with keyboard insets collapsing during scroll', (tester) async {
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
    final harnessKey = GlobalKey<_InsetHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: InsetHarness(key: harnessKey, agent: agent),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    double offset() => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    final list = find.byType(ListView);

    // Keyboard "open".
    await tester.tap(find.byType(TextField).first);
    await tester.pump(const Duration(milliseconds: 50));
    harnessKey.currentState!.set(300);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 200));
    final withKeyboard = offset();
    // ignore: avoid_print
    print('offset with keyboard open: $withKeyboard');

    // The keyboard animates away while the finger keeps scrolling.
    for (var i = 1; i <= 10; i++) {
      harnessKey.currentState!.set(300 - 30.0 * i);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 200));
    final afterKeyboard = offset();
    // ignore: avoid_print
    print('offset after keyboard closed: $afterKeyboard');

    // Then a plain upward drag afterwards: it must not jump back to the top.
    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    final next = offset();
    // ignore: avoid_print
    print('offset after next drag: $next');

    expect(next, greaterThanOrEqualTo(afterKeyboard), reason: 'scrolling must continue from where it was');
  });
}
