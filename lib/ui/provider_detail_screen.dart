import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../agent/agent_controller.dart';
import '../agent/models.dart';
import 'custom_provider_sheet.dart';
import 'kit.dart';
import 'provider_actions.dart';
import 'theme.dart';
import 'i18n.dart';

/// One provider in detail, after Kelivo's provider page: a brand header, a
/// segmented switch between its models and its connection, and the models it
/// offers — tapping one makes it the model the agent runs.
class ProviderDetailScreen extends StatefulWidget {
  const ProviderDetailScreen({super.key, required this.agent, required this.providerId});
  final AgentController agent;
  final String providerId;

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  final _search = TextEditingController();
  String query = '';
  int tab = 0;
  List<ModelInfo>? models;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await widget.agent.modelsFor(widget.providerId);
      list.sort((a, b) => (b.contextWindow ?? 0).compareTo(a.contextWindow ?? 0));
      if (mounted) setState(() => models = list);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  ProviderInfo? get provider {
    for (final p in widget.agent.providers) {
      if (p.id == widget.providerId) return p;
    }
    return null;
  }

  /// Set when this provider lives in models.json (added by the user).
  CustomProvider? get own {
    for (final c in widget.agent.customProviders) {
      if (c.id == widget.providerId) return c;
    }
    return null;
  }

