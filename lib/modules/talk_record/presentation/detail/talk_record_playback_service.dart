/// 面聊记录（talk_record）受控回放服务（T16）。
///
/// 契约源：BACKEND-API.md §4 POST /:id/playback（短时受控播放会话
/// URL/expiry；逐段/Range 重验授权，不暴露可长期直读的 S3 地址）+
/// §11.3（撤权阻止票据续签；播放器预取量须受控，以最小预取窗口验证
/// 撤权效果）。
///
/// 生产实现从 API 获取短票据；媒体请求复用设备签名与当前 JWT，
/// 仅访问同源受控 stream。账号变化同步封锁命令并停止、释放原生播放器。
/// fixture 网关仅供 widget 测试，不代表真实音频可用。
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'talk_record_playback_request.dart';
import 'talk_record_playback_account_session.dart';

import 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 受控播放票据（短时会话 URL + 到期时间）。
class TalkRecordPlaybackTicket {
  final EntityId recordId;
  final String sessionId;
  final String url;
  final DateTime expiresAt;

  const TalkRecordPlaybackTicket({
    required this.recordId,
    required this.sessionId,
    required this.url,
    required this.expiresAt,
  });

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// 到期前 [lead] 内需要续签（续签触发点，见 TalkRecordPlayerNotifier）。
  bool needsRenew(DateTime now, Duration lead) =>
      expiresAt.difference(now) <= lead;
}

class TalkRecordPlaybackPart {
  const TalkRecordPlaybackPart(
    this.seq,
    this.offsetMs,
    this.durationMs,
    this.url,
  );
  final int seq;
  final int offsetMs;
  final int durationMs;
  final String url;
}

class TalkRecordPartsTicket {
  const TalkRecordPartsTicket(this.parts, this.expiresAt);
  final List<TalkRecordPlaybackPart> parts;
  final DateTime expiresAt;

  bool needsRenew(DateTime now, Duration lead) =>
      expiresAt.difference(now) <= lead;
}

abstract class TalkRecordPartsPlaybackGateway {
  Future<TalkRecordPartsTicket> openTicket(EntityId recordId);
}

class TalkRecordApiPartsPlaybackGateway
    implements TalkRecordPartsPlaybackGateway {
  TalkRecordApiPartsPlaybackGateway([TalkRecordApi? api])
    : _api = api ?? TalkRecordApi();
  final TalkRecordApi _api;

  @override
  Future<TalkRecordPartsTicket> openTicket(EntityId recordId) async {
    final result = await _api.playbackParts(recordId);
    final rawExpiry = result['expiry'];
    final isoExpiry = result['expires_at'];
    final expiry = isoExpiry is String
        ? DateTime.tryParse(isoExpiry)
        : rawExpiry is int && rawExpiry > 0 && rawExpiry <= 253402300799
        ? DateTime.fromMillisecondsSinceEpoch(rawExpiry * 1000, isUtc: true)
        : null;
    final rows = result['parts'];
    if (expiry == null ||
        !DateTime.now().isBefore(expiry) ||
        result['record_id'] != recordId ||
        rows is! List ||
        rows.isEmpty) {
      throw StateError('Playback parts unavailable');
    }
    final parts = <TalkRecordPlaybackPart>[];
    var offset = 0;
    for (final row in rows) {
      if (row is! Map ||
          row['seq'] is! int ||
          row['offset_ms'] is! int ||
          row['duration_ms'] is! int ||
          row['url'] is! String) {
        throw StateError('Invalid playback part');
      }
      final seq = row['seq'] as int;
      final start = row['offset_ms'] as int;
      final duration = row['duration_ms'] as int;
      final url = row['url'] as String;
      final uri = talkRecordPlaybackUri(
        url,
        Uri.parse(Env().apiBaseUrl),
        recordId: recordId,
      );
      if (seq != parts.length ||
          start != offset ||
          duration <= 0 ||
          !uri.path.endsWith('/playback/parts/$seq')) {
        throw StateError('Invalid playback part timeline');
      }
      parts.add(TalkRecordPlaybackPart(seq, start, duration, url));
      offset += duration;
    }
    return TalkRecordPartsTicket(List.unmodifiable(parts), expiry);
  }
}

