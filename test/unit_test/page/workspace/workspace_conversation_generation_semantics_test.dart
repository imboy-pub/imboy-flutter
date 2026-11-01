// plan-v2.2 §9 J28.c（退出再加入 workspace 群 → 旧 generation 偏好/水位/
// 内容回填）App 侧世代语义单测（纯模型，零网络）。
//
// 语义锚点（plan §6.7 / W09.b 记录）：
//   - WorkspaceConversationModel.memberGenerationId 是偏好动作的世代身份
//     descriptor（服务端 gen.id 投影）；0/缺失 = 世代未知（旧服务端），
//     折叠 '0' 不伪造世代；
//   - 退出再加入：服务端 close 旧 generation、新世代换绑（新 member_start_seq
//     前移）；旧世代水位（latest_message.conv_seq < 新 member_start_seq）
//     不是完整快照，必须拒绝回填——旧行数据保留在旧响应里，但不得被新世代
//     快照采纳（服务端世代过滤为主，App 解析层 fail-closed 为辅）；
//   - 大十进制世代 ID 规范化保留（J27.d 同口径：逐字符十进制不变）。
//
// 既有互补覆盖（不重复）：
//   - 内容回填定位的世代 fence：chat_archive_location_test.dart
//     J18.f 「generation 边界切换丢弃晚到上下文」向量；
//   - 偏好服务端世代绑定/读过滤：Backend conversation_pref_generation_pg_tests
//     （V1–V5，Backend 域）；App 本地 SQLite 无世代新列（W09.d 记录）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';

/// 基准行：与 workspace_conversations_api_test 的 messageRow 同构。
///
/// [generation] 非 null 或 [withGenerationKey] 时输出键（值为 null =
/// 服务端显式 null）；两者都否 = 旧服务端响应（键整体缺席）。
/// [latest] 非 null 或 [withLatestKey]（默认 true）时输出键；
/// `withLatestKey: false` = 键整体缺席（非完整快照）。
Map<String, dynamic> _row({
  int id = 1,
  int startSeq = 3,
  Object? generation,
  bool withGenerationKey = false,
  Object? latest,
  bool withLatestKey = true,
  int unread = 0,
}) => {
  'id': id,
  'scope': 'workspace',
  'workspace_id': 100,
  'status': 1,
  'title': 'Group $id',
  'member_start_seq': startSeq,
  if (generation != null || withGenerationKey)
    'member_generation_id': generation,
  if (latest != null || withLatestKey) 'latest_message': latest,
  'unread_count': unread,
};

Map<String, dynamic> _latest({required int seq, String msgId = 'opaque-msg'}) =>
    {
      'msg_id': msgId,
      'conv_seq': seq,
      'msg_type': 'text',
      'payload': <String, dynamic>{
        'payload': <String, dynamic>{'text': 'synthetic'},
      },
      'e2ee': null,
      'server_ts': '2026-10-01T00:00:00Z',
      'expire_at': null,
    };