  Future<void> _select(ModelInfo m) async {
    final agent = widget.agent;
    try {
      await agent.setModel(m);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Using')} ${m.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _edit(CustomProvider c) async {
    await showCustomProviderSheet(context, widget.agent, existing: c);
    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(CustomProvider c) async {
    final p = context.palette;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Remove provider?'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                tr('Its models, endpoint and key are deleted from models.json on this device.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: p.danger),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(tr('Remove')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    await widget.agent.deleteProvider(c.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.agent,
      builder: (context, _) {
        final pr = provider;
        final c = own;
        final p = context.palette;
        final text = Theme.of(context).textTheme;
        final current = widget.agent.model;
        final name = c?.name ?? pr?.name ?? widget.providerId;
        final configured = c != null ? c.hasKey : (pr?.configured ?? false);

        final q = query.trim().toLowerCase();
        final fromAgent = (models ?? const <ModelInfo>[])
            .where((m) => q.isEmpty || m.name.toLowerCase().contains(q) || m.id.toLowerCase().contains(q))
            .toList();
        final local = [
          for (final m in c?.models ?? const <CustomModel>[])
            ModelInfo({
              'provider': widget.providerId,
              'id': m.id,
              'name': m.name,
              'contextWindow': m.contextWindow,
              'reasoning': m.reasoning,
            }),
        ];
        final shown = fromAgent.isNotEmpty ? fromAgent : local;
        final count = shown.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              if (c != null)
                IconButton(
                  tooltip: tr('Edit provider'),
                  onPressed: () => _edit(c),
                  icon: const Icon(LucideIcons.penLine, size: 18),
                ),
              IconButton(
                tooltip: tr('Refresh'),
                onPressed: loading ? null : _load,
                icon: const Icon(LucideIcons.refreshCw, size: 19),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              _Header(
                id: widget.providerId,
                name: name,
                modelCount: count,
                configured: configured,
                oauth: pr?.oauth ?? false,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _Tabs(
                  index: tab,
                  onChanged: (i) => setState(() => tab = i),
                  left: (LucideIcons.cpu, tr('Models')),
                  right: (LucideIcons.plugZap, tr('Connection')),
                ),
              ),
              Expanded(
                child: tab == 0
                    ? _modelsTab(context, shown: shown, current: current, configured: configured)
                    : _connectionTab(context, pr: pr, c: c, count: count, text: text, p: p),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modelsTab(
    BuildContext context, {
    required List<ModelInfo> shown,
    required ModelInfo? current,
    required bool configured,
  }) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    if (loading && shown.isEmpty) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.muted));
    }
    if (error != null && shown.isEmpty) {
      return _Note(
        icon: LucideIcons.triangleAlert,
        title: tr('The agent could not start'),
        body: error!,
        action: TextButton(onPressed: _load, child: Text(tr('Retry'))),
      );
    }
    if (shown.isEmpty) {
      return _Note(
        icon: LucideIcons.cpu,
        title: tr('No models yet'),
        body: tr('Add a model ID to this provider.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (shown.length > 8)
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: tr('Search models'),
              prefixIcon: Icon(LucideIcons.search, size: 18, color: p.faint),
              isDense: true,
              filled: true,
              fillColor: p.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        if (shown.length > 8) const SizedBox(height: 12),
        SettingsGroup(
          children: [
            for (final m in shown)
              SettingsRow(
                title: m.name,
                subtitle: [
                  if (m.contextWindow != null) '${_context(m.contextWindow!)} ${tr('context')}',
                  if (m.reasoning) tr('Reasoning'),
                  if (m.acceptsImages) tr('Images'),
                ].join(' · '),
                onTap: configured ? () => _select(m) : null,
                trailing: current?.key == m.key ? Icon(LucideIcons.check, size: 19, color: p.accent) : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            configured ? tr('Tap a model to use it for new messages.') : tr('Connect a provider to start'),
            style: text.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _connectionTab(
    BuildContext context, {
    required ProviderInfo? pr,
    required CustomProvider? c,
    required int count,
    required TextTheme text,
    required Palette p,
  }) {
    if (c != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SettingsGroup(
            children: [
              SettingsRow(
                title: tr('Status'),
                trailing: Pill(c.hasKey ? tr('Connected') : tr('No key'), color: c.hasKey ? p.success : p.warning, dot: true),
              ),
              SettingsRow(title: tr('API endpoint'), subtitle: c.baseUrl, ),
              SettingsRow(title: tr('API format'), subtitle: c.api),
              SettingsRow(
                title: tr('API key'),
                subtitle: c.hasKey ? '••••••••' : tr('Not set'),
              ),
              SettingsRow(title: tr('Models'), subtitle: '$count'),
              SettingsRow(title: 'Provider ID', subtitle: c.id),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _edit(c),
            icon: const Icon(LucideIcons.penLine, size: 17),
            label: Text(tr('Edit provider')),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: p.danger),
            onPressed: () => _delete(c),
            child: Text(tr('Remove provider')),
          ),
          const SizedBox(height: 16),
          Text(tr('Stored in models.json on this device, next to the agent.'), style: text.bodySmall),
        ],
      );
    }

    if (pr == null) return const SizedBox.shrink();
    final connected = pr.configured;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        SettingsGroup(
          children: [
            SettingsRow(
              title: tr('Status'),
              trailing: connected
                  ? Pill(pr.oauth ? tr('Signed in') : tr('API key'), color: p.success, dot: true)
                  : Pill(tr('Not connected'), color: p.muted, dot: true),
            ),
            SettingsRow(
              title: tr('Sign-in method'),
              subtitle: pr.methods.isEmpty
                  ? tr('Ambient credentials')
                  : pr.methods.map((m) => m == 'oauth' ? tr('Account') : tr('API key')).join(' · '),
            ),
            SettingsRow(title: tr('Models'), subtitle: '$count'),
            SettingsRow(title: 'Provider ID', subtitle: pr.id),
            if (widget.agent.model?.provider == pr.id)
              SettingsRow(title: tr('Current model'), subtitle: widget.agent.model?.name ?? '—'),
          ],
        ),
        const SizedBox(height: 18),
        if (!connected)
          FilledButton(
            onPressed: () => connectProvider(context, widget.agent, pr),
            child: Text(tr('Connect')),
          )
        else ...[
          FilledButton(
            onPressed: () => connectProvider(context, widget.agent, pr),
            child: Text(tr('Sign in again')),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: p.danger),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await disconnectProvider(context, widget.agent, pr);
              if (mounted && provider?.configured != true) navigator.maybePop();
            },
            child: Text(tr('Disconnect')),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          tr('The key is stored on this device only, in the agent directory.'),
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// Brand header: mark, name, how many models, and where it stands.
class _Header extends StatelessWidget {
  const _Header({
    required this.id,
    required this.name,
    required this.modelCount,
    required this.configured,
    required this.oauth,
  });
  final String id;
  final String name;
  final int modelCount;
  final bool configured;
  final bool oauth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          BrandTile(id: id, size: 62),
          const SizedBox(height: 12),
          Text(name, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('$modelCount ${tr('models')}', style: text.bodySmall),
          const SizedBox(height: 10),
          configured
              ? Pill(oauth ? tr('Signed in') : tr('Connected'), color: p.success, dot: true)
              : Pill(tr('Not connected'), color: p.faint, dot: true),
        ],
      ),
    );
  }
}

/// Two-segment control, like the bottom tabs on Kelivo's provider page.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged, required this.left, required this.right});
  final int index;
  final ValueChanged<int> onChanged;
  final (IconData, String) left;
  final (IconData, String) right;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: index == i ? (dark ? p.raised : p.bg) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(i == 0 ? left.$1 : right.$1, size: 16, color: index == i ? p.text : p.muted),
                      const SizedBox(width: 7),
                      Text(
                        i == 0 ? left.$2 : right.$2,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: index == i ? FontWeight.w600 : FontWeight.w500,
                          color: index == i ? p.text : p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.title, this.body = '', this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              Icon(icon, size: 24, color: p.faint),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center, style: text.titleSmall),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(body, textAlign: TextAlign.center, style: text.bodySmall),
              ],
              if (action != null) ...[const SizedBox(height: 14), action!],
            ],
          ),
        ),
      ],
    );
  }
}

String _context(int window) {
  if (window >= 1000000) return '${(window / 1000000).toStringAsFixed(window % 1000000 == 0 ? 0 : 1)}M';
  if (window >= 1000) return '${(window / 1000).round()}K';
  return '$window';
}