/// 受控回放网关抽象：开票与续签（POST /:id/playback）。
///
/// T13/T15 联调注意：
/// - 续签必须携带当前会话标识/位置，服务端重验 ACL 与撤销版本（§11.3）；
/// - 撤权后 openTicket/renewTicket 应失败（404/403），播放器据此停止；
/// - 不缓存长时 URL，票据过期即视为不可用。
abstract class TalkRecordPlaybackGateway {
  Future<TalkRecordPlaybackTicket> openTicket(
    EntityId recordId, {
    int? positionMs,
  });

  Future<TalkRecordPlaybackTicket> renewTicket(
    EntityId recordId,
    TalkRecordPlaybackTicket current,
  );
}

/// 默认实现：T08 API 客户端薄封装（端点未实现 → 失败如实抛错）。
class TalkRecordApiPlaybackGateway implements TalkRecordPlaybackGateway {
  TalkRecordApiPlaybackGateway([TalkRecordApi? api])
    : _api = api ?? TalkRecordApi();

  final TalkRecordApi _api;

  @override
  Future<TalkRecordPlaybackTicket> openTicket(
    EntityId recordId, {
    int? positionMs,
  }) async {
    final session = await _api.playback(recordId, positionMs: positionMs);
    final expiry = session.expiresAt;
    if (expiry == null || !DateTime.now().isBefore(expiry)) {
      throw StateError('Playback ticket expiry unavailable');
    }
    talkRecordPlaybackUri(
      session.url,
      Uri.parse(Env().apiBaseUrl),
      recordId: recordId,
    );
    return TalkRecordPlaybackTicket(
      recordId: recordId,
      sessionId: session.url,
      url: session.url,
      expiresAt: expiry,
    );
  }

  @override
  Future<TalkRecordPlaybackTicket> renewTicket(
    EntityId recordId,
    TalkRecordPlaybackTicket current,
  ) {
    // 服务器续签复用同端点（带当前进度；§4 position_ms 可选）。
    return openTicket(recordId, positionMs: null).then((t) => t);
  }
}

/// fixture 网关：签发**不可播放**的伪 URL（`fixture-playback://...`），
/// 供 widget 测试断言开票/续签调用序列。零网络，不代表真实音频可用。
class FixtureTalkRecordPlaybackGateway implements TalkRecordPlaybackGateway {
  FixtureTalkRecordPlaybackGateway({
    this.ticketTtl = const Duration(minutes: 5),
  });

  /// 票据寿命（测试可缩短以触发续签路径）。
  final Duration ticketTtl;

  int openCount = 0;
  int renewCount = 0;
  int seq = 0;

  /// 可选错误注入（模拟撤权后 404/403，验证播放器停止）。
  Object? errorToThrow;

  @override
  Future<TalkRecordPlaybackTicket> openTicket(
    EntityId recordId, {
    int? positionMs,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    openCount++;
    return _issue(recordId);
  }

  @override
  Future<TalkRecordPlaybackTicket> renewTicket(
    EntityId recordId,
    TalkRecordPlaybackTicket current,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    renewCount++;
    return _issue(recordId);
  }

  TalkRecordPlaybackTicket _issue(EntityId recordId) {
    seq++;
    return TalkRecordPlaybackTicket(
      recordId: recordId,
      sessionId: 'fixture-session-$seq',
      url: 'fixture-playback://talk-records/$recordId?session=$seq',
      expiresAt: DateTime.now().add(ticketTtl),
    );
  }
}

/// 播放器后端状态（position/duration/完成，毫秒）。
class TalkRecordPlayerBackendState {
  final bool playing;
  final int positionMs;
  final int durationMs;
  final bool completed;
  final bool blocked;
  final bool failed;

  const TalkRecordPlayerBackendState({
    this.playing = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.completed = false,
    this.blocked = false,
    this.failed = false,
  });
}

/// 播放器后端抽象：UI/状态层只面向此接口；widget 测试注入 Fake（零平台
/// 通道），真实实现用 just_audio。
abstract class TalkRecordPlayerBackend {
  /// 载入受控 URL（[initialPositionMs] 恢复进度）。票据续签换 URL 时同样
  /// 经此方法热载（保持当前位置）。
  Future<void> load(String url, {int initialPositionMs = 0});

  Future<void> play();
  Future<void> pause();
  Future<void> seek(int positionMs);

  /// 停止并释放当前源（页面离开/撤权时调用——不保留可播放缓冲）。
  Future<void> stop();

  Stream<TalkRecordPlayerBackendState> get states;

