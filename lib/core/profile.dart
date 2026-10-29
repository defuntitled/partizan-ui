import 'package:flutter/foundation.dart';

/// A server in the list. No secrets: the link with the token lives in the secret store,
/// under [id].
@immutable
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.transport,
    this.ownRules = false,
  });

  final int id;
  final String name;
  final String host;
  final int port;
  final String transport;

  /// Uses its own split tunneling rules instead of the shared ones.
  final bool ownRules;

  String get address => host.contains(':') ? '[$host]:$port' : '$host:$port';

  @override
  bool operator ==(Object other) =>
      other is ServerProfile &&
      other.id == id &&
      other.name == name &&
      other.host == host &&
      other.port == port &&
      other.transport == transport &&
      other.ownRules == ownRules;

  @override
  int get hashCode => Object.hash(id, name, host, port, transport, ownRules);

  ServerProfile copyWith({String? name, bool? ownRules}) => ServerProfile(
    id: id,
    name: name ?? this.name,
    host: host,
    port: port,
    transport: transport,
    ownRules: ownRules ?? this.ownRules,
  );

  @override
  String toString() => 'ServerProfile($id, $name, $address, $transport)';
}