void main() {
  group('J28.c：世代身份 descriptor（偏好动作身份投影）', () {
    test('缺失/0/负数/非法/浮点折叠为 0——旧服务端不伪造世代', () {
      final vectors = <Object?>[
        null,
        0,
        '0',
        -5,
        '-5',
        'gen-x',
        7.5,
        <String, dynamic>{},
      ];
      for (final vector in vectors) {
        final model = WorkspaceConversationModel.fromJson(
          _row(
            generation: vector,
            withGenerationKey: true,
            latest: _latest(seq: 4),
          ),
        );
        expect(
          model.memberGenerationId,
          '0',
          reason: 'generation=$vector 应折叠 0（世代未知）',
        );
      }
      // 键整体缺席 = 旧服务端响应，同样折叠 0 且不阻断解析。
      final withoutKey = WorkspaceConversationModel.fromJson(
        _row(latest: _latest(seq: 4)),
      );
      expect(withoutKey.memberGenerationId, '0');
    });

    test('大十进制世代 ID 规范保留：int/string 同值同形，前导零规范化', () {
      final fromInt = WorkspaceConversationModel.fromJson(
        _row(generation: 120619900000000003, latest: _latest(seq: 4)),
      );
      final fromString = WorkspaceConversationModel.fromJson(
        _row(generation: '120619900000000003', latest: _latest(seq: 4)),
      );
      expect(fromInt.memberGenerationId, '120619900000000003');
      expect(fromString.memberGenerationId, '120619900000000003');
      // 规范化：'007' 是十进制 7 的非规范写法，折叠为规范十进制串。
      final canonical = WorkspaceConversationModel.fromJson(
        _row(generation: '007', latest: _latest(seq: 4)),
      );
      expect(canonical.memberGenerationId, '7');
    });

    test('退出再加入：新旧世代 descriptor 可区分；旧快照字段保留不覆写', () {
      // 加入期（当前世代 7，start_seq=3，水位 4）。
      final joined = WorkspaceConversationModel.fromJson(
        _row(generation: '7', startSeq: 3, latest: _latest(seq: 4)),
      );
      // 退出再加入后（服务端换绑新世代 9，新 start_seq=100，水位 101）。
      final rejoined = WorkspaceConversationModel.fromJson(
        _row(generation: '9', startSeq: 100, latest: _latest(seq: 101)),
      );
      expect(joined.memberGenerationId, '7');
      expect(rejoined.memberGenerationId, '9');
      expect(joined.memberGenerationId, isNot(rejoined.memberGenerationId));
      // 旧快照本身的数据保留（不就地覆写/清空）……
      expect(joined.memberStartSeq, 3);
      expect(joined.unreadCount, 0);
      // ……但身份已是旧世代，偏好/水位动作不得把它当当前资格使用。
      expect(joined.memberGenerationId, isNot('0'));
      expect(rejoined.memberStartSeq, 100);
    });

    test('世代未知（0）不阻断内容投影字段解析', () {
      final model = WorkspaceConversationModel.fromJson(
        _row(latest: _latest(seq: 4), unread: 5),
      );
      expect(model.memberGenerationId, '0');
      expect(model.unreadCount, 5);
      expect(model.memberStartSeq, 3);
      expect(model.previewText, isNotEmpty);
    });
  });

  group('J28.c：水位与内容回填边界（fail-closed 解析）', () {
    test('旧世代水位低于新世代 member_start_seq 不得回填（FormatException）', () {
      // 重入后 start_seq=100：旧世代消息 conv_seq=4 不是新世代合法边界。
      expect(
        () => WorkspaceConversationModel.fromJson(
          _row(generation: '9', startSeq: 100, latest: _latest(seq: 4)),
        ),
        throwsFormatException,
        reason: '旧世代水位不得作为新世代内容回填边界',
      );
    });

    test('新世代水位 seq == start 合法；seq > start 合法', () {
      final atStart = WorkspaceConversationModel.fromJson(
        _row(generation: '9', startSeq: 100, latest: _latest(seq: 100)),
      );
      expect(atStart.memberStartSeq, 100);
      final afterStart = WorkspaceConversationModel.fromJson(
        _row(generation: '9', startSeq: 100, latest: _latest(seq: 101)),
      );
      expect(afterStart.memberStartSeq, 100);
    });

    test('member_start_seq <1 或非法拒绝；unread 负数/超 int32 拒绝', () {
      expect(
        () => WorkspaceConversationModel.fromJson(
          _row(startSeq: 0, latest: _latest(seq: 4)),
        ),
        throwsFormatException,
      );
      expect(
        () => WorkspaceConversationModel.fromJson(
          _row(startSeq: -3, latest: _latest(seq: 4)),
        ),
        throwsFormatException,
      );
      expect(
        () => WorkspaceConversationModel.fromJson(
          _row(latest: _latest(seq: 4), unread: -1),
        ),
        throwsFormatException,
      );
      expect(
        () => WorkspaceConversationModel.fromJson(
          _row(latest: _latest(seq: 4), unread: 2147483648),
        ),
        throwsFormatException,
      );
    });

    test('latest_message 键缺席 = 非完整快照拒绝；键存在且 null = 无预览合法', () {
      // 不含键：快照不完整（合同要求显式字段），拒绝。
      expect(
        () => WorkspaceConversationModel.fromJson(_row(withLatestKey: false)),
        throwsFormatException,
      );
      // 显式 null：服务端声明无最新消息，合法（仅成员资格行）。
      final noPreview = WorkspaceConversationModel.fromJson(
        _row(generation: '9', latest: null),
      );
      expect(noPreview.latest, isNull);
      expect(noPreview.previewText, isEmpty);
    });

    test('opaque msg_id 合同：非字符串/空串拒绝（ID 保真同 J27.d 口径）', () {
      expect(
        () => WorkspaceConversationModel.fromJson(
          _row(latest: _latest(seq: 4, msgId: '')),
        ),
        throwsFormatException,
      );
      expect(
        () => WorkspaceConversationModel.fromJson(
          _row(latest: {..._latest(seq: 4), 'msg_id': 123}),
        ),
        throwsFormatException,
      );
    });
  });
}
