import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../agent/agent_controller.dart';
import '../agent/models.dart';
import 'custom_provider_sheet.dart';
import 'kit.dart';
import 'provider_actions.dart';
import 'provider_detail_screen.dart';
import 'theme.dart';
import 'i18n.dart';

/// Providers, laid out like Kelivo's model-provider screen: a search field on
/// top, inset grouped rows with a brand mark, status pill and disclosure, and
/// a detail page per provider.
///
/// Only providers you added yourself (models.json) are listed; pi's built-in
/// ones stay hidden unless the switch at the bottom brings them back.
class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key, required this.agent});
  final AgentController agent;

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final _search = TextEditingController();
  String query = '';
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    widget.agent.refreshProviders().catchError((_) {});
    widget.agent.refreshCustom().catchError((_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => refreshing = true);
    try {
      await widget.agent.refreshProviders();
      await widget.agent.refreshCustom();
    } catch (_) {
      // The agent may still be booting; the list stays as it was.
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> _add() async {
    final saved = await showCustomProviderSheet(context, widget.agent);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Provider saved'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.agent,
      builder: (context, _) {
        final agent = widget.agent;
        final q = query.trim().toLowerCase();
        bool matches(ProviderInfo x) => q.isEmpty || x.name.toLowerCase().contains(q) || x.id.contains(q);

        final custom = agent.customProviders
            .where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.id.contains(q))
            .toList();
        final builtin = Appearance.instance.showBuiltins
            ? agent.providers.where((x) => !x.custom).where(matches).toList()
            : <ProviderInfo>[];

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('Models & providers')),
            actions: [
              IconButton(
                tooltip: tr('Refresh'),
                onPressed: refreshing ? null : _refresh,
                icon: refreshing
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
                      )
                    : const Icon(LucideIcons.refreshCw, size: 19),
              ),
              IconButton(
                tooltip: tr('Custom provider'),
                onPressed: _add,
                icon: const Icon(LucideIcons.plus, size: 21),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              _SearchField(
                controller: _search,
                hint: tr('Search providers'),
                onChanged: (v) => setState(() => query = v),
                onClear: () {
                  _search.clear();
                  setState(() => query = '');
                },
              ),
              SectionLabel(
                tr('My providers'),
                trailing: custom.isEmpty
                    ? null
                    : Text('${custom.length}', style: TextStyle(fontSize: 12, color: p.faint)),
              ),
              if (custom.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    children: [
                      Icon(LucideIcons.server, size: 22, color: p.faint),
                      const SizedBox(height: 10),
                      Text(
                        q.isEmpty ? tr('No providers yet. Add your own endpoint.') : tr('No matches'),
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('Any OpenAI-compatible service works: a key, a base URL and its models.'),
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(LucideIcons.plus, size: 17),
                        label: Text(tr('Add provider')),
                      ),
                    ],
                  ),
                )
              else
                SettingsGroup(
                  children: [
                    for (final c in custom)
                      SettingsRow(
                        leading: BrandTile(id: c.id, size: 34),
                        title: c.name,
                        subtitle: '${c.models.length} ${tr('models')} · ${_host(c.baseUrl)}',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProviderDetailScreen(agent: agent, providerId: c.id),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (agent.model?.provider == c.id)
                              Icon(LucideIcons.check, size: 17, color: p.accent),
                            const SizedBox(width: 2),
                            Icon(LucideIcons.chevronRight, size: 18, color: p.faint),
                          ],
                        ),
                      ),
                  ],
                ),
              if (builtin.isNotEmpty || Appearance.instance.showBuiltins) ...[
                SectionLabel(
                  tr('Built-in'),
                  trailing: Text('${builtin.length}', style: TextStyle(fontSize: 12, color: p.faint)),
                ),
                if (builtin.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text(tr('Nothing matches.'), style: text.bodySmall),
                  )
                else
                  SettingsGroup(
                    children: [
                      for (final pr in builtin)
                        SettingsRow(
                          leading: BrandTile(id: pr.id, size: 34),
                          title: pr.name,
                          subtitle: '${pr.modelCount} ${tr('models')}',
                          onTap: () => connectProvider(context, agent, pr),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pr.configured)
                                Pill(pr.oauth ? tr('Signed in') : tr('API key'), color: p.success, dot: true),
                              const SizedBox(width: 2),
                              Icon(LucideIcons.chevronRight, size: 18, color: p.faint),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
              SectionLabel(tr('Environment')),
              SettingsGroup(
                children: [
                  SettingsRow(title: 'pi', subtitle: agent.info['version']?.toString() ?? '—'),
                  SettingsRow(title: 'Node.js', subtitle: agent.info['node']?.toString() ?? '—'),
                  SettingsRow(
                    title: tr('Workspace'),
                    subtitle: agent.info['workspace']?.toString() ?? '—',
                  ),
                  SettingsRow(
                    title: tr('Agent directory'),
                    subtitle: agent.info['agentDir']?.toString() ?? '—',
                  ),
                  SettingsRow(
                    title: tr('Show built-in providers'),
                    subtitle: tr('The providers pi ships with'),
                    trailing: Switch(
                      value: Appearance.instance.showBuiltins,
                      onChanged: (v) => setState(() => Appearance.instance.update(showBuiltins: v)),
                    ),
                  ),
                  SettingsRow(
                    title: tr('Restart agent'),
                    icon: LucideIcons.rotateCw,
                    color: p.warning,
                    onTap: agent.busy ? null : agent.restart,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  tr('Providers and their models live in models.json. Keys stay on this device.'),
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _host(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return url;
  return uri.host + (uri.path.length > 1 ? uri.path.replaceAll(RegExp(r'/+$'), '') : '');
}

/// Rounded, filled search field like the one on Kelivo's provider list.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged, this.onClear});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(LucideIcons.search, size: 18, color: p.faint),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: Icon(LucideIcons.x, size: 16, color: p.faint),
                ),
          isDense: true,
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.accent.withValues(alpha: 0.5)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}
