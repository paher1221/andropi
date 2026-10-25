import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../agent/agent_controller.dart';
import '../agent/models.dart';
import 'kit.dart';
import 'provider_actions.dart';
import 'theme.dart';
import 'i18n.dart';

/// Picks a provider to add, the way Kelivo's add sheet works: search on top,
/// grouped rows with brand marks, then the connect flow for whatever is tapped.
Future<void> showAddProviderSheet(BuildContext context, AgentController agent) {
  agent.refreshProviders().catchError((_) {});
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddProviderSheet(agent: agent),
  );
}

class _AddProviderSheet extends StatefulWidget {
  const _AddProviderSheet({required this.agent});
  final AgentController agent;

  @override
  State<_AddProviderSheet> createState() => _AddProviderSheetState();
}

class _AddProviderSheetState extends State<_AddProviderSheet> {
  final _search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(ProviderInfo provider) async {
    Navigator.of(context).pop();
    await connectProvider(context, widget.agent, provider);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: ListenableBuilder(
        listenable: widget.agent,
        builder: (context, _) {
          final q = query.trim().toLowerCase();
          final all = widget.agent.providers.where((x) => !x.configured).toList();
          final shown = all
              .where((x) => q.isEmpty || x.name.toLowerCase().contains(q) || x.id.contains(q))
              .toList()
            ..sort((a, b) => b.modelCount.compareTo(a.modelCount));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(child: Text(tr('Add provider'), style: text.titleLarge)),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(LucideIcons.x, size: 20, color: p.muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  controller: _search,
                  autofocus: false,
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: tr('Search providers'),
                    prefixIcon: Icon(LucideIcons.search, size: 18, color: p.faint),
                    isDense: true,
                    filled: true,
                    fillColor: p.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                        child: Text(
                          all.isEmpty ? tr('All providers are connected.') : tr('No matches'),
                          textAlign: TextAlign.center,
                          style: text.bodySmall,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          SettingsGroup(
                            children: [
                              for (final pr in shown)
                                SettingsRow(
                                  leading: BrandTile(id: pr.id, size: 34),
                                  title: pr.name,
                                  subtitle: [
                                    '${pr.modelCount} ${tr('models')}',
                                    if (pr.methods.contains('oauth')) tr('Account'),
                                    if (pr.methods.contains('api_key')) tr('API key'),
                                  ].join(' · '),
                                  onTap: () => _pick(pr),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              tr('This list is what pi supports. Custom endpoints go in models.json.'),
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
