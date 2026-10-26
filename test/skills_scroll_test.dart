import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andropi/agent/agent_client.dart';
import 'package:andropi/agent/agent_controller.dart';
import 'package:andropi/ui/skills_screen.dart';
import 'package:andropi/ui/theme.dart';

/// Answers every RPC locally so the UI can be exercised without the host.
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
        return <dynamic, dynamic>{} as T;
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
  testWidgets('skills list keeps its scroll offset across repeated upward drags', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final agent = AgentController(FakeClient());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: SkillsScreen(agent: agent, embedded: true)),
      ),
    );
    // Let the RPC futures resolve and the sections expand.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    double offset() => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

    final list = find.byType(ListView);
    expect(list, findsOneWidget);

    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    final first = offset();
    // ignore: avoid_print
    print('offset after 1st drag: $first');
    expect(first, greaterThan(100), reason: 'the first drag should scroll down');

    await tester.drag(list, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    final second = offset();
    // ignore: avoid_print
    print('offset after 2nd drag: $second');
    expect(second, greaterThan(first), reason: 'the second drag should scroll further down');

    await tester.fling(list, const Offset(0, -600), 3000);
    await tester.pump(const Duration(seconds: 2));
    final third = offset();
    // ignore: avoid_print
    print('offset after fling: $third');
    expect(third, greaterThanOrEqualTo(second), reason: 'a fling must never move the list back toward the top');
  });
}
