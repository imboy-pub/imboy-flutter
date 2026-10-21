/// T09 manifest 单测：读写往返/原子性、崩溃恢复（伪造段文件+清单）、
/// 坏尾截断、恢复时长计算。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

void main() {
  late Directory tmpDir;
  late Directory sessionDir;
  const sessionId = 'sess-recovery';
  final recordKey = TalkRecordSegmentCrypto.generateRecordKey();

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('t09_manifest');
    sessionDir = Directory('${tmpDir.path}/$sessionId');
    sessionDir.createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  /// 伪造一个已封段：真实加密路径产密文 + 清单条目。
  Future<TalkRecordSegmentEntry> forgeSegment(
    int seq,
    int startMs,
    int durationMs,
  ) async {
    final plain = File('${sessionDir.path}/p$seq.aac');
    await plain.writeAsBytes(List<int>.generate(256, (i) => (i + seq) & 0xFF));
    final cipher = File(
      '${sessionDir.path}/${'seg_${seq.toString().padLeft(6, '0')}.aes'}',
    );
    final info = await TalkRecordSegmentCrypto.sealSegment(
      plainFile: plain,
      cipherFile: cipher,
      recordKey: recordKey,
      sessionId: sessionId,
      seq: seq,
      mime: 'audio/aac',
    );
    await plain.delete();
    return TalkRecordSegmentEntry(
      seq: seq,
      startMs: startMs,
      endMs: startMs + durationMs,
      cipherFileName: cipher.uri.pathSegments.last,
      cipherSize: info.cipherSize,
      cipherSha256Hex: info.cipherSha256Hex,
      plainSize: info.plainSize,
      plainSha256Hex: info.plainSha256Hex,
      codec: 'aac_lc',
      sampleRateHz: 16000,
      numChannels: 1,
      capturedWallTimeIso: '2026-10-20T12:00:00',
    );
  }

  TalkRecordManifest buildManifest(
    List<TalkRecordSegmentEntry> segments, {
    TalkRecordSessionStatus status = TalkRecordSessionStatus.recording,
  }) {
    return TalkRecordManifest(
      sessionId: sessionId,
      recordLocalId: 'rec-1',
      clientRecordingId: 'crid-1',
      status: status,
      reportedStartedAtIso: '2026-10-20T11:00:00',
      segments: segments,
      marks: const [
        TalkRecordLocalMark(
          localId: 'mk1',
          positionMs: 5000,
          createdAtIso: '2026-10-20T11:05:00',
        ),
      ],
      encoder: const TalkRecordEncoderSettings(),
      updatedAtIso: '2026-10-20T12:00:00',
    );
  }

  test('写读往返：段/标记/中断记录/编码参数一致', () async {
    final store = TalkRecordManifestStore(sessionDir);
    final seg0 = await forgeSegment(0, 0, 30000);
    final seg1 = await forgeSegment(1, 30000, 8200);
    final m = buildManifest([seg0, seg1]).copyWith(
      interruption: const TalkRecordInterruptionRecord(
        reason: 'audio_interruption',
        occurredAtIso: '2026-10-20T11:40:00',
      ),
    );
    await store.write(m);

    final back = await store.read();
    expect(back, isNotNull);
    expect(back!.effectiveDurationMs, 38200);
    expect(back.segments.length, 2);
    expect(back.segments[1].startMs, 30000);
    expect(back.segments[1].durationMs, 8200);
    expect(back.marks.single.positionMs, 5000);
    expect(back.interruption?.reason, 'audio_interruption');
    expect(back.encoder.sampleRateHz, 16000);
    expect(back.lastSeq, 1);
    expect(back.totalCipherBytes, seg0.cipherSize + seg1.cipherSize);
    // 原子写不残留 tmp。
    expect(File('${sessionDir.path}/manifest.json.tmp').existsSync(), isFalse);
  });

  test('损坏 manifest（非 JSON 对象根）→ fail-closed 抛异常', () async {
    await File('${sessionDir.path}/manifest.json').writeAsString('[1,2]');
    final store = TalkRecordManifestStore(sessionDir);
    expect(store.read(), throwsA(isA<TalkRecordManifestException>()));
  });

  test('崩溃恢复：全部段完好 → 原样恢复，不截断', () async {
    final store = TalkRecordManifestStore(sessionDir);
    final segs = [
      await forgeSegment(0, 0, 30000),
      await forgeSegment(1, 30000, 5000),
    ];
    await store.write(
      buildManifest(segs, status: TalkRecordSessionStatus.recording),
    );

    final result = await store.recover();
    expect(result.truncatedTail, isFalse);
    expect(result.effectiveDurationMs, 35000);
    expect(result.manifest!.segments.length, 2);
  });

  test('崩溃恢复：末段密文丢失 → 坏尾截断，恢复为 interrupted', () async {
    final store = TalkRecordManifestStore(sessionDir);
    final segs = [
      await forgeSegment(0, 0, 30000),
      await forgeSegment(1, 30000, 12000),
      await forgeSegment(2, 42000, 7000),
    ];
    await store.write(
      buildManifest(segs, status: TalkRecordSessionStatus.recording),
    );
    // 崩溃：第 2 段文件没落成/被清掉。
    File('${sessionDir.path}/${segs[2].cipherFileName}').deleteSync();

    final result = await store.recover();
    expect(result.truncatedTail, isTrue);
    expect(result.manifest!.segments.length, 2);
    expect(result.effectiveDurationMs, 42000);
    expect(result.manifest!.status, TalkRecordSessionStatus.interrupted);
    expect(result.manifest!.interruption?.reason, 'unknown_interrupt');
    // 截断后的清单已写回，二次恢复稳定。
    final again = await store.recover();
    expect(again.truncatedTail, isFalse);
    expect(again.effectiveDurationMs, 42000);
  });

  test('崩溃恢复：段内容损坏（哈希不符）→ 同样截断', () async {
    final store = TalkRecordManifestStore(sessionDir);
    final segs = [
      await forgeSegment(0, 0, 30000),
      await forgeSegment(1, 30000, 9000),
    ];
    await store.write(buildManifest(segs));
    final bad = File('${sessionDir.path}/${segs[0].cipherFileName}');
    final bytes = await bad.readAsBytes();
    bytes[5] ^= 0xFF;
    await bad.writeAsBytes(bytes);

    final result = await store.recover();
    expect(result.truncatedTail, isTrue);
    // 头段坏了 → 从头截断，全部丢弃。
    expect(result.manifest!.segments, isEmpty);
    // M3：首段损坏（kept 空）同样归一 interrupted + unknown_interrupt，
    // 磁盘清单不得残留 recording 误导恢复入口。
    expect(result.manifest!.status, TalkRecordSessionStatus.interrupted);
    expect(result.manifest!.interruption?.reason, 'unknown_interrupt');
  });

  test('崩溃恢复：已 ended 会话 → 保持 ended 不改写', () async {
    final store = TalkRecordManifestStore(sessionDir);
    final segs = [await forgeSegment(0, 0, 30000)];
    await store.write(
      buildManifest(segs, status: TalkRecordSessionStatus.ended),
    );
    final result = await store.recover();
    expect(result.manifest!.status, TalkRecordSessionStatus.ended);
    expect(result.truncatedTail, isFalse);
  });

  test('恢复后段可解密（recordKey 可继续打开已落盘段）', () async {
    final store = TalkRecordManifestStore(sessionDir);
    final seg0 = await forgeSegment(0, 0, 30000);
    await store.write(buildManifest([seg0]));
    final result = await store.recover();
    final out = File('${tmpDir.path}/recovered.aac');
    await TalkRecordSegmentCrypto.openSegment(
      cipherFile: File('${sessionDir.path}/${seg0.cipherFileName}'),
      plainOutFile: out,
      recordKey: recordKey,
      sessionId: sessionId,
      seq: 0,
      info: result.manifest!.segments.single.cipherInfo,
      mime: 'audio/aac',
    );
    expect(out.lengthSync(), seg0.plainSize);
  });

  test('空目录恢复 → empty 结果', () async {
    final result = await TalkRecordManifestStore(sessionDir).recover();
    expect(result.manifest, isNull);
    expect(result.effectiveDurationMs, 0);
  });

  test('JSON 字段宽松解析（未知字段忽略、数字字符串兼容）', () {
    final m = TalkRecordManifest.fromJson(<String, dynamic>{
      'schema_version': 1,
      'session_id': 's',
      'record_local_id': 'r',
      'client_recording_id': 'c',
      'status': 'paused',
      'reported_started_at': 't',
      'updated_at': 'u',
      'segments': [
        {
          'seq': '3',
          'start_ms': '1000',
          'end_ms': '2500',
          'cipher_file': 'seg_000003.aes',
          'cipher_size': '99',
          'cipher_sha256': 'aa',
          'plain_size': '80',
          'plain_sha256': 'bb',
          'unknown_field': true,
        },
      ],
      'unknown_top': 1,
    });
    expect(m.status, TalkRecordSessionStatus.paused);
    expect(m.segments.single.seq, 3);
    expect(m.segments.single.durationMs, 1500);
    expect(m.effectiveDurationMs, 1500);
    expect(jsonEncode(m.toJson()), contains('seg_000003.aes'));
  });
}
