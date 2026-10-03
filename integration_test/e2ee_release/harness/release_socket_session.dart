import 'dart:async';

import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:web_socket_channel/io.dart';

import 'registered_fixture.dart';
import 'release_wire_codec.dart';

abstract class ReleaseSocket {
  Future<void> get ready;
  String? get protocol;
  Stream<Object> get messages;
  void send(Object data);
  Future<void> close();
}

class IoReleaseSocket implements ReleaseSocket {
  IoReleaseSocket(Uri uri, Map<String, String> headers)
    : _channel = IOWebSocketChannel.connect(
        uri,
        headers: headers,
        protocols: ['imboy.v2', 'imboy-json', 'text'],
      );

  final IOWebSocketChannel _channel;
  @override
  Future<void> get ready => _channel.ready;
  @override
  String? get protocol => _channel.protocol;
  @override
  Stream<Object> get messages => _channel.stream.cast<Object>();
  @override
  void send(Object data) => _channel.sink.add(data);
  @override
  Future<void> close() async => _channel.sink.close();
}

/// One device connection. Only a session-validating heartbeat marks it ready.
/// The caller must supply authorized resources and independently verified IDs.
class ReleaseSocketSession {
  ReleaseSocketSession({required this.onFrame, required this.onClosed});

  final void Function(DecodedReleaseFrame) onFrame;
  final void Function() onClosed;
  ReleaseSocket? _socket;
  ReleaseWireCodec? _codec;
  StreamSubscription<Object>? _subscription;
  Completer<void>? _confirmed;
  int _generation = 0;
  bool _connected = false;
  Future<void> _cleanup = Future.value();
  Future<void> get cleanup => _cleanup;
  bool get connected => _connected;
  int get generation => _generation;

  Future<void> connect({
    required Future<ReleaseSocket> Function(Map<String, String>) connector,
    required RegisteredDevice device,
    required String token,
    required String version,
    required Duration timeout,
  }) async {
    _validateInputs(token, version, timeout);
    final cleanup = disconnect();
    final generation = _generation;
    await cleanup;
    if (generation != _generation) throw StateError('connection superseded');
    ReleaseSocket? socket;
    try {
      socket =
          await connector({
                'authorization': 'Bearer $token',
                'did': device.did,
                'cos': device.platform,
                'vsn': version,
              })
              .then((value) async {
                if (generation != _generation) {
                  await value.close();
                  throw StateError('connection superseded');
                }
                return value;
              })
              .timeout(timeout);
      if (generation != _generation) {
        await socket.close();
        throw StateError('connection superseded');
      }
      _socket = socket;
      await socket.ready.timeout(timeout);
      _install(socket, generation);
      await _confirmed!.future.timeout(timeout);
      if (generation != _generation) throw StateError('connection superseded');
      _connected = true;
    } on Object {
      if (generation == _generation) {
        await disconnect();
      } else {
        await _cleanup;
      }
      throw StateError('release socket connection failed');
    }
  }

  void _validateInputs(String token, String version, Duration timeout) {
    if (token.trim().isEmpty ||
        token.contains('\r') ||
        token.contains('\n') ||
        version.trim().isEmpty ||
        version.contains('\r') ||
        version.contains('\n') ||
        timeout <= Duration.zero) {
      throw const FormatException('invalid connection inputs');
    }
  }

  void _install(ReleaseSocket socket, int generation) {
    if (generation != _generation) throw StateError('connection superseded');
    final codec = ReleaseWireCodec(socket.protocol);
    _codec = codec;
    final confirmed = Completer<void>();
    confirmed.future.ignore();
    _confirmed = confirmed;
    _subscription = socket.messages.listen(
      (data) => _receive(data, generation, codec, confirmed),
      onError: (Object _) => _fail(generation, confirmed),
      onDone: () => _fail(generation, confirmed),
    );
    socket.send(codec.framed ? ImboyFrame.heartbeatPing(1) : 'ping');
  }

  void _receive(
    Object data,
    int generation,
    ReleaseWireCodec codec,
    Completer<void> confirmed,
  ) {
    if (generation != _generation) return;
    try {
      final frame = codec.decode(data);
      if (frame.controlType == FrameType.heartbeatPong &&
          (!codec.framed || _matchesProbe(frame.controlPayload))) {
        if (!confirmed.isCompleted) confirmed.complete();
        return;
      }
      if (frame.controlType == FrameType.heartbeatPing) {
        if (frame.controlPayload.length != 2) {
          throw const FormatException('invalid heartbeat');
        }
        final seq = (frame.controlPayload[0] << 8) | frame.controlPayload[1];
        _socket!.send(ImboyFrame.heartbeatPong(seq));
        return;
      }
      if (frame.controlType == FrameType.close ||
          frame.controlType == FrameType.error) {
        _fail(generation, confirmed);
        return;
      }
      if (confirmed.isCompleted) onFrame(frame);
    } on Object {
      _fail(generation, confirmed);
    }
  }

  bool _matchesProbe(List<int> payload) =>
      payload.length == 2 && payload[0] == 0 && payload[1] == 1;

  void _fail(int generation, Completer<void> confirmed) {
    if (generation != _generation) return;
    final wasConfirmed = confirmed.isCompleted;
    if (!confirmed.isCompleted) {
      confirmed.completeError(StateError('release socket session failed'));
    }
    _cleanup = disconnect();
    _cleanup.ignore();
    if (wasConfirmed) onClosed();
  }

  void send(Map<String, dynamic> message) {
    if (!_connected) throw StateError('release socket not confirmed');
    _socket!.send(_codec!.encode(message));
  }

  Future<void> disconnect() async {
    final cleanup = _cleanup;
    _generation++;
    _connected = false;
    final subscription = _subscription;
    final socket = _socket;
    _subscription = null;
    _socket = null;
    _codec = null;
    final confirmed = _confirmed;
    _confirmed = null;
    if (confirmed != null && !confirmed.isCompleted) {
      confirmed.completeError(StateError('release socket disconnected'));
    }
    try {
      await subscription?.cancel();
    } finally {
      try {
        await socket?.close();
      } finally {
        await cleanup;
      }
    }
  }
}
