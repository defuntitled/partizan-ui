import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profiles.dart';
import '../../state/vpn.dart';
import '../theme.dart';
import '../widgets/art.dart';
import 'about_screen.dart';
import 'split_screen.dart';

final _killSwitchProvider = StreamProvider<bool>(
  (ref) => ref.watch(profileStoreProvider).watchKillSwitch(),
);

/// Settings: Kill Switch, split tunneling, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final killSwitch = ref.watch(_killSwitchProvider).value ?? false;
    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));
    return DarkScaffold(
      title: 'НАСТРОЙКИ',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('kill-switch'),
                  title: const Text('Kill Switch'),
                  subtitle: const Text('Блокировать интернет без VPN'),
                  value: killSwitch,
                  onChanged: (on) =>
                      ref.read(profileStoreProvider).setKillSwitch(on),
                ),
                ListTile(
                  key: const Key('system-lock'),
                  tileColor: Colors.transparent,
                  title: const Text('Системная блокировка'),
                  subtitle: const Text(
                    'Защищает и когда приложение не запущено: включите '
                    '«Постоянная VPN» и «Блокировать соединения без VPN»',
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 20),
                  onTap: () =>
                      ref.read(vpnBridgeProvider).openSystemVpnSettings(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Раздельное туннелирование'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const SplitTunnelScreen()),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('О приложении'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const AboutScreen()),
          ),
          const SizedBox(height: 16),
          Text(
            'Kill Switch держит интернет заблокированным, если туннель упал '
            'сам. Нажатие «Отключить» всегда возвращает интернет.',
            style: inter(12, color: PartizanColors.muted),
          ),
        ],
      ),
    );
  }
}
