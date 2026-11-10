/// no-backend-ffmpeg V1 — NC 静态/合成门（AT06 补测，IMBOY_AUTOTEST_V2.1）。
///
/// 合同：Erlang 服务端不做 FFmpeg；成品音频由 App 侧合成（AAC-LC ADTS 段
/// 解密后按 seq 确定性拼接）并 S3 直传（数据流 App→S3）。
///
/// 三道门：
/// * NC-3 静态防回归门：pubspec.yaml/pubspec.lock 依赖清单 + lib/ 源码
///   （剥注释后）断言无 FFmpeg 依赖/FFI 绑定/外部进程调用——有人引入
///   ffmpeg 依赖或调用时测试直接拦截。
/// * NC-1 三段端到端合成（纯 Dart，Fake 引擎 host 级）：录 3 段→网关
///   逐段解密拼接→直传字节 == 有序明文拼接，产物参数 == 合同常量
///   （TalkRecordEncoderSettings 16kHz/mono、样本轴 msOfSamples）。
/// * NC-2 合成期参数漂移门：段间采样率不一致时合成必须拒绝
///   （'Final audio parameter drift across parts'），不产成品、不直传、
///   不送 complete、不留明文。
///
/// 注：平台编码器真实采样率/音质属真机验证项（waiting_resource），本
/// 文件只覆盖纯 Dart 层可断言的门；真机门禁另行验证。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/talk_record_attachment_upload_gateway.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_part_transport.dart';
import 'package:imboy/modules/talk_record/application/talk_record_upload_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/talk_record_upload_manifest.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/service/talk_record/talk_record_adts.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';

import 'fake_talk_record_engine.dart';

part 'talk_record_no_ffmpeg_scan_helpers.dart';

// ---------------------------------------------------------------------------
// NC-1/NC-2：合成链测试设施（Fake api/transport/direct，全 host 级）
// ---------------------------------------------------------------------------

/// 合同常量（DESIGN §6）：AAC-LC mono，目标 16kHz。
const TalkRecordEncoderSettings kContractEncoder = TalkRecordEncoderSettings();

/// 刻意超过旧固定等待的名义 120ms，覆盖慢封段。
class _SlowSegmentEngine extends FakeTalkRecordEngine {
  @override
  Future<int?> stopSegment() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return super.stopSegment();
  }
}

/// 合法 AAC-LC ADTS 段字节（确定性 payload；freqIdx/channels 可参数化，
/// 供 NC-2 构造漂移段：44100Hz→freqIdx 4，立体声→channels 2）。
Uint8List adtsSegmentBytes({
  required int frames,
  int freqIdx = 8, // 16kHz（FakeTalkRecordEngine 同款）
  int channels = 1,
  int payload = 32,
  int salt = 0,
}) {
  const rates = <int>[
    96000, 88200, 64000, 48000, 44100, 32000, //
    24000, 22050, 16000, 12000, 11025, 8000, 7350,
  ];
  assert(freqIdx >= 0 && freqIdx < rates.length, 'freqIdx out of ADTS range');
  assert(channels >= 1 && channels <= 2, 'channel config must be 1..2');
  final frameLen = 7 + payload;
  final out = BytesBuilder(copy: false);
  for (var n = 0; n < frames; n++) {
    out.add(<int>[
      0xff,
      0xf1,
      // profile=01(AAC-LC) | freqIdx | private=0（bit0=0，声道高位归 b3）
      (1 << 6) | (freqIdx << 2),
      // channel configuration 低 2 位 | frameLen 高 2 位
      (channels << 6) | ((frameLen >> 11) & 0x3),
      (frameLen >> 3) & 0xff,
      ((frameLen & 0x7) << 5) | 0x1f, // fullness 高 5 位=11111
      0xfc, // fullness 低 6 位 | blocks-1=00（单 raw block）
      for (var i = 0; i < payload; i++) (i + n + salt) & 0xff,
    ]);
  }
  return out.toBytes();
}

