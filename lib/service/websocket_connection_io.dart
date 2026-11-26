import 'dart:io';

import 'package:web_socket_channel/io.dart';

import 'exponential_backoff.dart' show awaitWebSocketConnectionReady;

/// Opens a native WebSocket without retaining timed-out HTTP upgrade requests.
Future<IOWebSocketChannel> connectNativeWebSocket(
  String url, {
  Map<String, dynamic>? headers,
  Iterable<String>? protocols,
  Duration? pingInterval,
}) async {
  final client = HttpClient();
  try {
    final channel = IOWebSocketChannel.connect(
      url,
      headers: headers,
      protocols: protocols,
      pingInterval: pingInterval,
      customClient: client,
    );
    await awaitWebSocketConnectionReady(channel.ready);
    return channel;
  } finally {
    // A successful upgrade detaches its socket from this client. Before that,
    // force-close aborts the pending request instead of leaving it to accumulate.
    client.close(force: true);
  }
}
