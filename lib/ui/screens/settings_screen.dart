import 'package:flutter/material.dart';

import 'stub.dart';

/// Settings (A11); the split tunneling rules are one level down.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('НАСТРОЙКИ')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Раздельное туннелирование'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SplitTunnelScreen()),
          ),
        ),
      ],
    ),
  );
}

/// Include/Exclude mode and the list of networks (A09).
class SplitTunnelScreen extends StatelessWidget {
  const SplitTunnelScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('РАЗДЕЛЬНОЕ ТУННЕЛИРОВАНИЕ')),
    body: const StubBody('Здесь будут правила по адресам и подсетям'),
  );
}
