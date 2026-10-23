part of 'talk_record_doubao_workflow_test.dart';

void _registerRecoveryCases(
  _Gateway Function() gateway,
  _Provider Function() vendor,
  TalkRecordAiCheckpointStore Function() checkpoints,
  TalkRecordAiCoordinator Function() coordinator,
) {
  test('no execution discovery authorizes fresh claim distinct from uncertain old key', () async {
    final backend = gateway();
    backend.loseAfter = 'claim';
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(anything),
    );
    backend.claimed =
        false; // Synthetic server says first request never arrived.
    final old = (await checkpoints().load())!;
    final oldKey = (old['operations'] as Map)['claim']['key'];
    await coordinator().execute(consentConfirmed: true);
    final saved = (await checkpoints().load())!;
    final freshKey =
        (saved['operations'] as Map)['claim-after-empty-discovery']['key'];
    expect(freshKey, isNot(oldKey));
    expect(
      backend.actions,
      containsAllInOrder(['latest', 'claim', 'provider-create']),
    );
    expect(vendor().submits, 1);
  });
  for (final expired in [false, true]) {
    test(
      'lost claim response recovers unprepared run expired=$expired without claim replay',
      () async {
        final backend = gateway();
        backend.loseAfter = 'claim';
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(anything),
        );
        backend.expired = expired;
        await coordinator().execute(consentConfirmed: true);
        expect(backend.actions.where((a) => a == 'claim'), hasLength(1));
        expect(
          backend.actions,
          containsAllInOrder([
            'latest',
            'recover-unprepared',
            'provider-create',
          ]),
        );
        expect(vendor().submits, 1);
        expect((await checkpoints().load())!['phase'], 'complete');
      },
    );
  }
  test(
    'lost recover response reuses saved recovery key after latest discovery',
    () async {
      final backend = gateway();
      backend.loseAfter = 'claim';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      backend.loseAfter = 'recover-unprepared';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      await coordinator().execute(consentConfirmed: true);
      expect(backend.recoveryKeys, hasLength(2));
      expect(backend.recoveryKeys.toSet(), hasLength(1));
      expect(vendor().submits, 1);
    },
  );
  test('another device busy never recovers or prepares', () async {
    final backend = gateway();
    backend.loseAfter = 'claim';
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(anything),
    );
    backend.otherDevice = true;
    await expectLater(
      coordinator().execute(consentConfirmed: true),
      throwsA(
        isA<TalkRecordAiWorkflowException>().having(
          (e) => e.code,
          'code',
          'execution_device_busy',
        ),
      ),
    );
    expect(backend.actions, isNot(contains('recover-unprepared')));
    expect(vendor().submits, 0);
  });
  test(
    'prepare response loss discovers task but no token is granted by latest',
    () async {
      final backend = gateway();
      backend.loseAfter = 'provider-create';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(
          isA<TalkRecordAiWorkflowException>().having(
            (e) => e.code,
            'code',
            'provider_preparation_required',
          ),
        ),
      );
      expect(
        backend.actions.where((a) => a == 'provider-create'),
        hasLength(1),
      );
      expect(backend.actions, contains('latest'));
      expect(vendor().submits, 0);
      expect((await checkpoints().load())!['provider_task'], isNotNull);
      final control = coordinator();
      backend.preparationExpired = true;
      await control.resumeProviderPreparation(consentConfirmed: true);
      await control.execute(consentConfirmed: true);
      expect(vendor().submits, 1);
    },
  );
}
