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
  });

  final int id;
  final String name;
  final String host;
  final int port;
  final String transport;

  String get address => host.contains(':') ? '[$host]:$port' : '$host:$port';

  @override
  bool operator ==(Object other) =>
      other is ServerProfile &&
      other.id == id &&
      other.name == name &&
      other.host == host &&
      other.port == port &&
      other.transport == transport;

  @override
  int get hashCode => Object.hash(id, name, host, port, transport);

  @override
  String toString() => 'ServerProfile($id, $name, $address, $transport)';
}
