/// What the app reads from a `partizan://` link itself: where the server is. The token stays
/// inside the link, which only the secret store and the core ever see; the core validates the
/// rest (`check_uri`).
class LinkInfo {
  const LinkInfo({
    required this.host,
    required this.port,
    required this.transport,
  });

  final String host;
  final int port;

  /// `auto`, `quic` or `tls`.
  final String transport;

  static const scheme = 'partizan://';
  static const defaultPort = 443;

  /// `null` unless `link` has the shape `partizan://<id>:<token>@<host>[:<port>]?…`.
  static LinkInfo? parse(String link) {
    link = link.trim();
    if (!link.startsWith(scheme)) return null;
    final rest = link.substring(scheme.length);
    final query = rest.indexOf('?');
    final authority = query < 0 ? rest : rest.substring(0, query);
    final at = authority.lastIndexOf('@');
    if (at <= 0 || !authority.substring(0, at).contains(':')) return null;
    final hostPort = authority.substring(at + 1);
    String host;
    String? port;
    if (hostPort.startsWith('[')) {
      final close = hostPort.indexOf(']');
      if (close < 0) return null;
      host = hostPort.substring(1, close);
      final tail = hostPort.substring(close + 1);
      if (tail.isNotEmpty) {
        if (!tail.startsWith(':')) return null;
        port = tail.substring(1);
      }
    } else {
      final colon = hostPort.lastIndexOf(':');
      host = colon < 0 ? hostPort : hostPort.substring(0, colon);
      if (colon >= 0) port = hostPort.substring(colon + 1);
    }
    if (host.isEmpty) return null;
    final portNumber = port == null ? defaultPort : int.tryParse(port);
    if (portNumber == null || portNumber < 1 || portNumber > 65535) return null;
    var transport = 'auto';
    if (query >= 0) {
      for (final pair in rest.substring(query + 1).split('&')) {
        if (pair.startsWith('transport=')) {
          transport = pair.substring('transport='.length);
        }
      }
    }
    return LinkInfo(host: host, port: portNumber, transport: transport);
  }

  /// `host:port`, IPv6 in brackets.
  String get address => host.contains(':') ? '[$host]:$port' : '$host:$port';
}
