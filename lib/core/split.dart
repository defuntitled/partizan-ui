import 'dart:io' show InternetAddress, InternetAddressType;

import 'package:flutter/foundation.dart';

/// What the listed networks mean; mirrors `SplitMode` of the core.
enum SplitMode {
  /// Only the listed networks go through the tunnel, the rest goes direct.
  include,

  /// Everything goes through the tunnel except the listed networks.
  exclude,
}

/// An IPv4 or IPv6 network; host bits are zeroed, a single address is a /32 or /128.
@immutable
class IpNet {
  // ignore: prefer_const_constructors_in_immutables, the bytes are built at runtime.
  IpNet._(this._bytes, this.prefix);

  final Uint8List _bytes;
  final int prefix;

  bool get isV6 => _bytes.length == 16;
  int get maxPrefix => _bytes.length * 8;

  /// `99.84.0.0/16`, `203.0.113.7`, `2606:4700::/32`; `null` for anything else.
  static IpNet? tryParse(String text) {
    text = text.trim();
    if (text.isEmpty) return null;
    final slash = text.indexOf('/');
    final addressText = slash < 0 ? text : text.substring(0, slash);
    final address = InternetAddress.tryParse(addressText);
    if (address == null ||
        (address.type != InternetAddressType.IPv4 &&
            address.type != InternetAddressType.IPv6)) {
      return null;
    }
    // `InternetAddress` also takes forms such as `1.2.3`; only canonical dotted quads pass.
    if (address.type == InternetAddressType.IPv4 &&
        !RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(addressText)) {
      return null;
    }
    final bytes = Uint8List.fromList(address.rawAddress);
    var prefix = bytes.length * 8;
    if (slash >= 0) {
      final digits = text.substring(slash + 1);
      if (!RegExp(r'^\d{1,3}$').hasMatch(digits)) return null;
      prefix = int.parse(digits);
      if (prefix > bytes.length * 8) return null;
    }
    for (var bit = prefix; bit < bytes.length * 8; bit++) {
      bytes[bit >> 3] &= ~(0x80 >> (bit & 7)) & 0xff;
    }
    return IpNet._(bytes, prefix);
  }

  String get address => InternetAddress.fromRawAddress(_bytes).address;

  @override
  String toString() => '$address/$prefix';

  @override
  bool operator ==(Object other) =>
      other is IpNet &&
      other.prefix == prefix &&
      listEquals(other._bytes, _bytes);

  @override
  int get hashCode => Object.hash(prefix, Object.hashAll(_bytes));
}

/// Split tunneling rules, as stored and as handed to the platform.
@immutable
class SplitRules {
  const SplitRules({required this.mode, this.routes = const []});

  /// Until the user changes it, everything goes through the tunnel: nothing leaks.
  static const all = SplitRules(mode: SplitMode.exclude);

  final SplitMode mode;
  final List<IpNet> routes;

  SplitRules copyWith({SplitMode? mode, List<IpNet>? routes}) =>
      SplitRules(mode: mode ?? this.mode, routes: routes ?? this.routes);

  @override
  bool operator ==(Object other) =>
      other is SplitRules &&
      other.mode == mode &&
      listEquals(other.routes, routes);

  @override
  int get hashCode => Object.hash(mode, Object.hashAll(routes));

  @override
  String toString() => 'SplitRules(${mode.name}, ${formatRoutes(routes)})';
}

/// Result of [parseRoutes].
class ParsedRoutes {
  const ParsedRoutes(this.routes, this.rejected);

  /// Valid entries, normalized, duplicates dropped, in file order.
  final List<IpNet> routes;

  /// Entries that are neither an address nor a network, as written.
  final List<String> rejected;
}

/// Parses `99.84.0.0/16, 99.86.0.0/16, 203.0.113.7, 2606:4700::/32`. Entries are separated by
/// commas (line breaks count as commas too); spaces around them and empty entries are
/// ignored. A bad entry never fails the whole list: it lands in [ParsedRoutes.rejected].
ParsedRoutes parseRoutes(String text) {
  final routes = <IpNet>[];
  final seen = <IpNet>{};
  final rejected = <String>[];
  for (final entry in text.split(RegExp(r'[,\r\n]'))) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) continue;
    final net = IpNet.tryParse(trimmed);
    if (net == null) {
      rejected.add(trimmed);
    } else if (seen.add(net)) {
      routes.add(net);
    }
  }
  return ParsedRoutes(routes, rejected);
}

/// The file format [parseRoutes] reads.
String formatRoutes(Iterable<IpNet> routes) => routes.join(', ');

/// `current` with `added` appended, duplicates dropped.
List<IpNet> mergeRoutes(List<IpNet> current, List<IpNet> added) {
  final seen = current.toSet();
  return [...current, ...added.where(seen.add)];
}
