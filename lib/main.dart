import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'agent/agent_client.dart';
import 'agent/agent_controller.dart';
import 'ui/app_lock.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding.dart';
import 'ui/kit.dart';
import 'ui/theme.dart';
import 'ui/i18n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Preferences (theme, onboarding, language) come from a file inside the app's private dir.
  await Appearance.instance.load();
  final agent = AgentController(AgentClient())..boot();
  runApp(AndroPiApp(agent: agent));
}

class AndroPiApp extends StatelessWidget {
  const AndroPiApp({super.key, required this.agent});
  final AgentController agent;

  @override
  Widget build(BuildContext context) {
    final appearance = Appearance.instance;
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => MaterialApp(
        title: tr('AndroPI'),
        debugShowCheckedModeBanner: false,
        // Material's own widgets (text selection menu, pickers, tooltips) follow the
        // same language as the rest of the UI.
        locale: Locale(appearance.language),
        supportedLocales: const [Locale('en'), Locale('id'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        themeMode: appearance.value,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(appearance.textScale * MediaQuery.textScalerOf(context).scale(14) / 14),
          ),
          child: AppLockGate(child: child!),
        ),
        home: ListenableBuilder(
          listenable: agent,
          builder: (context, _) => AnimatedSwitcher(
            duration: Duration(milliseconds: 250),
            child: !appearance.onboarded
                ? OnboardingScreen(agent: agent)
                : switch (agent.status) {
                    BootStatus.ready => HomeShell(agent: agent),
                    BootStatus.starting => _Boot(),
                    BootStatus.failed => _BootFailed(agent: agent),
                  },
          ),
        ),
      ),
    );
  }
}

class _Boot extends StatelessWidget {
  const _Boot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoMark(size: 56),
            SizedBox(height: 20),
            SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 14),
            Text(tr('Starting agent'), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _BootFailed extends StatelessWidget {
  const _BootFailed({required this.agent});
  final AgentController agent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 32),
              Text(tr('The agent could not start'), style: text.headlineSmall),
              SizedBox(height: 8),
              Text(tr('Details from the runtime are below.'), style: text.bodyMedium?.copyWith(color: p.muted)),
              SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      agent.bootError ?? tr('Unknown error'),
                      style: TextStyle(fontFamily: mono, fontSize: 12, height: 1.5, color: p.text),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              FilledButton(onPressed: agent.boot, child: Text(tr('Try again'))),
            ],
          ),
        ),
      ),
    );
  }
}
