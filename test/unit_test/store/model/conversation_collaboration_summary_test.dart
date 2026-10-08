import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/group_collaboration_summary.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  for (final type in [
    MessageType.groupVote,
    MessageType.groupTask,
    MessageType.groupSchedule,
  ]) {
    test('$type 通知有类型标签，会话摘要只保存标题', () {
      final payload = {'title': '  团队协作  '};
      expect(groupCollaborationSummary(type, payload), '团队协作');
      expect(
        groupCollaborationSummary(type, payload, includeLabel: true),
        endsWith(']团队协作'),
      );
      expect(groupCollaborationSummary(type, {'title': '   '}), '');
    });
    for (final subtitle in ['', '团队协作']) {
      test('$type 会话摘要保留类型和标题：$subtitle', () {
        final model = ConversationModel.fromJson({
          'type': 'C2G',
          'peer_id': 123,
          'msg_type': type,
          'subtitle': subtitle,
        });
        final label = switch (type) {
          MessageType.groupVote => t.groupVote.title,
          MessageType.groupTask => t.groupTask.title,
          _ => t.groupSchedule.title,
        };
        expect(model.content, '[$label]$subtitle');
      });
    }
    test('$type 优先展示卡片标题而不是旧通用摘要', () {
      final model = ConversationModel.fromJson({
        'type': 'C2G',
        'peer_id': 123,
        'msg_type': type,
        'subtitle': '[消息]',
        'payload': {'title': ' 周五团队协作 '},
      });
      final label = switch (type) {
        MessageType.groupVote => t.groupVote.title,
        MessageType.groupTask => t.groupTask.title,
        _ => t.groupSchedule.title,
      };
      expect(model.content, '[$label]周五团队协作');
    });
  }
  test('非群协作消息保留原摘要处理路径', () {
    expect(
      groupCollaborationSummary(MessageType.text, {'title': '正文'}),
      isNull,
    );
  });
}
