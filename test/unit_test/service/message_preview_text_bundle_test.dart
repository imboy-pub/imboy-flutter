import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_preview_text.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// W3-I / BND-04：chat_history_bundle 会话列表摘要
/// （`chat.bundlePreview(count)`，zh-CN/en-US 双语断言）。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
  });

  List<Map<String, dynamic>> entries(int n) =>
      List<Map<String, dynamic>>.generate(
        n,
        (i) => {
          'msg_type': 'text',
          'payload': {'text': '第${i + 1}条'},
        },
      );

  test('zh-CN：返回「[聊天记录] N 条」', () async {
    await LocaleSettings.setLocale(AppLocale.zhCn);

    expect(
      messagePreviewText(MessageType.chatHistoryBundle, {
        'entries': entries(3),
      }),
      '[聊天记录] 3 条',
    );
    expect(
      messagePreviewText(MessageType.chatHistoryBundle, {
        'title': '产品群',
        'entries': entries(50),
      }),
      '[聊天记录] 50 条',
    );
  });

  test('en-US：返回 "[Chat history] N messages"', () async {
    await LocaleSettings.setLocale(AppLocale.enUs);

    expect(
      messagePreviewText(MessageType.chatHistoryBundle, {
        'entries': entries(3),
      }),
      '[Chat history] 3 messages',
    );
  });

  test('entries 缺失/畸形按 0 条展示，不落入通用兜底', () async {
    await LocaleSettings.setLocale(AppLocale.zhCn);

    expect(messagePreviewText(MessageType.chatHistoryBundle, {}), '[聊天记录] 0 条');
    // entries 是字符串脏值同样按 0 条（不抛异常、不显示原始 JSON）
    expect(
      messagePreviewText(MessageType.chatHistoryBundle, {'entries': 'garbage'}),
      '[聊天记录] 0 条',
    );
  });
}
