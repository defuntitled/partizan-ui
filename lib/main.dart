import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/local_profile_store.dart';
import 'platform/channel_vpn_bridge.dart';
import 'state/profiles.dart';
import 'state/vpn.dart';

void main() {
  final profiles = LocalProfileStore(
    AppDatabase.open(),
    const KeystoreSecretStore(),
  );
  runApp(
    ProviderScope(
      overrides: [
        vpnBridgeProvider.overrideWithValue(const ChannelVpnBridge()),
        profileStoreProvider.overrideWithValue(profiles),
      ],
      child: const PartizanApp(),
    ),
  );
}
