import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_preview_text.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// EO-20261009 回归：聊天页能渲染的消息类型（群作业/群投票/群日程/语音/
/// 红包/通话等）在会话列表/工作台预览里不得显示「[不支持的消息]」。
/// 类型→文案白名单收口在 messagePreviewText，本文件同时守 helper 与
/// Workspace/Conversation 两个消费方。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  group('messagePreviewText 类型白名单', () {
    test('群协作卡优先卡片标题并带类型标签', () {
      expect(
        messagePreviewText(MessageType.groupTask, {'title': '第三章练习'}),
        '[群作业]第三章练习',
      );
      expect(
        messagePreviewText(MessageType.groupVote, {'title': '午饭吃什么'}),
        '[群投票]午饭吃什么',
      );
      expect(
        messagePreviewText(MessageType.groupSchedule, {'title': '周五例会'}),
        '[群日程]周五例会',
      );
      // 无标题时不得出现「[不支持的消息]」，退化为类型标签
      expect(messagePreviewText(MessageType.groupTask, {}), '[群作业]');
    });

    test('媒体与业务卡类型给出类型标签', () {
      expect(messagePreviewText(MessageType.image, {}), '[图片]');
      expect(messagePreviewText(MessageType.imageMulti, {}), '[图片]');
      expect(messagePreviewText(MessageType.video, {}), '[视频]');
      expect(messagePreviewText(MessageType.voice, {}), '[语音消息]');
      // protobuf/收藏链路的 audio 别名与 voice 同文案
      expect(messagePreviewText(MessageType.audio, {}), '[语音消息]');
      expect(messagePreviewText(MessageType.file, {'name': 'a.pdf'}), 'a.pdf');
      expect(messagePreviewText(MessageType.file, {}), '[文件]');
      expect(
        messagePreviewText(MessageType.location, {'title': '北京市朝阳区'}),
        '[位置消息]北京市朝阳区',
      );
      expect(messagePreviewText(MessageType.location, {}), '[位置消息]');
      expect(messagePreviewText(MessageType.expression, {}), '[表情]');
      expect(messagePreviewText(MessageType.redPacket, {}), '[红包]');
      expect(
        messagePreviewText(MessageType.redPacket, {'greeting': '恭喜发财'}),
        '[红包]恭喜发财',
      );
      expect(messagePreviewText(MessageType.transfer, {}), '[转账]');
      expect(messagePreviewText(MessageType.visitCard, {}), '[个人名片]');
      expect(messagePreviewText(MessageType.channelCard, {}), '[名片]');
      expect(messagePreviewText(MessageType.webrtcAudio, {}), '[语音通话]');
      expect(messagePreviewText(MessageType.webrtcVideo, {}), '[视频通话]');
      // 历史脏数据：snake_case webrtc 命名同样给通话标签
      expect(messagePreviewText('webrtc_audio', {}), '[语音通话]');
      expect(messagePreviewText('webrtc_video', {}), '[视频通话]');
      expect(messagePreviewText('revoked', {}), '[消息已撤回]');
    });

    test('文本类优先正文，空正文走兜底链', () {
      expect(
        messagePreviewText(MessageType.text, {'text': ' hello '}),
        'hello',
      );
      // 历史文本消息正文可能在 content 字段
      expect(messagePreviewText(MessageType.text, {'content': '旧正文'}), '旧正文');
      expect(
        messagePreviewText(MessageType.quote, {
          'text': '回复',
          'quote_text': '被引用',
        }),
        '回复',
      );
      expect(
        messagePreviewText(MessageType.quote, {'quote_text': '被引用'}),
        '被引用',
      );
      expect(messagePreviewText(MessageType.text, {}), '[消息]');
    });

    test('未识别类型不显示「不支持」措辞，兜底可读字段', () {
      expect(messagePreviewText('brandNewType', {'title': '卡片'}), '卡片');
      expect(messagePreviewText('brandNewType', {}), '[消息]');
      expect(messagePreviewText(MessageType.custom, {'text': '内容'}), '内容');
    });

    test('MessageType.allTypes 全类型扫描：预览非空且无「不支持/未知」措辞', () {
      // 新增消息类型若漏补 messagePreviewText，本测试立刻失败——
      // 收口后预览的唯一事实源，类型清单与文案清单必须同步。
      for (final type in MessageType.allTypes) {
        final preview = messagePreviewText(type, const {});
        expect(preview, isNotEmpty, reason: '类型 $type 预览为空');
        expect(preview.contains('不支持'), isFalse, reason: '类型 $type: $preview');
        expect(preview.contains('未知消息'), isFalse, reason: '类型 $type: $preview');
      }
    });

    test('fallbackSubtitle 过滤旧类型标签，不叠加显示', () {
      // 旧落库 subtitle 可能是 '[位置]'/'[未知消息]' 这类标签，不得拼回
      expect(
        messagePreviewText(MessageType.location, {}, fallbackSubtitle: '[位置]'),
        '[位置消息]',
      );
      expect(
        messagePreviewText(MessageType.groupTask, {}, fallbackSubtitle: '[消息]'),
        '[群作业]',
      );
      // 非标签型 subtitle 作为可读兜底保留
      expect(
        messagePreviewText(MessageType.custom, {}, fallbackSubtitle: '旧摘要'),
        '旧摘要',
      );
    });
  });

  group('WorkspaceConversationModel.previewText', () {
    WorkspaceConversationModel rowOfType(
      String msgType,
      Map<String, dynamic> inner, {
      String? topType,
    }) {
      return WorkspaceConversationModel.fromJson({
        'id': 1,
        'title': 'Group',
        'member_start_seq': 3,
        'unread_count': 0,
        'latest_message': <String, dynamic>{
          'msg_id': 'm1',
          'conv_seq': 4,
          'msg_type': topType ?? msgType,
          'payload': <String, dynamic>{'payload': inner},
          'e2ee': null,
          'server_ts': '2026-10-01T00:00:00Z',
          'expire_at': null,
        },
      });
    }

    test('群作业/群投票/群日程不再显示「[不支持的消息]」', () {
      for (final entry in {
        MessageType.groupTask: '[群作业]第三章练习',
        MessageType.groupVote: '[群投票]午饭吃什么',
        MessageType.groupSchedule: '[群日程]周五例会',
      }.entries) {
        final preview = rowOfType(entry.key, {
          'title': entry.value.substring(entry.value.indexOf(']') + 1),
        }).previewText;
        expect(preview, entry.value, reason: 'msg_type=${entry.key}');
        expect(preview, isNot(t.chat.invalidMessageType));
      }
    });

    test('语音/红包/通话等此前漏白的类型给出可读摘要', () {
      expect(rowOfType(MessageType.voice, {}).previewText, '[语音消息]');
      expect(rowOfType(MessageType.redPacket, {}).previewText, '[红包]');
      expect(rowOfType(MessageType.webrtcAudio, {}).previewText, '[语音通话]');
      expect(rowOfType(MessageType.expression, {}).previewText, '[表情]');
      expect(rowOfType(MessageType.image, {}).previewText, '[图片]');
      expect(rowOfType(MessageType.video, {}).previewText, '[视频]');
      expect(
        rowOfType(MessageType.file, {'name': '报告.pdf'}).previewText,
        '报告.pdf',
      );
      // 未知类型不显示「[不支持的消息]」
      expect(rowOfType('brandNewType', {}).previewText, '[消息]');
    });

    test('文本/引用正文行为不变', () {
      expect(rowOfType(MessageType.text, {'text': 'hi'}).previewText, 'hi');
      expect(rowOfType(MessageType.quote, {'text': '回复'}).previewText, '回复');
    });
  });

  group('ConversationModel.content 收敛后的兜底', () {
    ConversationModel modelOfType(
      String msgType,
      Map<String, dynamic>? payload, {
      String subtitle = '',
    }) {
      return ConversationModel.fromJson({
        'type': 'C2G',
        'peer_id': 123,
        'msg_type': msgType,
        'subtitle': subtitle,
        'payload': ?payload,
      });
    }

    test('custom 无 subtitle 不再返回「[]」', () {
      expect(modelOfType(MessageType.custom, null).content, '[消息]');
      expect(modelOfType(MessageType.custom, {'text': '内容'}).content, '内容');
      expect(
        modelOfType(MessageType.custom, null, subtitle: '库内摘要').content,
        '库内摘要',
      );
    });

    test('location 标题优先，不再误用群日程「地点」键做标签', () {
      expect(
        modelOfType(MessageType.location, {'title': '北京市朝阳区'}).content,
        '[位置消息]北京市朝阳区',
      );
      expect(modelOfType(MessageType.location, null).content, '[位置消息]');
    });

    test('expression/textStream/imageMulti/channelCard 不再落「[未知消息]」', () {
      expect(modelOfType(MessageType.expression, {'text': '👏'}).content, '👏');
      expect(modelOfType(MessageType.textStream, {'text': '流式'}).content, '流式');
      expect(modelOfType(MessageType.imageMulti, {}).content, '[图片]');
      expect(modelOfType(MessageType.channelCard, {}).content, '[名片]');
    });

    test('红包/转账/名片/通话给出类型标签', () {
      expect(modelOfType(MessageType.redPacket, null).content, '[红包]');
      expect(modelOfType(MessageType.transfer, null).content, '[转账]');
      expect(modelOfType(MessageType.visitCard, null).content, '[个人名片]');
      expect(modelOfType(MessageType.voice, null).content, '[语音消息]');
      expect(modelOfType(MessageType.video, null).content, '[视频]');
    });

    test('未知类型兜底「[消息]」而非「[未知消息]」', () {
      expect(modelOfType('brandNewType', null).content, '[消息]');
    });

    test('text/quote/empty 行为不变', () {
      expect(modelOfType(MessageType.text, null, subtitle: '正文').content, '正文');
      expect(
        modelOfType(MessageType.quote, null, subtitle: '引用').content,
        '引用',
      );
      expect(modelOfType('empty', null).content, '');
    });
  });
}
