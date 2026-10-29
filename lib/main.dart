import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/local_profile_store.dart';
import 'platform/channel_vpn_bridge.dart';
import 'platform/vault_store.dart';
import 'state/profiles.dart';
import 'state/vpn.dart';
import 'ui/screens/about_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicenses();
  runApp(const _Boot());
}

/// Shows the splash while the storage opens, at least [_minimum], then the app.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  static const _minimum = Duration(milliseconds: 1200);
  LocalProfileStore? _profiles;

  @override
  void initState() {
    super.initState();
    final shown = Future<void>.delayed(_minimum);
    _open().then((profiles) async {
      await shown;
      if (mounted) setState(() => _profiles = profiles);
    });
  }

  static Future<LocalProfileStore> _open() async {
    final profiles = LocalProfileStore(AppDatabase.open(), const VaultStore());
    // The tile and the widget read links natively; move those A07–A09 kept elsewhere.
    final existing = await profiles.watchAll().first;
    await migrateLinks(
      from: const KeystoreSecretStore(),
      to: const VaultStore(),
      keys: [for (final p in existing) LocalProfileStore.secretKey(p.id)],
    );
    return profiles;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: profiles == null
          ? MaterialApp(
              theme: partizanTheme(),
              debugShowCheckedModeBanner: false,
              home: const SplashScreen(),
            )
          : ProviderScope(
              overrides: [
                vpnBridgeProvider.overrideWithValue(const ChannelVpnBridge()),
                profileStoreProvider.overrideWithValue(profiles),
              ],
              child: const PartizanApp(),
            ),
    );
  }
}
