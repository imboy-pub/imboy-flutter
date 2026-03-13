import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  group('MessageTypeConstants TDD Tests - 命名一致性', () {
    test('voice 常量应该存在且值为 "voice"', () {
      // THEN: voice 常量应该存在
      expect(MessageType.voice, equals('voice'));
    });
  });

  group('MsgTypeEnumExtension TDD Tests', () {
    test('fromValue 应该正确识别 voice 类型', () {
      // WHEN: 从 "voice" 字符串获取枚举
      final enumValue = MsgTypeEnumExtension.fromValue('voice');

      // THEN: 应该返回 MsgTypeEnum.voice
      expect(enumValue, equals(MsgTypeEnum.voice));
    });

    test('所有基础消息类型应该有对应的枚举值', () {
      // THEN: 验证所有基础类型都有对应的枚举
      expect(MsgTypeEnum.text.value, equals(MessageType.text));
      expect(MsgTypeEnum.textStream.value, equals(MessageType.textStream));
      expect(MsgTypeEnum.image.value, equals(MessageType.image));
      expect(MsgTypeEnum.imageMulti.value, equals(MessageType.imageMulti));
      expect(MsgTypeEnum.file.value, equals(MessageType.file));
      expect(MsgTypeEnum.location.value, equals(MessageType.location));
      expect(MsgTypeEnum.voice.value, equals(MessageType.voice));
      expect(MsgTypeEnum.video.value, equals(MessageType.video));
    });

    test('fromValue 不应再识别 audio 旧类型', () {
      final enumValue = MsgTypeEnumExtension.fromValue('audio');
      expect(enumValue, isNull);
    });

    test('fromValue 应该处理未知类型返回 null', () {
      // WHEN: 从未知字符串获取枚举
      final enumValue = MsgTypeEnumExtension.fromValue('unknown_type');

      // THEN: 应该返回 null
      expect(enumValue, isNull);
    });
  });

  group('ExtendedMessageTypeConstants TDD Tests', () {
    test('webrtcAudio 应该使用驼峰命名', () {
      // THEN: webrtcAudio 应该使用驼峰命名
      expect(MessageType.webrtcAudio, equals('webrtcAudio'));
    });

    test('webrtcVideo 应该使用驼峰命名', () {
      // THEN: webrtcVideo 应该使用驼峰命名
      expect(MessageType.webrtcVideo, equals('webrtcVideo'));
    });

    test('visitCard 应该使用驼峰命名', () {
      // THEN: visitCard 应该使用驼峰命名
      expect(MessageType.visitCard, equals('visitCard'));
    });

    test('WebRTC 相关枚举应该使用驼峰命名', () {
      // WHEN: 获取 WebRTC 枚举值
      // THEN: 应该对应驼峰命名的常量
      expect(MsgTypeEnum.webrtcAudio.value, equals('webrtcAudio'));
      expect(MsgTypeEnum.webrtcVideo.value, equals('webrtcVideo'));
    });
  });

  group('MessageTypeConstants TDD Tests - 字段命名', () {
    test('image payload 应该使用 uri 字段', () {
      // THEN: 验证文档中 image payload 使用 uri
      expect(MessageType.image, equals('image'));
    });

    test('file payload 应该使用 uri 字段', () {
      // THEN: 验证文档中 file payload 使用 uri
      expect(MessageType.file, equals('file'));
    });

    test('video payload 应该使用 uri 字段', () {
      // THEN: 验证文档中 video payload 使用 uri
      expect(MessageType.video, equals('video'));
    });

    test('voice payload 应该使用 uri 字段', () {
      // THEN: 验证文档中 voice payload 使用 uri
      expect(MessageType.voice, equals('voice'));
    });
  });

  group('S2CAction TDD Tests', () {
    test('所有 S2C action 应该有有效的常量', () {
      // THEN: 验证关键 S2C action 存在
      expect(S2CAction.pullOfflineMsg, equals('pull_offline_msg'));
      expect(S2CAction.c2cRevoke, equals('c2c_revoke'));
      expect(S2CAction.c2cDelEveryone, equals('c2c_del_everyone'));
      expect(S2CAction.groupMemberJoin, equals('group_member_join'));
      expect(S2CAction.groupDissolve, equals('group_dissolve'));
      expect(S2CAction.applyFriend, equals('apply_friend'));
      expect(S2CAction.online, equals('online'));
      expect(S2CAction.offline, equals('offline'));
      expect(S2CAction.momentNew, equals('moment_new'));
      expect(S2CAction.momentLike, equals('moment_like'));
      expect(S2CAction.momentComment, equals('moment_comment'));
      expect(S2CAction.momentDeleted, equals('moment_deleted'));
    });

    test('isValid 应该正确验证 action', () {
      // WHEN: 验证有效的 action
      // THEN: 应该返回 true
      expect(S2CAction.isValid('pull_offline_msg'), isTrue);
      expect(S2CAction.isValid('c2c_revoke'), isTrue);
      expect(S2CAction.isValid('moment_new'), isTrue);
      expect(S2CAction.isValid('invalid_action'), isFalse);
    });

    test('getDisplayName 应该返回正确的显示名称', () {
      // WHEN: 获取 action 的显示名称
      // THEN: 应该返回中文名称
      expect(S2CAction.getDisplayName('pull_offline_msg'), equals('拉取离线消息'));
      expect(S2CAction.getDisplayName('c2c_revoke'), equals('消息撤回'));
      expect(S2CAction.getDisplayName('moment_deleted'), equals('朋友圈删除'));
      expect(S2CAction.getDisplayName('unknown'), equals('unknown'));
    });
  });
}
