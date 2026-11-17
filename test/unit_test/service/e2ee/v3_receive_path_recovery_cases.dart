part of 'v3_receive_path_e2e_test.dart';

void _registerExistingReceiveRecoveryCases(_ReceivePathFixture fixture) {
  group('existing PFv3 恢复', () {
    setUp(() async {
      await StorageService.to.setString(Keys.currentUid, '200');
      SqliteService.setDbForTest(fixture.db);
      OlmSessionService.to.resetForTest();
      // 恒等协议在这里复刻真实协议的原子去重及解密结果提交。
      fixture.olmProtocol.commitInbound = true;
      MessageService.to;
      await MessageRetry.instance.debugWaitForIdle();
    });
    test('失败占位及空 sealed 正文持久化后才完成，重投幂等', () async {
      final events = <DataWrapperEvent<dynamic>>[];
      final sub = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
        events.add,
      );
      addTearDown(sub.cancel);
      for (final old in <Object>[
        {'_e2ee_failed': true},
        '',
      ]) {
        final id = old is String ? 'recover-empty' : 'recover-failed';
        final frame = await fixture.buildV3Message(id);
        await fixture.seedExisting(frame, old);
        expect(await MessageService.to.persistInboundMessage(frame), isTrue);
        final row = (await fixture.db.query(
          'msg_c2c',
          where: 'id = ?',
          whereArgs: [id],
        )).single;
        expect(
          (jsonDecode(row['payload'] as String) as Map)['body'],
          _plainBody,
        );
        expect(row['e2ee'], jsonEncode(frame['e2ee']));
        expect(row['status'], 20);
        expect(
          await fixture.db.query(
            'crypto_inbox_staging',
            where: 'message_id = ?',
            whereArgs: [id],
          ),
          isEmpty,
        );
        expect(
          await MessageService.to.persistInboundMessage(
            await fixture.buildV3Message(id),
          ),
          isTrue,
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.dataType == 'messages').length, 2);
      expect(await fixture.db.query('conversation'), isEmpty);
    });

    test('DB失败保留staging供重试；篡改、账号切换均拒绝物化', () async {
      final frame = await fixture.buildV3Message('recover-rollback');
      await fixture.seedExisting(frame, {'_e2ee_failed': true});
      await fixture.db.execute(
        "CREATE TRIGGER fail_recovery BEFORE UPDATE OF payload ON msg_c2c BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      expect(await MessageService.to.persistInboundMessage(frame), isFalse);
      expect(await fixture.db.query('crypto_inbox_staging'), isNotEmpty);
      expect(
        (await MessageRepo(tableName: 'msg_c2c').find('recover-rollback'))!
            .payloadMap['_e2ee_failed'],
        isTrue,
      );
      await fixture.db.execute('DROP TRIGGER fail_recovery');
      final conflict = await fixture.buildV3Message('recover-rollback');
      final envelope =
          ((conflict['e2ee'] as Map)['devices'] as Map)[deviceId] as Map;
      envelope['ciphertext'] = '${envelope['ciphertext']}A';
      expect(await MessageService.to.persistInboundMessage(conflict), isFalse);
      expect(await fixture.db.query('crypto_inbox_staging'), isNotEmpty);
      expect(
        await MessageService.to.persistInboundMessage(
          await fixture.buildV3Message('recover-rollback'),
        ),
        isTrue,
      );
      final switched = await fixture.buildV3Message('recover-switched');
      await fixture.seedExisting(switched, {'_e2ee_failed': true});
      fixture.olmProtocol.beforeDecrypt = () async {
        await StorageService.to.setString(Keys.currentUid, '300');
      };
      expect(await MessageService.to.persistInboundMessage(switched), isFalse);
      expect(
        (await fixture.db.query(
          'msg_c2c',
          where: 'id = ?',
          whereArgs: ['recover-switched'],
        )).single['payload'],
        jsonEncode({'_e2ee_failed': true}),
      );
      expect(
        await fixture.db.query(
          'crypto_inbox_staging',
          where: 'message_id = ?',
          whereArgs: ['recover-switched'],
        ),
        isNotEmpty,
      );
      await StorageService.to.setString(Keys.currentUid, '200');
      SqliteService.setDbForTest(fixture.db);
    });

    test('completion失败后重试补发一次UI，并保留本地焚毁计时起点', () async {
      final frame = await fixture.buildV3Message('recover-completion');
      final readAt = DateTime.now().millisecondsSinceEpoch;
      await fixture.seedExisting(frame, {
        '_e2ee_failed': true,
        'burn_read_at': readAt,
      });
      final events = <DataWrapperEvent<dynamic>>[];
      final sub = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
        events.add,
      );
      addTearDown(sub.cancel);
      await fixture.db.execute(
        "CREATE TRIGGER fail_completion BEFORE DELETE ON crypto_inbox_staging BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      expect(await MessageService.to.persistInboundMessage(frame), isFalse);
      final row = await MessageRepo(tableName: 'msg_c2c')
          .find('recover-completion');
      expect(row!.payloadMap['body'], _plainBody);
      expect(row.payloadMap['burn_read_at'], readAt);
      expect(await fixture.db.query('crypto_inbox_staging'), isNotEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.dataType == 'messages'), isEmpty);
      await fixture.db.execute('DROP TRIGGER fail_completion');
      expect(
        await MessageService.to.persistInboundMessage(
          await fixture.buildV3Message('recover-completion'),
        ),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.dataType == 'messages').length, 1);
      expect(await fixture.db.query('crypto_inbox_staging'), isEmpty);
      expect(
        await MessageService.to.persistInboundMessage(
          await fixture.buildV3Message('recover-completion'),
        ),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.dataType == 'messages').length, 1);
    });

    test('撤回、编辑及过期行保持原值', () async {
      for (final entry in [
        (30, <String, dynamic>{'_e2ee_failed': true}),
        (20, <String, dynamic>{'_e2ee_failed': true, 'is_edited': true}),
        (20, <String, dynamic>{'_e2ee_failed': true, 'burn_deleted': true}),
        (
          20,
          <String, dynamic>{
            '_e2ee_failed': true,
            'burn': true,
            'burn_after_ms': 1000,
            'burn_read_at': 1,
          },
        ),
      ].indexed) {
        final id = 'recover-protected-${entry.$1}';
        final frame = await fixture.buildV3Message(id);
        await fixture.seedExisting(frame, entry.$2.$2, status: entry.$2.$1);
        expect(await MessageService.to.persistInboundMessage(frame), isTrue);
        expect(
          (await fixture.db.query(
            'msg_c2c',
            where: 'id = ?',
            whereArgs: [id],
          )).single['payload'],
          jsonEncode(entry.$2.$2),
        );
      }
    });
  });
}
