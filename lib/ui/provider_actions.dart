import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../agent/agent_controller.dart';
import '../agent/models.dart';
import 'kit.dart';
import 'login_flow.dart';
import 'theme.dart';
import 'i18n.dart';

/// Connect, re-auth or disconnect a provider. Shared by the provider list, the
/// detail page and the add sheet so the flows stay identical everywhere.

Future<void> connectProvider(BuildContext context, AgentController agent, ProviderInfo provider) async {
  final methods = provider.methods;
  if (methods.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${provider.name} ${tr('uses ambient credentials and cannot be set up here.')}')),
    );
    return;
  }
  var method = methods.first;
  if (methods.length > 1) {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  BrandTile(id: provider.id, size: 38),
                  const SizedBox(width: 12),
                  Expanded(child: Text(provider.name, style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.globe, size: 20),
              title: Text(tr('Sign in with account')),
              subtitle: Text(tr('Use your subscription through the browser')),
              onTap: () => Navigator.of(context).pop('oauth'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.keyRound, size: 20),
              title: Text(tr('Use an API key')),
              subtitle: Text(tr('Paste a key from the provider console')),
              onTap: () => Navigator.of(context).pop('api_key'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    method = picked;
  }
  if (!context.mounted) return;
  final ok = await showLoginSheet(context, agent, provider, method);
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${provider.name} ${tr('connected')}')));
  }
}

Future<bool> confirmDisconnect(BuildContext context, ProviderInfo provider) async {
  final p = context.palette;
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BrandTile(id: provider.id, size: 38),
                const SizedBox(width: 12),
                Expanded(child: Text(provider.name, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 10),
            Text(tr('Remove the stored credential from this device.'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.danger),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('Disconnect')),
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}

Future<void> disconnectProvider(BuildContext context, AgentController agent, ProviderInfo provider) async {
  if (!await confirmDisconnect(context, provider)) return;
  await agent.logout(provider.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${provider.name} ${tr('disconnected')}')));
}
