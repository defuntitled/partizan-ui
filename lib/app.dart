import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/profile.dart';
import 'core/profile_store.dart';
import 'core/split.dart';
import 'core/vpn_bridge.dart';
import 'state/profiles.dart';
import 'state/vpn.dart';
import 'ui/screens/connection_screen.dart';
import 'ui/screens/servers_screen.dart';
import 'ui/theme.dart';

class PartizanApp extends ConsumerStatefulWidget {
  const PartizanApp({super.key});

  @override
  ConsumerState<PartizanApp> createState() => _PartizanAppState();
}

class _PartizanAppState extends ConsumerState<PartizanApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    final bridge = ref.read(vpnBridgeProvider);
    // The tile, the widget and the service start what the app would start: keep them told.
    final store = ref.read(profileStoreProvider);
    (ServerProfile, SplitRules)? launch;
    var killSwitch = false;
    var known = false;
    void publish() {
      if (!known) return;
      bridge.publishLaunch(
        launch?.$1,
        launch?.$2 ?? SplitRules.all,
        killSwitch: killSwitch,
      );
    }

    _subscriptions.add(
      watchLaunch(store).listen((value) {
        launch = value;
        known = true;
        publish();
      }),
    );
    _subscriptions.add(
      store.watchKillSwitch().listen((value) {
        killSwitch = value;
        publish();
      }),
    );
    _subscriptions.add(bridge.targets().listen(_go));
  }

  void _go(AppTarget target) {
    switch (target) {
      case AppTarget.servers:
        _navigator.currentState?.push(
          MaterialPageRoute<void>(builder: (_) => const ServersScreen()),
        );
      case AppTarget.connect:
        ref.read(connectRequestsProvider.notifier).request();
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    title: 'partizan',
    theme: partizanTheme(),
    debugShowCheckedModeBanner: false,
    home: const ConnectionScreen(),
  );
}
