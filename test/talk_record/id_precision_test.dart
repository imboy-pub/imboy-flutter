/// T08 面聊记录（talk_record）TSID 精度测试。
///
/// 契约（BACKEND-API.md §2 + CONTRACT-FREEZE-T02 §3.3）：64-bit TSID 以
/// JSON integer 传输；App 端一律经 entityIdOf 转 String（EntityId）持有，
/// 全程不回转 int/num。超过 2^53 的 TSID 若被解析为 double 会丢精度——
/// 本文件所有断言 ID 均取 > 2^53 的 64-bit 值（对齐
/// test/enterprise/enterprise_tsid_precision_test.dart 模式）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_job_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_summary_model.dart';

/// > 2^53（double 安全整数上限）的 TSID 样本。
const int bigRecordId = 7366418340025468940;
const int bigOwnerId = 7366418340025468941;
const int bigCreatedBy = 7366418340025468942;
const int bigOrgId = 7366418340025468943;
const int bigWsId = 7366418340025468944;
const int bigCaptureId = 7366418340025468945;
const int bigSegmentId = 7366418340025468946;
const int bigSpeakerId = 7366418340025468947;
const int bigGrantId = 7366418340025468948;
const int bigGranteeId = 7366418340025468949;
const int bigJobId = 7366418340025468950;
const int bigMarkId = 7366418340025468951;
const int bigSummaryId = 7366418340025468952;
const int bigTranscriptId = 7366418340025468953;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T08 talk_record TSID 精度（>2^53）', () {
    test('TalkRecordModel：全部 TSID 字段精确保留', () {
      final record = TalkRecordModel.fromJson(const {
        'id': bigRecordId,
        'owner_user_id': bigOwnerId,
        'created_by': bigCreatedBy,
        'organization_id': bigOrgId,
        'workspace_id': bigWsId,
        'active_capture_id': bigCaptureId,
        'current_transcript_id': bigTranscriptId,
      });
      expect(record.id, '7366418340025468940');
      expect(record.ownerUserId, '7366418340025468941');
      expect(record.createdBy, '7366418340025468942');
      expect(record.organizationId, '7366418340025468943');
      expect(record.workspaceId, '7366418340025468944');
      expect(record.activeCaptureId, '7366418340025468945');
      expect(record.currentTranscriptId, '7366418340025468953');
      // 反向防呆：类型必须是 String（EntityId）。
      expect(record.id, isA<String>());
      expect(record.organizationId, isA<String>());
    });

    test('capture/segment/speaker/grant/job/mark/summary 各行 TSID 无损', () {
      final capture = TalkRecordCaptureModel.fromJson(const {
        'id': bigCaptureId,
        'record_id': bigRecordId,
        'started_by': bigOwnerId,
      });
      expect(capture.id, '7366418340025468945');
      expect(capture.recordId, '7366418340025468940');

      final segment = TalkRecordSegmentModel.fromJson(const {
        'id': bigSegmentId,
        'record_id': bigRecordId,
        'speaker_id': bigSpeakerId,
        'edited_by': bigOwnerId,
      });
      expect(segment.id, '7366418340025468946');
      expect(segment.speakerId, '7366418340025468947');

      final speaker = TalkRecordSpeakerModel.fromJson(const {
        'id': bigSpeakerId,
        'record_id': bigRecordId,
        'matched_user_id': bigGranteeId,
        'confirmed_by': bigGranteeId,
      });
      expect(speaker.id, '7366418340025468947');
      expect(speaker.matchedUserId, '7366418340025468949');

      final grant = TalkRecordGrantModel.fromJson(const {
        'id': bigGrantId,
        'record_id': bigRecordId,
        'grantee_user_id': bigGranteeId,
        'granted_by': bigOwnerId,
      });
      expect(grant.id, '7366418340025468948');
      expect(grant.granteeUserId, '7366418340025468949');

      final job = TalkRecordJobModel.fromJson(const {
        'id': bigJobId,
        'record_id': bigRecordId,
      });
      expect(job.id, '7366418340025468950');

      final mark = TalkRecordMarkModel.fromJson(const {
        'id': bigMarkId,
        'record_id': bigRecordId,
        'author_id': bigOwnerId,
        'capture_id': bigCaptureId,
      });
      expect(mark.id, '7366418340025468951');
      expect(mark.captureId, '7366418340025468945');

      final summary = TalkRecordSummaryModel.fromJson(const {
        'id': bigSummaryId,
        'record_id': bigRecordId,
        'confirmed_by': bigOwnerId,
      });
      expect(summary.id, '7366418340025468952');
    });

    test('端到端：jsonDecode 大整数 envelope → Model 全程 string 不丢精度', () {
      // 模拟服务端返回体：TSID 为 JSON integer；jsonDecode 后是 Dart int
      //（VM 上 64 位无损），Model 解析必须原样转 string 而非经 double 往返。
      final body = jsonDecode(
        '{"code":0,"msg":"success","payload":{'
        '"list":[{"id":$bigRecordId,'
        '"owner_user_id":$bigOwnerId,'
        '"organization_id":$bigOrgId,'
        '"active_capture_id":$bigCaptureId}],'
        '"next_cursor":"","has_more":false}}',
      ) as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(body['payload'] as Map);
      final row = Map<String, dynamic>.from(
        (payload['list'] as List).first as Map,
      );

      final record = TalkRecordModel.fromJson(row);
      expect(record.id, '7366418340025468940');
      expect(record.ownerUserId, '7366418340025468941');
      expect(record.organizationId, '7366418340025468943');
      expect(record.activeCaptureId, '7366418340025468945');
    });

    test('序列化：toJson 的 TSID 以 string 落 JSON（不回转 int）', () {
      final record = TalkRecordModel.fromJson(const {
        'id': bigRecordId,
        'owner_user_id': bigOwnerId,
        'organization_id': bigOrgId,
      });
      final encoded = jsonEncode(record.toJson());
      // string 形式带引号；若回转 int 则引号消失。
      expect(encoded, contains('"id":"7366418340025468940"'));
      expect(encoded, contains('"owner_user_id":"7366418340025468941"'));
      expect(encoded, contains('"organization_id":"7366418340025468943"'));

      final grant = TalkRecordGrantModel.fromJson(const {
        'id': bigGrantId,
        'record_id': bigRecordId,
        'grantee_user_id': bigGranteeId,
      });
      final grantEncoded = jsonEncode(grant.toJson());
      expect(grantEncoded, contains('"grantee_user_id":"7366418340025468949"'));
    });

    test('摘要结构项 segment_ids 同样以 EntityId 持有', () {
      final summary = TalkRecordSummaryModel.fromJson(const {
        'id': bigSummaryId,
        'decisions': [
          {
            'text': '采用 A 方案',
            'segment_ids': [bigSegmentId, bigSpeakerId],
          },
        ],
      });
      final segs = summary.decisions.single.segmentIds;
      expect(segs, ['7366418340025468946', '7366418340025468947']);
      expect(segs.first, isA<String>());
    });
  });
}
