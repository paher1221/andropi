import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:andropi/agent/agent_client.dart';
import 'package:andropi/agent/agent_controller.dart';
import 'package:andropi/ui/home_shell.dart';
import 'package:andropi/ui/theme.dart';

class FakeClient extends AgentClient {
  @override
  Future<T> call<T>(String type, [Map<String, dynamic> args = const {}]) async {
    switch (type) {
      case 'skills_list':
        return [
          for (var i = 0; i < 40; i++)
            {'name': 'skill-$i', 'description': 'Description of skill $i', 'path': '/tmp/skills/$i', 'source': 'local'},
        ] as T;
      case 'skills_search':
        return <dynamic>[] as T;
      case 'sessions':
        return <dynamic>[] as T;
      case 'projects':
        return <dynamic>[] as T;
      case 'runs':
        return <dynamic>[] as T;
      case 'integrations':
        return {'github': null, 'vercel': null, 'ssh': {'hosts': <dynamic>[], 'publicKey': 'key'}} as T;
      case 'container_status':
        return <dynamic, dynamic>{'installed': false, 'enabled': false, 'distros': <dynamic>[]} as T;
      case 'settings_get':
        return <dynamic, dynamic>{'approvalMode': 'ask_risky', 'fallbackModels': <dynamic>[], 'dailyBudget': 0} as T;
      case 'state':
      case 'hello':
        return {
          'model': null,
          'thinkingLevel': 'off',
          'thinkingLevels': <dynamic>['off'],
          'cwd': '/tmp/ws',
        } as T;
      default:
        throw StateError('FakeClient: unexpected rpc "$type"');
    }
  }

  @override
  Future<Map<String, dynamic>?> takeLaunch() async => null;
  @override
  Future<void> requestNotifications() async {}
  @override
  Future<void> notify(int id, String title, String body) async {}
  @override
  Future<void> setBusy(bool busy) async {}
  @override
  Future<void> openUrl(String url) async {}
  @override
  Future<void> keepAlive(bool on, {String? text}) async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<String?> listen({String? language}) async => null;
}

void main() {
  testWidgets('skills tab inside HomeShell keeps its scroll offset across drags', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Silence the platform channels the shell touches (haptics, agent host).
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
      MaterialApp(theme: buildTheme(Brightness.light), home: HomeShell(agent: agent)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Switch to the Skills tab.
    await tester.tap(find.byIcon(LucideIcons.compass));
    await tester.pump(const Duration(milliseconds: 400));

    double offset() => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    final list = find.byType(ListView).last;

    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    final first = offset();
    // ignore: avoid_print
    print('offset after 1st drag: $first');

    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    final second = offset();
    // ignore: avoid_print
    print('offset after 2nd drag: $second');

    await tester.fling(list, const Offset(0, -600), 3000);
    await tester.pump(const Duration(seconds: 2));
    final third = offset();
    // ignore: avoid_print
    print('offset after fling: $third');

    expect(second, greaterThanOrEqualTo(first), reason: 'second drag must not reset toward top');
    expect(third, greaterThanOrEqualTo(second), reason: 'fling must not reset toward top');
  });
}