/// 测试用 binding（录制完成回填 sessionId 后构建）。
TalkRecordLocalBinding buildBinding(String sessionId) => TalkRecordLocalBinding(
  account: const TalkRecordAccount('https://local.example', '100'),
  clientRecordingId: 'record-client',
  deviceSessionId: 'device-session',
  context: const TalkRecordEntryContext.personal(),
  title: 'Gate',
  processingMode: 'record_only',
  policyVersion: 'v1',
  processorConfigVersion: 'approved-bundle-v1',
  sessionId: sessionId,
  recordId: '1',
  captureId: '2',
  leaseEpoch: 0,
  captureStatus: 'draft',
  leaseUntil: DateTime.now().add(const Duration(minutes: 5)),
);

/// 最小 TalkRecordApi fake：只覆盖网关 upload 链实际触达的端点
/// （record_only 模式：capabilities 不触达；无 marks：createMark 不触达）。
class MinimalUploadApi extends TalkRecordApi {
  String status = 'draft';
  String media = 'uploading';
  int confirmedCount = 0, completes = 0;
  int lastSeq = -1;
  int durationMs = 0;
  TalkRecordAudioPartInput? part;
  String completedHash = '';
  TalkRecordFinalAudioDecl? completedFinalAudio;

  TalkRecordCaptureModel get capture => TalkRecordCaptureModel.fromJson({
    'completion_manifest_hash': completedHash,
    'capture_id': 2,
    'record_id': 1,
    'device_session_id': 'device-session',
    'status': status,
    'parts': {
      'confirmed': confirmedCount,
      'pending': 0,
      'last_seq': part?.seq ?? -1,
      'effective_ms': durationMs,
    },
    'lease_epoch': 0,
    'last_event_seq': lastSeq,
    'lease_until': DateTime.now()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
  });

  @override
  Future<List<TalkRecordCaptureModel>> captures(String id) async => [capture];

  @override
  Future<TalkRecordFetched<TalkRecordModel>> detail(String id) async {
    return TalkRecordFetched(
      TalkRecordModel(
        id: '1',
        ownerUserId: '100',
        clientRecordingId: 'record-client',
        scope: TalkRecordScope.personal,
        captureStatus: TalkRecordCaptureStatus.parse(status),
        mediaStatus: TalkRecordMediaStatus.parse(media),
        durationMs: status == 'ended' ? durationMs : 0,
      ),
      etag: '"record-4"',
    );
  }

  @override
  Future<TalkRecordCaptureModel> postCaptureEvent(
    String id,
    String captureId,
    TalkRecordCaptureEventInput input,
  ) async {
    lastSeq = input.seq;
    status = input.event == TalkRecordCaptureEventKind.end
        ? 'ended'
        : 'recording';
    return capture;
  }

  @override
  Future<TalkRecordAudioUploadSession> createAudioPart(
    String id,
    String captureId,
    TalkRecordAudioPartInput input, {
    required String idempotencyKey,
  }) async {
    part = input;
    return TalkRecordAudioUploadSession.fromJson({
      'part_id': 3,
      'attachment_id': null,
      'upload_ref': {
        'state': 'GRANTED',
        'object_key': 'owner/record/audio-part.aac',
        'attempt_id': 1,
        'grant': {
          'transport': 's3_put',
          'url':
              'https://garage.example.test/owner/record/audio-part.aac'
              '?X-Amz-Signature=synthetic',
          'method': 'PUT',
          'required_headers': <String, String>{
            'Content-Type': 'audio/aac',
            'x-amz-checksum-sha256': 'synthetic-checksum',
          },
          'expires_in': 3600,
        },
      },
    });
  }

  @override
  Future<TalkRecordAudioPartConfirmResult> confirmAudioPart(
    String id,
    String captureId,
    String partId,
  ) async {
    confirmedCount++;
    return TalkRecordAudioPartConfirmResult.fromJson({
      'status': 'confirmed',
      'part_id': 3,
      'capture_id': 2,
      'seq': part!.seq,
      'attachment_id': 4,
      'sha256': part!.sha256,
      'byte_size': part!.byteSize,
    });
  }

  @override
  Future<TalkRecordCompleteResult> complete(
    String id, {
    required List<TalkRecordCompleteCaptureInput> captures,
    required TalkRecordFinalAudioDecl finalAudio,
    required String policyVersion,
    String? processorConfigVersion,
    required String idempotencyKey,
    required String ifMatch,
  }) async {
    completedFinalAudio = finalAudio;
    completes++;
    completedHash = captures.single.manifestHash;
    media = 'assembling';
    return const TalkRecordCompleteResult(
      mediaStatus: 'assembling',
      jobId: '6',
    );
  }
}

