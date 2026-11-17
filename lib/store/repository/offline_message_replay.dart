part of 'offline_message_writer.dart';

/// Isolate a control-frame failure without acknowledging its side effects.
Future<void> _replayOfflineControlMessages(
  List<Map<String, dynamic>> s2cMessages,
  Future<void> Function(Map<String, dynamic>) onS2CMessage,
  void Function() requireCurrent,
  void Function(String) addAckId,
) async {
  for (final msgData in s2cMessages) {
    requireCurrent();
    final id = (msgData['msg_id'] ?? msgData['id']).toString();
    try {
      await onS2CMessage(msgData);
      requireCurrent();
      addAckId(id);
    } on Object catch (error) {
      // Keep a failed control frame pending on the server, but return
      // ACKs for committed messages and continue processing its peers.
      // A session change still invalidates the entire response.
      requireCurrent();
      AppLogger.warning(
        'Offline S2C frame deferred id=$id errType=${error.runtimeType}',
      );
    }
  }
}
