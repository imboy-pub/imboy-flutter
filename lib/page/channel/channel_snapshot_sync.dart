import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';

/// 对账事务绑定取得的数据库；会话或列表代次失效时回滚。
Future<bool> syncChannelSnapshot({
  required ChannelRepo repo,
  required List<ChannelModel> channels,
  required bool Function() isCurrent,
}) async {
  try {
    final db = await SqliteService.to.db;
    if (db == null || !isCurrent()) return false;
    await db.transaction((txn) async {
      for (final channel in channels) {
        if (!isCurrent()) throw StateError('stale channel snapshot');
        await repo.saveChannel(channel, txn: txn);
        final rows = await txn.query(
          ChannelRepo.subscriptionTableName,
          columns: [ChannelRepo.subChannelId],
          where: '${ChannelRepo.subChannelId} = ?',
          whereArgs: [channel.id],
        );
        if (rows.isEmpty) {
          await repo.saveSubscription(
            ChannelSubscriptionModel(
              channelId: channel.id,
              subscribedAt: DateTime.now(),
            ),
            txn: txn,
          );
        }
        if (!isCurrent()) throw StateError('stale channel snapshot');
      }
    });
    return isCurrent();
  } catch (_) {
    return false;
  }
}

/// 只对账汇总里明确返回的项；未返回不代表未读为零。
Future<bool> syncChannelUnreadSnapshot({
  required ChannelApi api,
  required bool Function() isCurrent,
}) async {
  try {
    final summary = await api.getUnreadSummary();
    final rows = summary['channels'];
    if (!isCurrent() || rows is! List) return false;
    final db = await SqliteService.to.db;
    if (db == null || !isCurrent()) return false;
    final changed = <String, int>{};
    final present = <String>{};
    var total = 0;
    var unresolved = false;
    await db.transaction((txn) async {
      for (final raw in rows) {
        if (!isCurrent()) throw StateError('stale unread snapshot');
        if (raw is! Map<String, dynamic>) {
          throw FormatException('invalid unread snapshot row');
        }
        final item = raw;
        final id = parseModelString(item['channel_id']);
        final count = int.tryParse('${item['unread_count']}');
        if (id.isEmpty || count == null || count < 0) {
          throw FormatException('invalid unread snapshot row');
        }
        present.add(id);
        final updates = await txn.update(
          ChannelRepo.subscriptionTableName,
          {ChannelRepo.unreadCount: count},
          where: '${ChannelRepo.subChannelId} = ?',
          whereArgs: [id],
        );
        if (updates > 0) changed[id] = count;
      }
      final local = await txn.query(
        ChannelRepo.subscriptionTableName,
        columns: [
          'CAST(${ChannelRepo.subChannelId} AS TEXT) AS ${ChannelRepo.subChannelId}',
          ChannelRepo.unreadCount,
        ],
      );
      // shortcut: 缺席可能是撤权或零未读；W07 权威逐项对账完成后消除待核对状态。
      unresolved = local.any(
        (row) =>
            parseModelInt(row[ChannelRepo.unreadCount]) > 0 &&
            !present.contains(parseModelString(row[ChannelRepo.subChannelId])),
      );
      final totals = await txn.rawQuery(
        'SELECT COALESCE(SUM(${ChannelRepo.unreadCount}), 0) AS total '
        'FROM ${ChannelRepo.subscriptionTableName}',
      );
      total = parseModelInt(totals.single['total']);
      if (!isCurrent()) throw StateError('stale unread snapshot');
    });
    if (!isCurrent()) return false;
    for (final entry in changed.entries) {
      AppEventBus.fire(
        ChannelUnreadCountUpdatedEvent(
          channelId: entry.key,
          unreadCount: entry.value,
        ),
      );
    }
    AppEventBus.fire(
      ChannelUnreadCountUpdatedEvent(
        channelId: 'unread_summary',
        unreadCount: total,
      ),
    );
    return !unresolved;
  } catch (_) {
    return false;
  }
}
