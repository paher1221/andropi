import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:andropi/agent/agent_client.dart';
import 'package:andropi/agent/agent_controller.dart';
import 'package:andropi/main.dart';
import 'package:andropi/ui/theme.dart';

/// Fakes the host and lets the test push records, like the real host does.
class FakeClient extends AgentClient {
  final recordsSink = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get records => recordsSink.stream;

  void push(Map<String, dynamic> record) => recordsSink.add(record);

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
  testWidgets('skills tab survives agent rebuilds mid-scroll inside the real app shell', (tester) async {
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

    Appearance.instance.onboarded = true;
    final client = FakeClient();
    final agent = AgentController(client)..status = BootStatus.ready;

    await tester.pumpWidget(AndroPiApp(agent: agent));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(LucideIcons.compass));
    await tester.pump(const Duration(milliseconds: 400));

    double offset() => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    final list = find.byType(ListView).last;

    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    final first = offset();
    // ignore: avoid_print
    print('offset after 1st drag: $first');

    // A state record from the host: the app rebuilds from the root.
    client.push({'type': 'state', 'state': {'model': null, 'thinkingLevel': 'off', 'cwd': '/tmp/ws'}});
    agent.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    final afterRecord = offset();
    // ignore: avoid_print
    print('offset after host record: $afterRecord');

    await tester.drag(list, const Offset(0, -300));
    agent.notifyListeners();
    await tester.pump(const Duration(milliseconds: 300));
    final second = offset();
    // ignore: avoid_print
    print('offset after 2nd drag: $second');

    expect(afterRecord, closeTo(first, 1), reason: 'a host record must not move the list');
    expect(second, greaterThanOrEqualTo(first), reason: 'drags must accumulate, not reset');
  });
}
