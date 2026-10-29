import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/vpn_status.dart';
import '../../state/profiles.dart';
import '../../state/vpn.dart';
import '../theme.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';

/// Main screen: the tunnel state from the core; tapping it brings the tunnel up or down.
/// The full switch and traffic figures come in A08.
class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});

  static String label(VpnState state) => switch (state) {
    VpnState.idle => 'ПОДКЛЮЧИТЬСЯ',
    VpnState.connecting => 'ПОДКЛЮЧЕНИЕ',
    VpnState.connected => 'ПОДКЛЮЧЕНО',
    VpnState.reconnecting => 'ПЕРЕПОДКЛЮЧЕНИЕ',
    VpnState.revoked => 'ДОСТУП ОТОЗВАН',
    VpnState.error => 'ОШИБКА',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(vpnStatusProvider);
    final active = ref.watch(activeProfileProvider).value;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: PartizanColors.red,
      appBar: AppBar(
        backgroundColor: PartizanColors.red,
        foregroundColor: PartizanColors.black,
        centerTitle: false,
        title: Text(
          'partizan',
          style: text.headlineLarge?.copyWith(
            color: PartizanColors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),
              switch (status) {
                AsyncData(:final value) => _State(
                  status: value,
                  onTap: () => _toggle(context, ref, value.state, active),
                ),
                AsyncError(:final error) => Text(
                  'Ядро недоступно: $error',
                  key: const Key('core-error'),
                  style: text.bodyLarge?.copyWith(color: PartizanColors.black),
                  textAlign: TextAlign.center,
                ),
                _ => const CircularProgressIndicator(
                  color: PartizanColors.black,
                ),
              },
              const Spacer(),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(active?.name ?? 'Сервер не выбран'),
                  subtitle: Text(
                    active?.address ?? 'Добавьте сервер по ссылке partizan://',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ServersScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    VpnState state,
    ServerProfile? active,
  ) async {
    final bridge = ref.read(vpnBridgeProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (isActive(state)) {
        await bridge.stop();
        return;
      }
      if (active == null) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ServersScreen()));
        return;
      }
      // Read from the Keystore only now, for the start.
      final link = await ref.read(profileStoreProvider).link(active.id);
      if (link == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ссылка сервера потеряна, добавьте его заново'),
          ),
        );
        return;
      }
      await bridge.start(uri: link);
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    }
  }
}

class _State extends StatelessWidget {
  const _State({required this.status, required this.onTap});

  final VpnStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final transport = status.transport;
    return InkWell(
      key: const Key('vpn-toggle'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                ConnectionScreen.label(status.state),
                key: const Key('vpn-state'),
                style: text.displayMedium?.copyWith(
                  color: PartizanColors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (transport != null)
              Text(
                [
                  transport.toUpperCase(),
                  if (status.rttMs case final rtt?) '$rtt мс',
                ].join(' · '),
                key: const Key('vpn-transport'),
                style: text.titleMedium?.copyWith(color: PartizanColors.black),
              ),
            if (status.error case final error?)
              Text(
                error,
                style: text.bodyMedium?.copyWith(color: PartizanColors.black),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
