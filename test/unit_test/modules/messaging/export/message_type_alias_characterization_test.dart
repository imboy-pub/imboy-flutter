/// W5-G3-4 特征化测试：锁定三处别称口径的**现状映射**——
/// ① 导出准入 `normalizeChatExportMsgType`、② `MessageTypeNormalizer`
/// （aliasOf/normalize/renderType）、③ `messagePreviewText`。
///
/// 别名表收口到共享源（service/message_type_alias.dart）前后，
/// 下列断言必须逐一不变（重构安全网；改口径须先改这里并显式评审）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_admission.dart';
import 'package:imboy/service/message_preview_text.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/message_type_normalizer.dart';

void main() {
  setUp(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });

  group('① 导出准入 normalizeChatExportMsgType 现状', () {
    test('audio → voice（含 trim）', () {
      expect(normalizeChatExportMsgType(MessageType.audio), MessageType.voice);
      expect(normalizeChatExportMsgType(' audio '), MessageType.voice);
    });

    test('channel_message → channel_card（历史频道分享别称）', () {
      expect(
        normalizeChatExportMsgType(MessageType.legacyChannelMessage),
        MessageType.channelCard,
      );
    });

    test('webrtc_audio / webrtc_video 下划线脏值 → 驼峰常量', () {
      expect(
        normalizeChatExportMsgType('webrtc_audio'),
        MessageType.webrtcAudio,
      );
      expect(
        normalizeChatExportMsgType('webrtc_video'),
        MessageType.webrtcVideo,
      );
    });

    test('非别称原样返回（仅 trim）', () {
      expect(normalizeChatExportMsgType(' text '), MessageType.text);
      expect(normalizeChatExportMsgType('redPacket'), MessageType.redPacket);
    });
  });

  group('② MessageTypeNormalizer 现状', () {
    test('aliasOf 只归一 legacy 频道别称（audio 原样透传）', () {
      expect(
        MessageTypeNormalizer.aliasOf(MessageType.legacyChannelMessage),
        MessageType.channelCard,
      );
      expect(
        MessageTypeNormalizer.aliasOf(MessageType.audio),
        MessageType.audio,
      );
    });

    test('normalize：audio 判有效后 canonical 成 voice', () {
      expect(
        MessageTypeNormalizer.normalize(
          msgType: MessageType.audio,
          payload: null,
        ),
        MessageType.voice,
      );
    });

    test('normalize：webrtc 下划线脏值不在 allTypes → unsupported', () {
      expect(
        MessageTypeNormalizer.normalize(msgType: 'webrtc_audio', payload: null),
        MessageType.unsupported,
      );
      expect(
        MessageTypeNormalizer.normalize(msgType: 'webrtc_video', payload: null),
        MessageType.unsupported,
      );
    });

    test('renderType：webrtc 下划线脏值判无效 → 空串（不渲染）', () {
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: 'webrtc_audio',
        ),
        '',
      );
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: 'webrtc_video',
        ),
        '',
      );
    });

    test('renderType：channel_message → channel_card、audio → voice', () {
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: MessageType.legacyChannelMessage,
        ),
        MessageType.channelCard,
      );
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: MessageType.audio,
        ),
        MessageType.voice,
      );
    });
  });

  group('③ messagePreviewText 现状', () {
    test('audio 与 voice 同文案；webrtc 下划线脏值与驼峰常量同文案', () {
      expect(
        messagePreviewText(MessageType.audio, null),
        messagePreviewText(MessageType.voice, null),
      );
      expect(
        messagePreviewText('webrtc_audio', null),
        messagePreviewText(MessageType.webrtcAudio, null),
      );
      expect(
        messagePreviewText('webrtc_video', null),
        messagePreviewText(MessageType.webrtcVideo, null),
      );
    });

    test('channel_message 走 default 兜底分支（不被归一成 channel_card）', () {
      // default 分支空载荷落通用 '[消息]'；channel_card 空载荷是名片标签
      // ——两者输出不同，锁死 preview 不消费频道别称的现状。
      expect(
        messagePreviewText(MessageType.legacyChannelMessage, null),
        '[消息]',
      );
      expect(
        messagePreviewText(MessageType.channelCard, null),
        '[${t.chat.card}]',
      );
    });

    test('preview 不做 trim：带空格的 audio 落 default 兜底', () {
      expect(messagePreviewText(' audio ', null), '[消息]');
    });
  });
}
