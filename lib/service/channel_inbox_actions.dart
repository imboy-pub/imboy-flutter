import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/channel_events.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// The caller binds [isCurrent] to the row's captured account, session,
/// environment and endpoint. All awaits stay within that same owner.
Future<bool> setPersonalInboxChannelPinned({
  required ChannelService service,
  required String channelId,
  required bool pinned,
  required bool Function() isCurrent,
  Future<Database?> Function()? database,
}) async {
  if (!isCurrent()) return false;
  try {
    final db = await (database ?? (() => SqliteService.to.db))();
    if (db == null || !isCurrent()) return false;
    final rows = await db.transaction((txn) async {
      if (!isCurrent()) throw StateError('stale channel inbox session');
      final channel = await service.repo.getChannel(channelId, txn: txn);
      if (!isCurrent()) throw StateError('stale channel inbox session');
      if (channel == null ||
          channel.scope != 'personal' ||
          (channel.workspaceId?.isNotEmpty ?? false) ||
          !channel.isSubscribed) {
        return 0;
      }
      final rows = await service.repo.setPinned(channelId, pinned, txn: txn);
      if (!isCurrent()) throw StateError('stale channel inbox session');
      return rows;
    });
    if (!isCurrent() || rows == 0) return false;
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: channelId,
        action: 'channel_pinned_changed',
        payload: {'is_pinned': pinned},
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
