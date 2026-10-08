import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_type_constants.dart';
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
  }
}
