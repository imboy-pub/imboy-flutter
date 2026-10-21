import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart' as app;
import 'package:imboy/modules/talk_record/application/talk_record_capture_api_gateway.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';

class RecoveryApi extends TalkRecordApi {
  List<TalkRecordCaptureModel> existing = [];
  TalkRecordCaptureModel recovered = TalkRecordCaptureModel.fromJson({
    'id': 2,
    'record_id': 1,
    'device_session_id': 'device-session',
    'lease_epoch': 0,
    'status': 'recording',
    'lease_until': DateTime.now()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
  });
  int created = 0, recoveries = 0;
  final devices = <String>[];
  Future<void> Function()? beforeCreate;
  final keys = <String>[];
  String ownerId = '100';
  @override
  Future<TalkRecordFetched<TalkRecordModel>> detail(String id) async =>
      TalkRecordFetched(
        TalkRecordModel(
          id: '1',
          ownerUserId: ownerId,
          clientRecordingId: 'record-client',
          scope: TalkRecordScope.personal,
        ),
        etag: '"1"',
      );
  @override
  Future<List<TalkRecordCaptureModel>> captures(String id) async => existing;
  @override
  Future<TalkRecordCaptureModel> recoverCapture(
    String id,
    String captureId, {
    required String deviceSessionId,
  }) async {
    recoveries++;
    return recovered;
  }

  @override
  Future<TalkRecordCaptureModel> createCapture(
    String id, {
    required String deviceSessionId,
    required String idempotencyKey,
    required String ifMatch,
    String deviceId = '',
  }) async {
    created++;
    devices.add(deviceId);
    await beforeCreate?.call();
    keys.add(idempotencyKey);
    return recovered;
  }
}

