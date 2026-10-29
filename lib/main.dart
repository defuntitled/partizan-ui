import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'platform/channel_vpn_bridge.dart';
import 'state/vpn.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        vpnBridgeProvider.overrideWithValue(const ChannelVpnBridge()),
      ],
      child: const PartizanApp(),
    ),
  );
}
