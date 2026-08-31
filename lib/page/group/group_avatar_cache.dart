import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';

/// 群头像成员列表全局缓存（单例）。
///
/// - key: groupId；value: 成员头像 URL 列表 + 过期时间。
/// - in-flight 去重：同 gid 并发 load 只发起一次底层查询，会话列表滚动
///   重挂载不会放大 SQL 次数。
/// - 时效性三层：①GroupMemberUpdateEvent（加人/退人/踢人/解散）按 gid
///   即时失效；②成员换头像 = 新 object_key = 新 URL，TTL 过期重新 load
///   自然拿到新值；③refresh_conversations 广播的 invalidateAll 粗粒度兜底
///   （contact.avatar 更新改变不了已缓存 URL 列表，只能靠失效重查）。
///
/// 群自定义头像（group.avatar 非空）走单图直出，不经过本缓存。
class GroupAvatarMemberCache {
  /// 测试用独立实例注入时钟；单例随 App 生命周期存续。
  GroupAvatarMemberCache({DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _subscription = AppEventBus.on<GroupMemberUpdateEvent>().listen((event) {
      invalidate(event.groupId);
    });
  }

  /// 全局单例。测试请 new 独立实例，勿污染单例状态。
  static final instance = GroupAvatarMemberCache();

  /// TTL：群头像 URL 列表的保鲜期，超时后 peek 返回 null、load 重新查询。
  @visibleForTesting
  static const ttl = Duration(minutes: 5);

  final DateTime Function() _now;
  final _cache = <String, _GroupAvatarEntry>{};
  final _inflight = <String, Future<List<String>>>{};
  StreamSubscription<GroupMemberUpdateEvent>? _subscription;

  /// 命中且未过期 → 直接返回缓存；否则调 loader 并写缓存（并发去重）。
  ///
  /// 去重用 Completer 中转：存入 _inflight 的是 completer.future，
  /// 异步体 finally 里 remove 的是 _inflight 条目，二者不是一个对象。
  /// 曾直接存 then/whenComplete 链的 future 再在回调里 remove 同一 key
  /// —— 该形态在 Dart 3.13.1 下 await 永久挂起（最小复现已证），勿改回。
  /// complete 传 unmodifiable 版本，保证命中缓存返回的是同一份不可变列表。
  Future<List<String>> load(
    String gid,
    Future<List<String>> Function(String gid) loader,
  ) {
    final entry = _cache[gid];
    if (entry != null && _now().isBefore(entry.expiredAt)) {
      return Future.value(entry.urls);
    }
    final existing = _inflight[gid];
    if (existing != null) {
      return existing;
    }
    final completer = Completer<List<String>>();
    _inflight[gid] = completer.future;
    unawaited(() async {
      try {
        final urls = List<String>.unmodifiable(await loader(gid));
        _cache[gid] = _GroupAvatarEntry(urls: urls, expiredAt: _now().add(ttl));
        if (!completer.isCompleted) {
          completer.complete(urls);
        }
      } catch (e, s) {
        // loader 失败不写缓存，下次 load 重试；异常原样抛给调用方
        if (!completer.isCompleted) {
          completer.completeError(e, s);
        }
      } finally {
        _inflight.remove(gid);
      }
    }());
    return completer.future;
  }

  /// 同步嗅探：会话列表预热后，列表项 build 时先问这里，命中即同步渲染
  /// （无 FutureBuilder，首帧真图）。纯内存查询，每次 build 都可调用。
  List<String>? peek(String gid) {
    final entry = _cache[gid];
    if (entry == null || !_now().isBefore(entry.expiredAt)) {
      return null;
    }
    return entry.urls;
  }

  /// 群成员变更（加人/退人/踢人/解散）后失效该群。
  void invalidate(String gid) {
    _cache.remove(gid);
  }

  /// 会话全量刷新（refresh_conversations）后的粗粒度兜底。
  void invalidateAll() {
    _cache.clear();
  }

  /// 取消事件订阅。单例永不调用；测试实例在 tearDown 释放，
  /// 避免跨用例泄漏订阅。
  @visibleForTesting
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

class _GroupAvatarEntry {
  _GroupAvatarEntry({required this.urls, required this.expiredAt});

  final List<String> urls;
  final DateTime expiredAt;
}

/// 稳定的默认群头像 loader（文件级顶层函数，tear-off 引用恒定）。
///
/// 替代调用方每次 build 新建 `GroupListService().computeAvatar` 闭包 ——
/// 闭包每次都是新对象，无法做稳定引用传递。
Future<List<String>> defaultGroupAvatarLoader(String gid) {
  return GroupListService().computeAvatar(gid);
}