void _checkCancellation(CancelToken? cancelToken) {
  final error = cancelToken?.cancelError;
  if (error != null) throw error;
}

/// 段 PUT fake（无网络）。
class FakePartTransport implements TalkRecordPartTransport {
  int puts = 0;
  @override
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard, {
    CancelToken? cancelToken,
  }) async {
    guard();
    _checkCancellation(cancelToken);
    puts++;
  }
}

/// 成品 direct fake：捕获直传字节（供 NC-1 断言成品 == 有序明文拼接）。
class FinalDirectCapture {
  int uploads = 0, statuses = 0, registers = 0;
  final clientUploadIds = <String>[];
  final uploadedBytes = <Uint8List>[];
  String objectKeyOf(String id) => 'owner/record/final-$id.aac';
  TalkRecordFinalDirectRegister get register =>
      (
        String clientUploadId,
        String scopeRef, {
        CancelToken? cancelToken,
      }) async {
        _checkCancellation(cancelToken);
        registers++;
        return objectKeyOf(clientUploadId);
      };
  TalkRecordFinalDirectUpload get upload =>
      (
        File file, {
        required String clientUploadId,
        required String scopeRef,
        CancelToken? cancelToken,
      }) async {
        _checkCancellation(cancelToken);
        uploads++;
        clientUploadIds.add(clientUploadId);
        final bytes = await file.readAsBytes();
        _checkCancellation(cancelToken);
        uploadedBytes.add(bytes);
        return DirectUploadResult(
          objectKey: objectKeyOf(clientUploadId),
          state: 'CONFIRMED',
          attemptId: 1,
        );
      };
  TalkRecordFinalDirectStatus get status =>
      (String objectKey, {CancelToken? cancelToken}) async {
        _checkCancellation(cancelToken);
        statuses++;
        return DirectUploadResult(
          objectKey: objectKey,
          state: 'RESERVED',
          attemptId: 0,
        );
      };
}

