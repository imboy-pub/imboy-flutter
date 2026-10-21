/// 面聊记录（talk_record）T09 —— 平台适配器集合。
///
/// 生产实现与可注入抽象的边界文件：
/// - [SecureTalkRecordKeyStore]：recordKey → flutter_secure_storage
///   （iOS Keychain ThisDeviceOnly / Android Keystore，与项目 E2EE 秘钥
///   同一存储面；key 不进 SQLite/manifest）；
/// - [ProbeFileDiskSpaceProbe]：磁盘剩余空间 best-effort 探测
///   （Flutter 无跨平台纯 Dart 空闲空间 API，写后即删的探测文件是
///   无新依赖下的诚实实现；ENOSPC 类真实写入失败仍由写入路径兜底）；
/// - [TalkRecordSystemInterruptionSource]：audio_session 中断流适配
///   （来电/系统抢占→真实暂停信号；只在生产装配，测试注入流）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';

import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

/// 系统中断信号（reason 持久化进 manifest）。
class TalkRecordInterruptionSignal {
  final String reason;
  const TalkRecordInterruptionSignal(this.reason);
}

/// 中断源抽象（测试注入 StreamController）。
///
/// 生命周期：[start]（激活，须在订阅 [interruptions] 前调用——生产源在
/// 此桥接平台流，未 start 的源不产生任何信号）→ [interruptions] 订阅
/// → [dispose]。
abstract class TalkRecordInterruptionSource {
  /// 激活源。生产实现在此挂接平台流；幂等（重复调用无副作用）。
  Future<void> start();

  Stream<TalkRecordInterruptionSignal> get interruptions;

  Future<void> dispose();
}

/// recordKey 的 secure storage 生产实现。
class SecureTalkRecordKeyStore implements TalkRecordKeyStore {
  SecureTalkRecordKeyStore({StorageSecureService? storage})
    : _storage = storage ?? StorageSecureService.to;

  final StorageSecureService _storage;
  static const String _prefix = 'trk_';

  String _key(String sessionId) => '$_prefix$sessionId';

  @override
  Future<void> writeRecordKey(String sessionId, Uint8List key) {
    return _storage.write(key: _key(sessionId), value: base64Encode(key));
  }

  @override
  Future<Uint8List?> readRecordKey(String sessionId) async {
    final raw = await _storage.read(key: _key(sessionId));
    if (raw == null || raw.isEmpty) return null;
    return _fromBase64(raw);
  }

  @override
  Future<void> deleteRecordKey(String sessionId) {
    return _storage.delete(key: _key(sessionId));
  }

  static Uint8List _fromBase64(String raw) {
    try {
      return base64Decode(raw);
    } on FormatException {
      return Uint8List(0);
    }
  }
}

/// 磁盘空间预检抽象。
abstract class DiskSpaceProbe {
  Future<bool> hasAtLeast(Directory dir, int bytes);
}

/// 探测文件实现：向 dir 写 [bytes] 后删除；写失败=空间不足/目录不可写。
class ProbeFileDiskSpaceProbe implements DiskSpaceProbe {
  @override
  Future<bool> hasAtLeast(Directory dir, int bytes) async {
    File? probe;
    try {
      await dir.create(recursive: true);
      probe = File(
        '${dir.path}/.space_probe_${DateTime.now().microsecondsSinceEpoch}',
      );
      final sink = probe.openWrite();
      const chunk = 64 * 1024;
      final block = List<int>.filled(chunk, 0);
      var remaining = bytes;
      while (remaining > 0) {
        final n = remaining > chunk ? chunk : remaining;
        sink.add(n == chunk ? block : block.sublist(0, n));
        remaining -= n;
      }
      await sink.flush();
      await sink.close();
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        if (probe != null && probe.existsSync()) probe.deleteSync();
      } catch (_) {}
    }
  }
}

/// audio_session 中断源生产实现（来电/系统抢占麦克风）。
class TalkRecordSystemInterruptionSource
    implements TalkRecordInterruptionSource {
  /// 会话（构造注入；未注入时惰性获取）。公开字段便于注入替换。
  AudioSession? session;

  TalkRecordSystemInterruptionSource({this.session});

  final StreamController<TalkRecordInterruptionSignal> _out =
      StreamController<TalkRecordInterruptionSignal>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  Stream<TalkRecordInterruptionSignal> get interruptions => _out.stream;

  Future<void> _ensureStarted() async {
    if (_subs.isNotEmpty) return;
    final effectiveSession = session ?? await AudioSession.instance;
    session = effectiveSession;
    _subs.add(
      effectiveSession.interruptionEventStream.listen((event) {
        if (event.begin) {
          _out.add(const TalkRecordInterruptionSignal('audio_interruption'));
        }
      }),
    );
    _subs.add(
      effectiveSession.becomingNoisyEventStream.listen((_) {
        _out.add(const TalkRecordInterruptionSignal('audio_becoming_noisy'));
      }),
    );
  }

  @override
  Future<void> start() => _ensureStarted();

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _out.close();
  }
}

/// RFC 4122 v4 会话/客户端 ID（Random.secure，无第三方依赖）。
class TalkRecordIds {
  static final Random _rng = Random.secure();

  static String newUuidV4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
