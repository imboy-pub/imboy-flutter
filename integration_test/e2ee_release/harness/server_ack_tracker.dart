/// Correlates decoded business ACKs from an authenticated device connection.
/// Acceptance means server acknowledgement, never recipient delivery/decryption.
enum ServerAckOutcome { accepted, unconfirmed }

class PendingServerAck {
  const PendingServerAck(
    this.deviceAlias,
    this.messageId,
    this.direction,
    this.deadline,
    this.connectionGeneration,
  );

  final String deviceAlias;
  final String messageId;
  final String direction;
  // Caller supplies a monotonic clock; no wall-clock timestamps are compared.
  final int deadline;
  final int connectionGeneration;
}

class ServerAckResult {
  const ServerAckResult(this.request, this.outcome);

  final PendingServerAck request;
  final ServerAckOutcome outcome;
}

class ServerAckTracker {
  final _pending = <(String, String), PendingServerAck>{};
  // A tracker belongs to one fixture run. IDs cannot be recycled after timeout.
  final _registered = <(String, String)>{};

  void register(PendingServerAck request) {
    if (request.deviceAlias.isEmpty ||
        request.messageId.isEmpty ||
        !const {'C2C', 'C2G'}.contains(request.direction) ||
        request.deadline < 0 ||
        request.connectionGeneration < 0) {
      throw const FormatException('invalid pending server acknowledgement');
    }
    final key = (request.deviceAlias, request.messageId);
    if (!_registered.add(key)) {
      throw StateError('message acknowledgement already registered');
    }
    _pending[key] = request;
  }

  ServerAckResult? receive({
    required String deviceAlias,
    required int connectionGeneration,
    required int now,
    required Map<String, dynamic> message,
  }) {
    _validateClock(now);
    final id = message['id'];
    if (id is! String) return null;
    final key = (deviceAlias, id);
    final request = _pending[key];
    if (request == null ||
        connectionGeneration != request.connectionGeneration ||
        message['type'] != '${request.direction}_SERVER_ACK' ||
        message['in_reply_to'] != id) {
      return null;
    }
    if (now >= request.deadline) {
      _pending.remove(key);
      return ServerAckResult(request, ServerAckOutcome.unconfirmed);
    }
    _pending.remove(key);
    return ServerAckResult(request, ServerAckOutcome.accepted);
  }

  List<ServerAckResult> expire(int now) {
    _validateClock(now);
    final expired = _pending.values
        .where((request) => now >= request.deadline)
        .toList();
    for (final request in expired) {
      _pending.remove((request.deviceAlias, request.messageId));
    }
    return List.unmodifiable(
      expired.map(
        (request) => ServerAckResult(request, ServerAckOutcome.unconfirmed),
      ),
    );
  }

  List<ServerAckResult> disconnect(String alias, int generation) {
    final requests = _pending.values
        .where(
          (request) =>
              request.deviceAlias == alias &&
              request.connectionGeneration == generation,
        )
        .toList();
    for (final request in requests) {
      _pending.remove((request.deviceAlias, request.messageId));
    }
    return List.unmodifiable(
      requests.map(
        (request) => ServerAckResult(request, ServerAckOutcome.unconfirmed),
      ),
    );
  }

  void _validateClock(int now) {
    if (now < 0) throw const FormatException('invalid monotonic clock');
  }
}
