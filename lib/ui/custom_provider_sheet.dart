import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../agent/agent_controller.dart';
import '../agent/models.dart';
import 'kit.dart';
import 'theme.dart';
import 'i18n.dart';

/// Add or edit a provider of your own: a name, an endpoint, a key, and the
/// models it serves — fetched from the service where possible, the way Kelivo
/// does it. Saved into pi's models.json.
Future<bool?> showCustomProviderSheet(BuildContext context, AgentController agent, {CustomProvider? existing}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CustomProviderSheet(agent: agent, existing: existing),
  );
}

class _Picked {
  _Picked({required this.id, this.name, this.contextWindow});
  final String id;
  final String? name;
  final int? contextWindow;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name != null && name != id) 'name': name,
    if (contextWindow != null) 'contextWindow': contextWindow,
  };
}

class _CustomProviderSheet extends StatefulWidget {
  const _CustomProviderSheet({required this.agent, this.existing});
  final AgentController agent;
  final CustomProvider? existing;

  @override
  State<_CustomProviderSheet> createState() => _CustomProviderSheetState();
}

class _CustomProviderSheetState extends State<_CustomProviderSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _baseUrl = TextEditingController(text: widget.existing?.baseUrl);
  late final _key = TextEditingController();
  final _manual = TextEditingController();
  final _filter = TextEditingController();

  late String api = widget.existing?.api ?? 'openai-completions';
  late final selected = <String, _Picked>{
    for (final m in widget.existing?.models ?? const <CustomModel>[])
      m.id: _Picked(id: m.id, name: m.name, contextWindow: m.contextWindow),
  };
  List<ModelInfo>? found;
  String? probeError;
  bool probing = false;
  bool saving = false;
  bool showKey = false;
  String filter = '';

  @override
  void dispose() {
    for (final c in [_name, _baseUrl, _key, _manual, _filter]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get canSave => _name.text.trim().isNotEmpty && _baseUrl.text.trim().isNotEmpty && selected.isNotEmpty && !saving;

  Future<void> _probe() async {
    if (_baseUrl.text.trim().isEmpty) {
      setState(() => probeError = tr('Enter the API endpoint first.'));
      return;
    }
    setState(() {
      probing = true;
      probeError = null;
    });
    try {
      final list = await widget.agent.probeModels(
        baseUrl: _baseUrl.text.trim(),
        apiKey: _key.text.trim().isEmpty ? null : _key.text.trim(),
        api: api,
      );
      if (!mounted) return;
      setState(() {
        found = list;
        // Anything already selected stays; preselect everything on a first fetch.
        for (final m in list) {
          selected.putIfAbsent(m.id, () => _Picked(id: m.id, name: m.name == m.id ? null : m.name, contextWindow: m.contextWindow));
        }
      });
    } catch (e) {
      if (mounted) setState(() => probeError = '${tr('Could not fetch models')}: $e');
    } finally {
      if (mounted) setState(() => probing = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.agent.saveProvider(
        id: widget.existing?.id,
        name: _name.text.trim(),
        baseUrl: _baseUrl.text.trim(),
        api: api,
        apiKey: _key.text.trim(),
        models: [for (final m in selected.values) m.toJson()],
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => probeError = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final qi = filter.trim().toLowerCase();
    final shown = (found ?? const <ModelInfo>[])
        .where((m) => qi.isEmpty || m.id.toLowerCase().contains(qi) || m.name.toLowerCase().contains(qi))
        .toList();
    final dialects = widget.agent.apiDialects.isEmpty
        ? const ['openai-completions', 'anthropic-messages', 'google-generative-ai']
        : widget.agent.apiDialects;

    Widget field(
      TextEditingController c,
      String label, {
      String? hint,
      String? helper,
      TextInputType? type,
      bool code = false,
      bool obscure = false,
      Widget? suffix,
      ValueChanged<String>? onChanged,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        autocorrect: false,
        obscureText: obscure,
        enableSuggestions: !obscure,
        onChanged: onChanged ?? (_) => setState(() {}),
        style: code ? const TextStyle(fontFamily: 'GeistMono', fontSize: 13.5) : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          suffixIcon: suffix,
        ),
      ),
    );

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? tr('Custom provider') : tr('Edit provider'),
                      style: text.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x, size: 20, color: p.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  field(_name, tr('Name'), hint: 'My proxy'),
                  field(_baseUrl, tr('API endpoint'), hint: 'https://api.example.com/v1', code: true),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: dialects.contains(api) ? api : dialects.first,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: tr('API format')),
                      items: [
                        for (final d in dialects)
                          DropdownMenuItem(
                            value: d,
                            child: Text(_dialectName(d), overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => api = v ?? api),
                    ),
                  ),
                  field(
                    _key,
                    tr('API key'),
                    hint: widget.existing?.hasKey == true ? tr('Leave empty to keep the saved key') : 'sk-…',
                    obscure: !showKey,
                    code: true,
                    suffix: IconButton(
                      onPressed: () => setState(() => showKey = !showKey),
                      icon: Icon(showKey ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: p.faint),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          found == null ? tr('Models') : '${tr('Models')} · ${selected.length}',
                          style: text.titleSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: probing ? null : _probe,
                        icon: probing
                            ? SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
                              )
                            : const Icon(LucideIcons.download, size: 16),
                        label: Text(tr('Fetch models')),
                      ),
                    ],
                  ),
                  if (probeError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(probeError!, style: text.bodySmall?.copyWith(color: p.danger)),
                    ),
                  if (found != null && found!.isNotEmpty) ...[
                    if (found!.length > 6) ...[
                      TextField(
                        controller: _filter,
                        onChanged: (v) => setState(() => filter = v),
                        decoration: InputDecoration(
                          hintText: tr('Search models'),
                          prefixIcon: Icon(LucideIcons.search, size: 17, color: p.faint),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final m = shown[i];
                          final on = selected.containsKey(m.id);
                          return InkWell(
                            onTap: () => setState(() {
                              if (on) {
                                selected.remove(m.id);
                              } else {
                                selected[m.id] = _Picked(
                                  id: m.id,
                                  name: m.name == m.id ? null : m.name,
                                  contextWindow: m.contextWindow,
                                );
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m.id, style: const TextStyle(fontFamily: mono, fontSize: 13)),
                                        if (m.contextWindow != null)
                                          Text('${_context(m.contextWindow!)} ${tr('context')}', style: text.bodySmall),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    on ? LucideIcons.circleCheck : LucideIcons.circle,
                                    size: 20,
                                    color: on ? p.accent : p.faint,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            for (final m in shown) {
                              selected[m.id] = _Picked(
                                id: m.id,
                                name: m.name == m.id ? null : m.name,
                                contextWindow: m.contextWindow,
                              );
                            }
                          }),
                          child: Text(tr('Select all')),
                        ),
                        TextButton(
                          onPressed: () => setState(() => selected.clear()),
                          child: Text(tr('Clear')),
                        ),
                      ],
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manual,
                          decoration: InputDecoration(
                            hintText: tr('Or type a model ID'),
                            isDense: true,
                          ),
                          style: const TextStyle(fontFamily: mono, fontSize: 13.5),
                          onSubmitted: (_) => _addManual(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addManual,
                        icon: const Icon(LucideIcons.plus, size: 20),
                      ),
                    ],
                  ),
                  if (selected.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in selected.values)
                          InputChip(
                            label: Text(m.id, style: const TextStyle(fontFamily: mono, fontSize: 12)),
                            onDeleted: () => setState(() => selected.remove(m.id)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    tr('Saved to models.json on this device. The agent restarts so pi picks it up.'),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: PrimaryButton(
                label: saving ? tr('Saving…') : tr('Save provider'),
                busy: saving,
                onPressed: canSave ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addManual() {
    final id = _manual.text.trim();
    if (id.isEmpty) return;
    setState(() {
      selected[id] = _Picked(id: id);
      _manual.clear();
    });
  }
}

String _dialectName(String api) => switch (api) {
  'openai-completions' => 'OpenAI ${tr('compatible')}',
  'openai-responses' => 'OpenAI Responses',
  'anthropic-messages' => 'Anthropic Messages',
  'google-generative-ai' => 'Google Gemini',
  'google-vertex' => 'Google Vertex',
  'mistral-conversations' => 'Mistral',
  'azure-openai-responses' => 'Azure OpenAI',
  _ => api,
};

String _context(int window) {
  if (window >= 1000000) return '${(window / 1000000).toStringAsFixed(window % 1000000 == 0 ? 0 : 1)}M';
  if (window >= 1000) return '${(window / 1000).round()}K';
  return '$window';
}
