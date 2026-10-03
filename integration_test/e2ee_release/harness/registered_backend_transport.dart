import 'dart:async';

import '../fixture_contract.dart';
import 'backend_transport.dart';
import 'registered_fixture.dart';
import 'registered_wire_binding.dart';
import 'release_socket_session.dart';
import 'release_wire_codec.dart';
import 'server_ack_tracker.dart';

class UnconfirmedDelivery implements Exception {
  const UnconfirmedDelivery();
  @override
  String toString() => 'C11 delivery unconfirmed';
}

/// Registered C2C transport composition. No default endpoint or credentials.
/// A fake connector only proves wiring, never a real-backend/device PASS.
class RegisteredBackendTransport implements ReleaseTransport {
  RegisteredBackendTransport({
    required this.fixture,
    required this.connector,
    required this.tokenResolver,
    required this.version,
    this.timeout = const Duration(seconds: 10),
  }) {
    if (timeout.inMilliseconds < 1) throw ArgumentError('invalid timeout');
  }

  final RegisteredFixture fixture;
  final Future<ReleaseSocket> Function(RegisteredDevice, Map<String, String>)
  connector;
  final Future<String> Function(RegisteredDevice) tokenResolver;
  final String version;
  final Duration timeout;
  final _sessions = <String, ReleaseSocketSession>{};
  final _connecting = <String, Future<void>>{};
  final _connectionEpoch = <String, int>{};
  final _inbox = <String, List<WireFrame>>{};
  final _pending = <(String, String), _PendingDelivery>{};
  final _acks = ServerAckTracker();
  final _clock = Stopwatch();
  bool _started = false;
  @override
  String get layerId => 'registered-backend-c2c';

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _clock.start();
  }

  @override
  Future<void> connectDevice(SynthDevice device) {
    if (!_started) throw StateError('transport not started');
    final registered = fixture.devices[device.deviceId];
    if (registered == null || registered.platform != device.platform) {
      throw const FormatException('device not in registered fixture');
    }
    return _connecting[device.deviceId] ??= _connect(registered)
        .whenComplete(() {
          _connecting.remove(device.deviceId);
        });
  }

  Future<void> _connect(RegisteredDevice device) async {
    final epoch = _connectionEpoch[device.alias] ?? 0;
    final session = _sessions.putIfAbsent(
      device.alias,
      () => ReleaseSocketSession(
        onFrame: (frame) => _receive(device.alias, frame),
        onClosed: () => _unconfirmDevice(device.alias),
      ),
    );
    if (session.connected) return;
    final token = await tokenResolver(device).timeout(timeout);
    if (!_started || epoch != (_connectionEpoch[device.alias] ?? 0)) {
      throw StateError('transport connection cancelled');
    }
    await session.connect(
      connector: (headers) => connector(device, headers),
      device: device,
      token: token,
      version: version,
      timeout: timeout,
    );
  }

  @override
  bool isDeviceConnected(String deviceId) =>
      _sessions[deviceId]?.connected ?? false;

  @override
  Future<DeliveryReceipt> send(WireFrame frame) async {
    final body = RegisteredWireBinding(fixture).prepareC2c(frame);
    final session = _sessions[frame.senderDid];
    if (!_started || session == null || !session.connected) {
      throw const UnconfirmedDelivery();
    }
    final request = PendingServerAck(
      frame.senderDid,
      frame.messageId,
      'C2C',
      _clock.elapsedMilliseconds + timeout.inMilliseconds,
      session.generation,
    );
    _acks.register(request);
    final key = (frame.senderDid, frame.messageId);
    final pending = _PendingDelivery(request);
    _pending[key] = pending;
    pending.timer = Timer(timeout, () {
      _acks.expire(_clock.elapsedMilliseconds);
      _finish(key, false);
    });
    try {
      session.send(body);
    } on Object {
      _acks.disconnect(frame.senderDid, session.generation);
      _unconfirmDevice(frame.senderDid);
    }
    return pending.result.future;
  }

  void _receive(String alias, DecodedReleaseFrame frame) {
    final message = frame.message;
    if (message == null) return;
    final session = _sessions[alias]!;
    final result = _acks.receive(
      deviceAlias: alias,
      connectionGeneration: session.generation,
      now: _clock.elapsedMilliseconds,
      message: message,
    );
    if (result != null) {
      _finish((
        alias,
        result.request.messageId,
      ), result.outcome == ServerAckOutcome.accepted);
      return;
    }
    if (message['type'] != 'C2C') return;
    final recipient = fixture.devices[alias]!;
    final sender = fixture.devices.values
        .where(
          (device) =>
              device.did == message['sender_did'] &&
              device.accountId == message['from']?.toString(),
        )
        .single;
    if (message['to']?.toString() != recipient.accountId ||
        message['id'] is! String) {
      throw const FormatException('inbound recipient mismatch');
    }
    final wire = WireFrame(
      messageId: message['id'] as String,
      senderUid: sender.accountAlias,
      senderDid: sender.alias,
      recipientUid: recipient.accountAlias,
      recipientDid: alias,
      body: message,
    );
    RegisteredWireBinding(fixture).prepareC2c(wire);
    (_inbox[alias] ??= []).add(wire);
  }

  void _finish((String, String) key, bool accepted) {
    final pending = _pending.remove(key);
    if (pending == null) return;
    pending.timer?.cancel();
    if (accepted) {
      pending.result.complete(DeliveryReceipt.accepted);
    } else {
      pending.result.completeError(const UnconfirmedDelivery());
    }
  }

  void _unconfirmDevice(String alias) {
    final keys = _pending.keys.where((key) => key.$1 == alias).toList();
    for (final key in keys) {
      _acks.disconnect(alias, _pending[key]!.request.connectionGeneration);
      _finish(key, false);
    }
  }

  @override
  Future<void> disconnectDevice(SynthDevice device) async {
    _connectionEpoch[device.deviceId] =
        (_connectionEpoch[device.deviceId] ?? 0) + 1;
    _unconfirmDevice(device.deviceId);
    await _sessions[device.deviceId]?.disconnect();
  }

  @override
  List<WireFrame> drainInbox(String deviceId) =>
      List.unmodifiable(_inbox.remove(deviceId) ?? const <WireFrame>[]);

  @override
  Future<void> dispose() async {
    _started = false;
    for (final alias in _sessions.keys) {
      _connectionEpoch[alias] = (_connectionEpoch[alias] ?? 0) + 1;
      _unconfirmDevice(alias);
    }
    await Future.wait(_sessions.values.map((session) => session.disconnect()));
    _inbox.clear();
  }
}

class _PendingDelivery {
  _PendingDelivery(this.request) {
    result.future.ignore();
  }
  final PendingServerAck request;
  final result = Completer<DeliveryReceipt>();
  Timer? timer;
}
