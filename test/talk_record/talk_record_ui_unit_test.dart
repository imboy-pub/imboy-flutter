/// T10 面聊记录 UI 层单元测试：纯函数（时长/状态文案/降级矩阵）、
/// 入口上下文序列化、草稿与列表 Notifier 状态迁移。
///
/// 纯 Dart/Provider 逻辑测试——不 pump widget、无网络、无平台通道；
/// widget 级矩阵见 talk_record_list_page_test / talk_record_prepare_page_test。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_prepare_page.dart'
    show TalkRecordProcessingAvailability;
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_ui_helpers.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';

void main() {
  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });

  group('talkRecordFormatDuration', () {
    test('mm:ss / h:mm:ss 与零值', () {
      expect(talkRecordFormatDuration(0), '00:00');
      expect(talkRecordFormatDuration(59_000), '00:59');
      expect(talkRecordFormatDuration(655_000), '10:55');
      expect(talkRecordFormatDuration(3_725_000), '1:02:05');
    });
  });

  group('talkRecordStatusText', () {
    TalkRecordModel record({
      String media = 'available',
      String transcript = 'ready',
      String processing = 'transcribe',
      String capture = 'ended',
    }) {
      return TalkRecordModel.fromJson({
        'id': 101,
        'media_status': media,
        'transcript_status': transcript,
        'processing_mode': processing,
        'capture_status': capture,
        'duration_ms': 60_000,
        'visibility': 'owner_only',
      });
    }

    test('转写就绪', () {
      expect(
        talkRecordStatusText(record()),
        t.talkRecord.statusTranscribeReady,
      );
    });

    test('上传链路优先于转写；失败态明示可重试', () {
      expect(
        talkRecordStatusText(record(media: 'uploading', transcript: 'ready')),
        t.talkRecord.statusUploading,
      );
      expect(
        talkRecordStatusText(
          record(media: 'retryable_failed', transcript: 'ready'),
        ),
        t.talkRecord.statusUploadFailed,
      );
    });

    test('录音中优先于转写排队', () {
      expect(
        talkRecordStatusText(
          record(transcript: 'queued', capture: 'recording'),
        ),
        t.talkRecord.statusRecording,
      );
    });

    test('无语音 ≠ 转写失败（UI-SPEC §4）', () {
      expect(
        talkRecordStatusText(record(transcript: 'no_speech')),
        t.talkRecord.statusNoSpeech,
      );
    });

    test('仅录音模式显示「仅录音」', () {
      expect(
        talkRecordStatusText(record(transcript: 'not_requested')),
        t.talkRecord.statusRecordOnly,
      );
    });
  });

  group('TalkRecordEntryContext 序列化', () {
    test('个人不携带企业/工作区字段', () {
      final q = const TalkRecordEntryContext.personal().toQuery();
      expect(q, {'scope': 'personal'});
      final back = TalkRecordEntryContext.fromQuery(q);
      expect(back.isOrganization, false);
      expect(back.organizationId, '');
    });

    test('企业往返保留 org/ws（未知值降级 personal，不猜企业）', () {
      const ctx = TalkRecordEntryContext(
        scope: TalkRecordScope.organization,
        organizationId: '7001',
        organizationName: '甲企业',
        workspaceId: '8001',
        workspaceName: '主工作区',
      );
      final back = TalkRecordEntryContext.fromQuery(ctx.toQuery());
      expect(back.organizationId, '7001');
      expect(back.organizationName, '甲企业');
      expect(back.hasWorkspace, true);

      final unknown = TalkRecordEntryContext.fromQuery({'scope': 'weird'});
      expect(unknown.isOrganization, false);
    });
  });

  group('TalkRecordProcessingAvailability.evaluate（能力降级矩阵）', () {
    final configured = TalkRecordCapabilitiesModel.fromJson({
      'processing_available': true,
      'asr_enabled': true,
      'processor_config_version': 'approved-bundle-v1',
      'summary_enabled': true,
      'queue_limit': 5,
    });

    test('enabled flags without processor configuration version cannot offer processing', () {
      final capabilities = TalkRecordCapabilitiesModel.fromJson({
        'processing_available': true,
        'asr_enabled': true,
        'queue_limit': 5,
      });
      expect(capabilities.canProcess, isFalse);
      expect(TalkRecordProcessingAvailability.evaluate(capabilities).modes, [
        TalkRecordProcessingMode.recordOnly,
      ]);
    });

    test('未配置转写 → 仅录音 + 原因', () {
      final r = TalkRecordProcessingAvailability.evaluate(
        TalkRecordCapabilitiesModel.fromJson({'asr_enabled': false}),
      );
      expect(r.modes, [TalkRecordProcessingMode.recordOnly]);
      expect(r.reasonKey, 'processingReasonUnavailable');
    });

    test('配额不足（queue_limit<=0）→ 仅录音，录音不受影响', () {
      final r = TalkRecordProcessingAvailability.evaluate(
        TalkRecordCapabilitiesModel.fromJson({
          'processing_available': true,
          'asr_enabled': true,
          'processor_config_version': 'approved-bundle-v1',
          'queue_limit': 0,
        }),
      );
      expect(r.modes, [TalkRecordProcessingMode.recordOnly]);
      expect(r.reasonKey, 'processingReasonQuota');
    });

    test('能力加载失败（null）→ 仅录音 + 加载失败原因', () {
      final r = TalkRecordProcessingAvailability.evaluate(null);
      expect(r.modes, [TalkRecordProcessingMode.recordOnly]);
      expect(r.reasonKey, 'processingReasonLoadFailed');
    });

    test('已配置 → 仅录音/转写/转写并摘要', () {
      final r = TalkRecordProcessingAvailability.evaluate(configured);
      expect(
        r.modes,
        containsAll([
          TalkRecordProcessingMode.recordOnly,
          TalkRecordProcessingMode.transcribe,
        ]),
      );
      expect(r.modes, contains(TalkRecordProcessingMode.summarize));
      expect(r.reasonKey, null);
    });

    test('配置了转写但未配置摘要 → 不出现摘要档', () {
      final r = TalkRecordProcessingAvailability.evaluate(
        TalkRecordCapabilitiesModel.fromJson({
          'processing_available': true,
          'asr_enabled': true,
          'processor_config_version': 'approved-bundle-v1',
          'summary_enabled': false,
          'queue_limit': 3,
        }),
      );
      expect(r.modes, isNot(contains(TalkRecordProcessingMode.summarize)));
    });
  });

  group('TalkRecordDraftNotifier（导航不丢稿/参与者清空规则）', () {
    test('跨个人↔企业清空参与者，标题保留', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(talkRecordDraftProvider.notifier);

      notifier
        ..setTitle('客户访谈')
        ..setSaveTo(
          const TalkRecordEntryContext(
            scope: TalkRecordScope.organization,
            organizationId: '7001',
            organizationName: '甲企业',
          ),
        )
        ..toggleParticipant(
          const TalkRecordParticipantSelection(
            userId: '9001',
            displayName: '张三',
          ),
        )
        ..setNoticeAcknowledged(true);

      var draft = container.read(talkRecordDraftProvider);
      expect(draft.title, '客户访谈');
      expect(draft.participants, hasLength(1));
      expect(draft.noticeAcknowledged, true);

      // 企业 → 个人：参与者清空、标题保留、告知确认保留（通用内容）。
      notifier.setSaveTo(const TalkRecordEntryContext.personal());
      draft = container.read(talkRecordDraftProvider);
      expect(draft.participants, isEmpty);
      expect(draft.title, '客户访谈');
      expect(draft.noticeAcknowledged, true);

      // 同企业换工作区：目录边界变化，必须重新明确选择参与者。
      notifier
        ..setSaveTo(
          const TalkRecordEntryContext(
            scope: TalkRecordScope.organization,
            organizationId: '7001',
            workspaceId: '8001',
            workspaceName: '主工作区',
          ),
        )
        ..toggleParticipant(
          const TalkRecordParticipantSelection(userId: '9001'),
        );
      notifier.setSaveTo(
        const TalkRecordEntryContext(
          scope: TalkRecordScope.organization,
          organizationId: '7001',
          workspaceId: '8002',
          workspaceName: '二号工作区',
        ),
      );
      expect(container.read(talkRecordDraftProvider).participants, isEmpty);
    });

    test('首次变更保存位置也按入口上下文判跨界（previousEffective 回归）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(talkRecordDraftProvider.notifier);
      notifier.toggleParticipant(
        const TalkRecordParticipantSelection(userId: '9001'),
      );
      // 草稿从未显式 setSaveTo：首次变更须拿入口上下文判跨界，
      // 否则企业→个人的参与者清空会漏（widget 测试发现的缺陷）。
      notifier.setSaveTo(
        const TalkRecordEntryContext.personal(),
        previousEffective: const TalkRecordEntryContext(
          scope: TalkRecordScope.organization,
          organizationId: '7001',
        ),
      );
      expect(container.read(talkRecordDraftProvider).participants, isEmpty);
    });

    test('effectiveSaveTo 回落入口上下文', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(talkRecordDraftProvider.notifier);
      const entry = TalkRecordEntryContext.personal();
      expect(
        container.read(talkRecordDraftProvider).effectiveSaveTo(entry),
        entry,
      );
      notifier.setSaveTo(
        const TalkRecordEntryContext(
          scope: TalkRecordScope.organization,
          organizationId: '7001',
        ),
      );
      expect(
        container
            .read(talkRecordDraftProvider)
            .effectiveSaveTo(entry)
            .isOrganization,
        true,
      );
    });
  });

  group('默认服务占位（不假装可用）', () {
    test('UnavailableRecordingLauncher 如实返回不可用', () async {
      const launcher = UnavailableRecordingLauncher();
      final result = await launcher.launch(
        TalkRecordRecordingDraftRequest(
          saveTo: const TalkRecordEntryContext.personal(),
        ),
      );
      expect(result.started, false);
      expect(result.messageKey, 'recordingUnavailableMessage');
    });

    test('EmptyParticipantDirectory 不可用且不猜候选', () async {
      const directory = EmptyParticipantDirectory();
      expect(directory.isAvailable, false);
      expect(await directory.search('7001', ''), isEmpty);
    });
  });
}