void main() {
  // =========================================================================
  // NC-3：no-ffmpeg 静态防回归门
  // =========================================================================
  group('NC-3 no-ffmpeg static gate', () {
    test('gate 自检：注释里的 ffmpeg 豁免，代码/字符串命中保留', () {
      const source = '''
/// no-backend-ffmpeg V1 文档注释（不应命中）。
// ffmpeg in line comment（不应命中）。
/* ffmpeg in block comment（不应命中） */
final doc = 'no-backend-ffmpeg contract';
final raw = r'ffmpeg';
final code = ffmpegCall();
''';
      final stripped = stripDartComments(source);
      final violations = findBannedLines('synthetic.dart', stripped);
      expect(violations, hasLength(3), reason: '字符串字面量与代码必须命中；注释必须豁免');
      // 命中行：4（普通字符串）/5（raw 字符串）/6（代码标识符）。
      expect(violations.join(), contains('synthetic.dart:4'));
      expect(violations.join(), contains('synthetic.dart:5'));
      expect(violations.join(), contains('synthetic.dart:6'));
    });

    test('gate 自检：YAML 注释豁免 + lock 包名提取', () {
      const yaml = '''
dependencies:
  flutter_sound: ^9.30.0 # 注释里提 ffmpeg 不应命中
#  ffmpeg_kit_flutter: 注释掉的依赖也不应命中
  just_audio: ^0.10.6
''';
      expect(findBannedLines('pubspec.yaml', stripYamlComments(yaml)), isEmpty);
      const lock = '''
packages:
  ffmpeg_kit_flutter_new:
    dependency: transitive
    name: ffmpeg_kit_flutter_new
  flutter_sound:
    dependency: "direct main"
    name: flutter_sound
''';
      expect(
        lockPackageNames(stripYamlComments(lock)),
        containsAll(<String>['ffmpeg_kit_flutter_new', 'flutter_sound']),
      );
    });

    test('pubspec.yaml 依赖清单无 FFmpeg 相关包', () {
      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue, reason: 'flutter test 必须在包根运行');
      final violations = findBannedLines(
        'pubspec.yaml',
        stripYamlComments(pubspec.readAsStringSync()),
      );
      expect(
        violations,
        isEmpty,
        reason: '依赖清单引入 FFmpeg 包即违反合同:\n${violations.join('\n')}',
      );
    });

    test('pubspec.lock 传递依赖无 FFmpeg 相关包', () {
      final lock = File('pubspec.lock');
      expect(lock.existsSync(), isTrue);
      final names = lockPackageNames(
        stripYamlComments(lock.readAsStringSync()),
      );
      expect(names, isNotEmpty, reason: 'lock 解析失败会使本门空转');
      final violations = names.where(kBannedFfmpegTokens.hasMatch).toList();
      expect(violations, isEmpty, reason: '传递依赖混入 FFmpeg 即违反合同: $violations');
    });

    test('lib/ 源码（剥注释后）无 FFmpeg token（依赖/FFI/命令路径一网打尽）', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue);
      final violations = <String>[];
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        violations.addAll(
          findBannedLines(
            entity.path,
            stripDartComments(entity.readAsStringSync()),
          ),
        );
      }
      expect(
        violations,
        isEmpty,
        reason:
            '合同：Erlang 不做 FFmpeg、App 侧合成音频——lib/ 代码或字符串出现 '
            'FFmpeg token 即违反（注释豁免，no-backend-ffmpeg 合同标记不受影响）:\n'
            '${violations.join('\n')}',
      );
    });

    test('talk_record 音频链无外部进程派生与 FFI 绑定', () {
      const scopes = <String>[
        'lib/service/talk_record',
        'lib/modules/talk_record',
      ];
      final violations = <String>[];
      for (final scope in scopes) {
        final dir = Directory(scope);
        expect(dir.existsSync(), isTrue, reason: '$scope 应存在');
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final stripped = stripDartComments(entity.readAsStringSync());
          if (kProcessSpawn.hasMatch(stripped)) {
            violations.add('${entity.path}: Process spawn');
          }
          if (kDartFfiImport.hasMatch(stripped)) {
            violations.add('${entity.path}: dart:ffi binding');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'App 侧合成是纯 Dart 字节拼接：音频链不得起外部进程（如调 ffmpeg CLI）'
            '或经 FFI 绑定 FFmpeg 库:\n${violations.join('\n')}',
      );
    });
  });

  // =========================================================================
  // NC-1 / NC-2：合成链（host 级 Fake 引擎，真实 recorder/网关/加密代码路径）
  // =========================================================================
  late Directory baseDir;
  late FakeClock clock;
  late FakeTalkRecordEngine engine;
  late MemoryTalkRecordKeyStore keys;
  late TalkRecordRecorderService recorder;
  late TalkRecordManifest manifest;
  late MinimalUploadApi api;
  late FinalDirectCapture fd;
  late TalkRecordLocalBinding binding;

  /// 真实 recorder 录 N 段；前段封存且下一段已启动后才推进双轴。
  Future<TalkRecordManifest> recordSegments(List<int> tickMsPerSegment) async {
    await recorder.start(
      recordLocalId: 'record-client',
      clientRecordingId: 'record-client',
    );
    for (var i = 0; i < tickMsPerSegment.length; i++) {
      // 先订阅，避免错过滚动完成事件。单看 segmentCount 不足以证明
      // 下一段已启动：封段后创建目录的 await 期间也可能收到 ticker 快照。
      final rolledOver = i + 1 < tickMsPerSegment.length
          ? recorder.snapshots
                .firstWhere(
                  (snapshot) =>
                      snapshot.segmentCount == i + 1 &&
                      engine.events
                              .where((event) => event.startsWith('start:'))
                              .length ==
                          i + 2,
                )
                .timeout(const Duration(seconds: 5))
          : null;
      clock.advanceMs(tickMsPerSegment[i]);
      engine.tick(tickMsPerSegment[i]);
      if (rolledOver != null) await rolledOver;
    }
    final result = await recorder.end();
    return result.manifest;
  }

  /// 逐段解密并按 seq 拼接（独立重算的期望成品字节）。
  Future<Uint8List> expectedFinalBytes() async {
    final expected = BytesBuilder(copy: false);
    for (final segment in manifest.segments) {
      final plain = await TalkRecordSegmentCrypto.openSegmentBytes(
        cipherFile: File(
          '${recorder.sessionDir!.path}/${segment.cipherFileName}',
        ),
        recordKey: Uint8List.fromList(keys.store[manifest.sessionId]!),
        sessionId: manifest.sessionId,
        seq: segment.seq,
        info: TalkRecordSegmentCipherInfo(
          plainSize: segment.plainSize,
          plainSha256Hex: segment.plainSha256Hex,
          cipherSize: segment.cipherSize,
          cipherSha256Hex: segment.cipherSha256Hex,
        ),
        mime: 'audio/aac',
      );
      expected.add(plain);
    }
    return expected.toBytes();
  }

  Future<void> upload() {
    return TalkRecordAttachmentUploadGateway(
      api: api,
      transport: FakePartTransport(),
      confirmAttempts: 2,
      delay: (_) async {},
      directUpload: fd.upload,
      directStatus: fd.status,
      directRegister: fd.register,
    ).upload(
      binding: binding,
      manifest: manifest,
      directory: recorder.sessionDir!,
      keys: keys,
      checkAccount: () {},
    );
  }

  setUp(() async {
    baseDir = Directory.systemTemp.createTempSync('talk_ffmpeg_gate_');
    engine = _SlowSegmentEngine();
    clock = FakeClock();
    keys = MemoryTalkRecordKeyStore();
    api = MinimalUploadApi();
    fd = FinalDirectCapture();
    TalkRecordCaptureLease.resetForTest();
    recorder = TalkRecordRecorderService(
      baseDirectory: baseDir,
      engine: engine,
      keyStore: keys,
      diskProbe: FakeDiskSpaceProbe(),
      config: const TalkRecordRecorderConfig(
        segmentTargetMs: 1000,
        minFreeDiskBytesPerSegment: 1,
      ),
      nowSource: clock.call,
    );
  });

  tearDown(() async {
    await recorder.dispose();
    TalkRecordCaptureLease.resetForTest();
    if (baseDir.existsSync()) baseDir.deleteSync(recursive: true);
  });

  group(
    'NC-1 three-segment end-to-end synthesis (no-backend-ffmpeg V1 T2)',
    () {
      test('录 3 段→逐段解密按 seq 拼接直传：字节/样本轴/参数全对账', () async {
        // 16 帧 + 16 帧 + 8 帧 = 40 帧 × 1024 样本 = 40960 样本 = 2560ms。
        manifest = await recordSegments(<int>[1000, 1000, 500]);
        binding = buildBinding(manifest.sessionId);
        api.durationMs = manifest.effectiveDurationMs;
        expect(manifest.segments, hasLength(3), reason: '前置：必须真的产出 3 段');
        expect(
          manifest.segments.map((s) => s.sampleCount).reduce((a, b) => a + b),
          40 * 1024,
        );

        await upload();

        expect(api.completes, 1);
        expect(fd.uploads, 1, reason: '成品只直传一次');
        expect(fd.uploadedBytes, hasLength(1));

        // 成品字节 == 有序原段明文逐字节拼接（同源同 hash 的确定性拼接合同）。
        final uploaded = fd.uploadedBytes.single;
        expect(
          uploaded,
          equals(await expectedFinalBytes()),
          reason: '成品必须严格等于有序原段明文',
        );

        // 产物参数 == 合同常量（16kHz mono AAC-LC；真实 ADTS 头权威）。
        final summary = talkRecordAdtsScan(uploaded);
        expect(
          summary.sampleRateHz,
          kContractEncoder.sampleRateHz,
          reason: '采样率必须等于合同常量',
        );
        expect(
          summary.numChannels,
          kContractEncoder.numChannels,
          reason: '声道必须等于合同常量',
        );
        expect(summary.frameCount, 40);
        expect(summary.sampleCount, 40 * 1024);
        expect(
          summary.durationMs,
          msOfSamples(40 * 1024, kContractEncoder.sampleRateHz),
        );

        // complete 声明与 checkpoint 冻结对账。
        final decl = api.completedFinalAudio!;
        expect(decl.sampleRate, kContractEncoder.sampleRateHz);
        expect(decl.channels, kContractEncoder.numChannels);
        expect(decl.byteSize, uploaded.length);
        expect(
          decl.sha256,
          sha256.convert(uploaded).toString(),
          reason: '成品 sha 必须与直传字节一致',
        );
        expect(decl.sampleCount, 40 * 1024);
        expect(
          decl.durationMs,
          2560,
          reason: '样本轴统一舍入：40960 样本 @16kHz = 2560ms',
        );
        final cp = await TalkRecordUploadCheckpointStore(recorder.sessionDir!)
            .load(binding, talkRecordManifestHash(manifest.toJson()));
        expect(cp.finalAudio['confirmed'], true);
        expect(cp.finalAudio['sample_rate'], kContractEncoder.sampleRateHz);
        expect(cp.finalAudio['sample_count'], 40 * 1024);
        // 明文临时目录已收敛。
        expect(
          Directory('${recorder.sessionDir!.path}/.upload_plain').existsSync(),
          isFalse,
        );
      });
    },
  );

  group('NC-2 synthesis-period parameter drift gate', () {
    test('段间采样率漂移（16k→44.1k 立体声）必须在合成期拒绝', () async {
      manifest = await recordSegments(<int>[1000, 500]);
      expect(manifest.segments, hasLength(2));

      // 本地漂移场景：第 2 段密文被换成 44.1kHz 立体声 ADTS（manifest
      // 元数据字段照旧声明 16k/mono——漂移发生在真实字节层面，合成期
      // 逐段 ADTS 自检必须拦下）。
      final sessionDir = recorder.sessionDir!;
      final tamperedPlain = File('${sessionDir.parent.path}/tampered.aac');
      await tamperedPlain.writeAsBytes(
        adtsSegmentBytes(frames: 4, freqIdx: 4, channels: 2, salt: 99),
      );
      expect(
        talkRecordAdtsScan(await tamperedPlain.readAsBytes()).sampleRateHz,
        44100,
        reason: '前置：漂移段自身必须是合法的 44.1kHz ADTS',
      );
      final info = await TalkRecordSegmentCrypto.sealSegment(
        plainFile: tamperedPlain,
        cipherFile: File('${sessionDir.path}/seg_000001.aes'),
        recordKey: Uint8List.fromList(keys.store[manifest.sessionId]!),
        sessionId: manifest.sessionId,
        seq: 1,
        mime: 'audio/aac',
      );
      await tamperedPlain.delete();
      final store = TalkRecordManifestStore(sessionDir);
      await store.write(
        manifest.copyWith(
          segments: manifest.segments.map((segment) {
            if (segment.seq != 1) return segment;
            return TalkRecordSegmentEntry(
              seq: segment.seq,
              startMs: segment.startMs,
              endMs: segment.endMs,
              cipherFileName: segment.cipherFileName,
              cipherSize: info.cipherSize,
              cipherSha256Hex: info.cipherSha256Hex,
              plainSize: info.plainSize,
              plainSha256Hex: info.plainSha256Hex,
              codec: segment.codec,
              sampleRateHz: segment.sampleRateHz, // 元数据照旧：漂移只在真实字节
              numChannels: segment.numChannels,
              sampleCount: segment.sampleCount,
              capturedWallTimeIso: segment.capturedWallTimeIso,
            );
          }).toList(),
        ),
      );
      manifest = (await store.read())!;
      binding = buildBinding(manifest.sessionId);
      api.durationMs = manifest.effectiveDurationMs;

      await expectLater(
        upload(),
        throwsA(
          predicate(
            (e) => e is StateError && e.toString().contains('parameter drift'),
            'StateError(parameter drift across parts)',
          ),
        ),
      );
      expect(api.completedFinalAudio, isNull, reason: '漂移不得产出 complete 声明');
      expect(api.completes, 0);
      expect(fd.registers, 0, reason: '漂移在成品 register 之前拦截');
      expect(fd.uploads, 0, reason: '漂移成品不得直传');
      expect(
        Directory('${sessionDir.path}/.upload_plain').existsSync(),
        isFalse,
        reason: '失败路径明文临时目录必须收敛',
      );
    });
  });
}