void main() {
  setUp(() {
    app.deviceId = 'synthetic-install-device';
  });

  const local = TalkRecordLocalBinding(
    account: TalkRecordAccount('https://local.example', '100'),
    clientRecordingId: 'record-client',
    deviceSessionId: 'device-session',
    context: TalkRecordEntryContext.personal(),
    title: '',
    processingMode: 'record_only',
    recordId: '1',
    recordEtag: '"record-1"',
  );

  test('response-lost create reconciles existing device session and recovers, no fresh capture', () async {
    final api = RecoveryApi()
      ..existing = [
        const TalkRecordCaptureModel(
          id: '2',
          recordId: '1',
          deviceSessionId: 'device-session',
        ),
      ];
    final checkpoints = <TalkRecordLocalBinding>[];
    final bound = await TalkRecordApiCaptureGateway(api)
        .bind(local, (value) async => checkpoints.add(value), () {});
    expect(api.created, 0);
    expect(api.recoveries, 1);
    expect(bound.leaseEpoch, 0);
    expect(checkpoints.single.captureId, '2');
  });
  test(
    'ambiguous mapping fails closed rather than resetting sequence',
    () async {
      final api = RecoveryApi()
        ..existing = [
          const TalkRecordCaptureModel(
            id: '2',
            deviceSessionId: 'device-session',
          ),
          const TalkRecordCaptureModel(
            id: '3',
            deviceSessionId: 'device-session',
          ),
        ];
      await expectLater(
        TalkRecordApiCaptureGateway(api).bind(local, (_) async {}, () {}),
        throwsStateError,
      );
      expect(api.created, 0);
      expect(api.recoveries, 0);
    },
  );
  test('recovery rejects foreign device identity', () async {
    final api = RecoveryApi()
      ..recovered = const TalkRecordCaptureModel(
        id: '2',
        recordId: '1',
        deviceSessionId: 'different-session',
      );
    await expectLater(
      TalkRecordApiCaptureGateway(api)
          .bind(local.copyWith(captureId: '2'), (_) async {}, () {}),
      throwsStateError,
    );
    expect(api.created, 0);
  });
  test(
    'first capture uses the same persisted idempotency key on retry',
    () async {
      final api = RecoveryApi();
      final gateway = TalkRecordApiCaptureGateway(api);
      await gateway.bind(local, (_) async {}, () {});
      await gateway.bind(local, (_) async {}, () {});
      expect(api.keys, ['device-session', 'device-session']);
    },
  );
  test('account fence prevents any server request', () async {
    final api = RecoveryApi();
    await expectLater(
      TalkRecordApiCaptureGateway(api)
          .bind(local, (_) async {}, () => throw StateError('changed')),
      throwsStateError,
    );
    expect(api.created, 0);
    expect(api.recoveries, 0);
  });
  test('missing epoch in actual DTO remains unknown and recovery never recreates capture', () async {
    final api = RecoveryApi()
      ..recovered = TalkRecordCaptureModel.fromJson({
        'id': '2',
        'record_id': '1',
        'device_session_id': 'device-session',
        'status': 'recording',
        'lease_until': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      });
    expect(api.recovered.leaseEpoch, -1);
    await expectLater(
      TalkRecordApiCaptureGateway(api)
          .bind(local.copyWith(captureId: '2'), (_) async {}, () {}),
      throwsStateError,
    );
    expect(api.recoveries, 1);
    expect(api.created, 0);
  });
  test(
    'DTO accepts epoch zero but rejects boolean/fraction/malformed/missing',
    () {
      expect(
        TalkRecordCaptureModel.fromJson({'id': '2', 'lease_epoch': 0})
            .leaseEpoch,
        0,
      );
      expect(
        TalkRecordCaptureModel.fromJson({'id': '2', 'lease_epoch': '0'})
            .leaseEpoch,
        0,
      );
      for (final malformed in [null, false, true, 0.5, '0.5', 'false', -2]) {
        expect(
          TalkRecordCaptureModel.fromJson({'id': '2', 'lease_epoch': malformed})
              .leaseEpoch,
          -1,
        );
      }
      expect(const TalkRecordCaptureModel(id: '2').leaseEpoch, -1);
    },
  );
  test(
    'fenced ended capture and unknown status rejected even with future lease',
    () async {
      final api = RecoveryApi();
      for (final status in [
        TalkRecordCaptureStatus.unknown,
        TalkRecordCaptureStatus.ended,
      ]) {
        api.recovered = TalkRecordCaptureModel(
          id: '2',
          recordId: '1',
          deviceSessionId: 'device-session',
          status: status,
          leaseEpoch: 1,
          leaseUntil: DateTime.now().add(const Duration(minutes: 5)),
        );
        await expectLater(
          TalkRecordApiCaptureGateway(api)
              .bind(local.copyWith(captureId: '2'), (_) async {}, () {}),
          throwsStateError,
        );
      }
      expect(api.created, 0);
    },
  );
  test(
    'backend initial draft with epoch zero is a valid capture binding',
    () async {
      final api = RecoveryApi()
        ..recovered = TalkRecordCaptureModel.fromJson({
          'capture_id': 2,
          'record_id': 1,
          'device_session_id': 'device-session',
          'status': 'draft',
          'lease_epoch': 0,
          'lease_until': DateTime.now()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        });
      final bound = await TalkRecordApiCaptureGateway(api)
          .bind(local, (_) async {}, () {});
      expect(bound.captureStatus, 'draft');
      expect(bound.leaseEpoch, 0);
    },
  );
  test('normally ended expired lease binds through current owner GET without recover', () async {
    final api = RecoveryApi();
    api.existing = [
      TalkRecordCaptureModel.fromJson({
        'capture_id': 2,
        'record_id': 1,
        'device_session_id': 'device-session',
        'status': 'ended',
        'lease_epoch': 0,
        'lease_until': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      }),
    ];
    final bound = await TalkRecordApiCaptureGateway(api)
        .bind(local.copyWith(captureId: '2'), (_) async {}, () {});
    expect(bound.captureStatus, 'ended');
    expect(api.recoveries, 0);
    expect(api.created, 0);
    api.ownerId = '200';
    await expectLater(
      TalkRecordApiCaptureGateway(api)
          .bind(local.copyWith(captureId: '2'), (_) async {}, () {}),
      throwsStateError,
    );
  });
  test('production default uses signed-header install ID and checkpoints before capture create', () async {
    final api = RecoveryApi();
    final saved = <TalkRecordLocalBinding>[];
    api.beforeCreate = () async {
      expect(saved.last.deviceId, 'synthetic-install-device');
      expect(saved.last.captureId, isEmpty);
    };
    final bound = await TalkRecordApiCaptureGateway(api)
        .bind(local, (value) async {
          saved.add(value);
        }, () {});
    expect(api.devices, ['synthetic-install-device']);
    expect(bound.deviceId, 'synthetic-install-device');
    expect(
      TalkRecordLocalBinding.fromJson(bound.toJson()).deviceId,
      bound.deviceId,
    );
  });
  test(
    'pinned device request never drifts after install resolver changes',
    () async {
      final api = RecoveryApi();
      var current = 'install-A';
      final gateway = TalkRecordApiCaptureGateway(api, deviceId: () => current);
      TalkRecordLocalBinding? pinned;
      api.beforeCreate = () async {
        throw StateError('response lost');
      };
      await expectLater(
        gateway.bind(local, (value) async {
          pinned = value;
        }, () {}),
        throwsStateError,
      );
      expect(pinned!.deviceId, 'install-A');
      current = 'install-B';
      api.beforeCreate = null;
      final bound = await gateway.bind(pinned!, (_) async {}, () {});
      expect(api.devices, ['install-A', 'install-A']);
      expect(bound.deviceId, 'install-A');
      expect(() => bound.copyWith(deviceId: 'install-B'), throwsStateError);
    },
  );
  test('legacy unknown ID with exact existing capture recovers without resolver or new capture', () async {
    final api = RecoveryApi()
      ..existing = [
        const TalkRecordCaptureModel(
          id: '2',
          deviceSessionId: 'device-session',
        ),
      ];
    final bound = await TalkRecordApiCaptureGateway(
      api,
      deviceId: () {
        throw StateError('must not invent legacy device ID');
      },
    ).bind(local, (_) async {}, () {});
    expect(bound.captureId, '2');
    expect(bound.deviceId, isEmpty);
    expect(api.created, 0);
    expect(api.recoveries, 1);
  });
  test(
    'missing install ID and checkpoint failure never send capture create',
    () async {
      final api = RecoveryApi();
      app.deviceId = '';
      await expectLater(
        TalkRecordApiCaptureGateway(api).bind(local, (_) async {}, () {}),
        throwsStateError,
      );
      expect(api.created, 0);
      app.deviceId = 'synthetic-install-device';
      await expectLater(
        TalkRecordApiCaptureGateway(api).bind(local, (_) async {
          throw FileSystemException('checkpoint failed');
        }, () {}),
        throwsA(isA<FileSystemException>()),
      );
      expect(api.created, 0);
    },
  );
}
