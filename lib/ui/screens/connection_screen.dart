import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/vpn_status.dart';
import '../../state/profiles.dart';
import '../../state/vpn.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/distressed_title.dart';
import '../widgets/record.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';

/// Main screen: the record is the switch, the headline the core's state.
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
    ref.listen(connectRequestsProvider, (_, _) {
      final state = ref.read(vpnStatusProvider).value?.state ?? VpnState.idle;
      if (!isActive(state)) _toggle(context, ref, state, active);
    });
    final state = status.value?.state ?? VpnState.idle;
    final connecting =
        state == VpnState.connecting || state == VpnState.reconnecting;
    // Black on red; white on the dark background while connecting.
    final ink = connecting ? PartizanColors.white : PartizanColors.black;
    final media = MediaQuery.of(context);
    // Keep the content clear of the stones: they start this far above the bottom edge.
    final clear =
        (Debris.top(media.size.width) - media.padding.bottom - 16).clamp(
          0.0,
          double.infinity,
        ) +
        8;
    final card = Padding(
      padding: const EdgeInsets.only(right: 12, top: 16),
      child: Card(
        color: PartizanColors.black.withValues(alpha: 0.92),
        child: ListTile(
          leading: const Icon(Icons.public),
          title: Text(active?.name ?? 'Сервер не выбран'),
          subtitle: Text(
            active?.address ?? 'Добавьте сервер по ссылке partizan://',
          ),
          trailing: const Icon(Icons.chevron_right),
          tileColor: Colors.transparent,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ServersScreen()),
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: PartizanColors.red,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: connecting ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: Image.asset(Art.connectBackground, fit: BoxFit.cover),
            ),
          ),
          const Positioned.fill(child: Debris()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Worn like the headline.
                      Distressed(child: Logo(height: 64, color: ink)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Настройки',
                        color: ink,
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: clear),
                      child: switch (status) {
                        AsyncData(:final value) => _State(
                          status: value,
                          ink: ink,
                          card: card,
                          onTap: () =>
                              _toggle(context, ref, value.state, active),
                        ),
                        AsyncError(:final error) => Center(
                          child: Text(
                            'Ядро недоступно: $error',
                            key: const Key('core-error'),
                            style: inter(16, color: PartizanColors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        _ => const Center(
                          child: CircularProgressIndicator(
                            color: PartizanColors.black,
                          ),
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      final store = ref.read(profileStoreProvider);
      // Read from the Keystore only now, for the start.
      final link = await store.link(active.id);
      if (link == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ссылка сервера потеряна, добавьте его заново'),
          ),
        );
        return;
      }
      await bridge.start(uri: link, split: await store.rulesFor(active));
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    }
  }
}

class _State extends StatelessWidget {
  const _State({
    required this.status,
    required this.ink,
    required this.card,
    required this.onTap,
  });

  final VpnStatus status;
  final Color ink;

  /// The active server, right under the headline.
  final Widget card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final transport = status.transport;
    return LayoutBuilder(
      builder: (context, box) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The record takes what the rest leaves, up to 82% of the width.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.82),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: RecordToggle(state: status.state, onTap: onTap),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DistressedTitle(
                ConnectionScreen.label(status.state),
                style: oswald(54, weight: 700, color: ink, spacing: 2),
              ),
            ),
            if (status.state == VpnState.idle)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: SizedBox(height: 28, child: LongArrow(color: ink)),
              ),
            if (transport != null)
              Text(
                [
                  transport.toUpperCase(),
                  if (status.rttMs case final rtt?) '$rtt мс',
                ].join(' · '),
                key: const Key('vpn-transport'),
                style: oswald(18, weight: 500, color: ink),
              ),
            if (status.error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: Text(
                  error,
                  style: inter(14, color: ink),
                  textAlign: TextAlign.center,
                ),
              ),
            card,
          ],
        );
      },
    );
  }
}