  void dispose();
}

/// just_audio 后端（真实实现）。
///
/// **预取量最小化声明（撤权验证需要，§11.3）**：
/// - 只 `setUrl` 当前票据 URL，从不预载第二条资源/预取下一片段；
/// - 停止/失败/票据失效即 `stop()` 释放当前源与缓冲，不后台保活；
/// - 会话票据短时（服务端控制）+ 客户端到期前续签，URL 失效后旧缓冲
///   不可续读；ExoPlayer/AVPlayer 的字节级 buffer 上限未在 Flutter 侧
///   暴露，最小窗口验证（撤权后立即可断流）留 T13/T15 真机联调复核。
class JustAudioTalkRecordPlayerBackend implements TalkRecordPlayerBackend {
  JustAudioTalkRecordPlayerBackend({
    AudioPlayer? player,
    TalkRecordPlaybackRequestResolver? requestResolver,
    void Function(void Function())? addAuthListener,
    void Function(void Function())? removeAuthListener,
  }) : _player = player ?? AudioPlayer(),
       _requestResolver =
           requestResolver ?? TalkRecordPlaybackRequestResolver.production() {
    _accountSession = TalkRecordPlaybackAccountSession(
      accountKey: () => _requestResolver.accountKey,
      addListener: addAuthListener ?? UserRepoLocal.to.addAuthListener,
      removeListener: removeAuthListener ?? UserRepoLocal.to.removeAuthListener,
      stop: stop,
      disposeNative: () async {
        await _player.dispose();
        await _statesController.close();
      },
      onBlocked: () {
        _playing = false;
        _emit();
      },
      onFailure: _teardownFailed,
    );
    _player.positionStream.listen((pos) {
      _lastPositionMs = pos.inMilliseconds;
      _emit();
    });
    _player.durationStream.listen((dur) {
      if (dur != null) {
        _lastDurationMs = dur.inMilliseconds;
        _emit();
      }
    });
    _player.playerStateStream.listen((state) {
      _playing = state.playing;
      _completed = state.processingState == ProcessingState.completed;
      if (_completed) _playing = false;
      _emit();
    });
    _player.errorStream.listen((_) {
      // shortcut: errors lack source identity; replace when the player exposes it.
      _playing = false;
      _emit(failed: true);
    });
  }

  final AudioPlayer _player;
  final TalkRecordPlaybackRequestResolver _requestResolver;
  late final TalkRecordPlaybackAccountSession _accountSession;

  void _teardownFailed(Object error, StackTrace stack) {
    developer.log(
      'Playback native teardown failed',
      name: 'talk_record',
      error: error.runtimeType,
      stackTrace: stack,
    );
  }

  final _statesController =
      StreamController<TalkRecordPlayerBackendState>.broadcast();

  int _lastPositionMs = 0;
  int _lastDurationMs = 0;
  bool _playing = false;
  bool _completed = false;

  @override
  Stream<TalkRecordPlayerBackendState> get states => _statesController.stream;

  @override
  Future<void> load(String url, {int initialPositionMs = 0}) async {
    _accountSession.check();
    final request = await _requestResolver.resolve(url);
    _accountSession.check();
    _lastPositionMs = initialPositionMs;
    _completed = false;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } on Object {
      // 会话配置失败不阻塞播放（与 voice_playback_service 先例一致）。
    }
    await _player.setUrl(
      request.uri.toString(),
      headers: request.headers,
      initialPosition: Duration(milliseconds: initialPositionMs),
    );
    _accountSession.check();
    _emit();
  }

  @override
  Future<void> play() async {
    _accountSession.check();
    _playing = true;
    _emit();
    await _player.play();
    _accountSession.check();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _emit();
    await _player.pause();
  }

  @override
  Future<void> seek(int positionMs) async {
    _accountSession.check();
    _lastPositionMs = positionMs;
    _completed = false;
    _emit();
    await _player.seek(Duration(milliseconds: positionMs));
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _emit();
    await _player.stop();
  }

  @override
  void dispose() {
    unawaited(_accountSession.close().catchError(_teardownFailed));
  }

  void _emit({bool failed = false}) {
    if (_statesController.isClosed) return;
    _statesController.add(
      TalkRecordPlayerBackendState(
        playing: _playing && !_accountSession.blocked,
        positionMs: _lastPositionMs,
        durationMs: _lastDurationMs,
        completed: _completed,
        blocked: _accountSession.blocked,
        failed: failed,
      ),
    );
  }
}
