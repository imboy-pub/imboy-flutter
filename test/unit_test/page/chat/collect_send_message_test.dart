import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/user_collect_model.dart';

/// 收藏发送（sendCollectMessage）payload 构造契约测试。
///
/// 钉住真机实测到的缺陷（2026-10-08，macOS 收藏的位置消息转发到群）：
///   1. 历史收藏缺顶层 msg_type → MessageModel.fromJson 命中
///      「无效消息类型」占位分支，把「[不支持的消息]」当正文发出。
///   2. 收藏 payload 里的源会话 peer_id / conversation_uk3 残留，
///      getMsgFromTMsg 以 metadata['peer_id'] 为 toId → 消息归属错乱。
///   3. 仍未解密的加密收藏（info 带 e2ee）不能把密文当内容发出。
UserCollectModel _collect(
  Map<String, dynamic> info, {
  int kind = 6,
  String kindId = 'collect-1',
}) {
  return UserCollectModel(
    userId: 50,
    kind: kind,
    kindId: kindId,
    source: '',
    remark: '',
    tag: '',
    updatedAt: 0,
    createdAt: 0,
    info: info,
  );
}

void main() {
  group('ChatAttachmentHandler.collectPayload', () {
    test('信封形：payload 为 map 原样返回', () {
      final payload = ChatAttachmentHandler.collectPayload(
        _collect({
          'payload': {'msg_type': 'location', 'title': '海运中心'},
        }),
      );
      expect(payload['title'], '海运中心');
      expect(payload['msg_type'], 'location');
    });

    test('信封形：payload 为 JSON 字符串 → 解码成 map', () {
      final payload = ChatAttachmentHandler.collectPayload(
        _collect({'payload': '{"msg_type":"text","text":"hi"}'}, kind: 1),
      );
      expect(payload['text'], 'hi');
    });

    test('解密形：内容平铺在 info 顶层 → 剔除信封列后提取', () {
      final payload = ChatAttachmentHandler.collectPayload(
        _collect({
          'msg_type': 'location',
          'from_id': 100,
          'to_id': 200,
          'e2ee': {'nonce': 'x'},
          'title': '海运中心',
          'address': '临海大道59号',
          'latitude': '22.532',
          'longitude': '113.942',
        }),
      );
      expect(payload['title'], '海运中心');
      expect(payload['address'], '临海大道59号');
      expect(payload['latitude'], '22.532');
      // 信封列不得混进内容 payload
      expect(payload.containsKey('from_id'), isFalse);
      expect(payload.containsKey('to_id'), isFalse);
      expect(payload.containsKey('e2ee'), isFalse);
    });

    test('密文残留：payload 非 JSON 且 info 无内容 → 空 map', () {
      final payload = ChatAttachmentHandler.collectPayload(
        _collect({'payload': 'b64(nonce).b64(ciphertext)', 'msg_type': 'e2ee'}),
      );
      expect(payload, isEmpty);
    });

    test('info 顶层 null 值不拷贝', () {
      final payload = ChatAttachmentHandler.collectPayload(
        _collect({'payload': <String, dynamic>{}, 'text': null}),
      );
      expect(payload, isEmpty);
    });
  });

  group('ChatAttachmentHandler.collectMsgType', () {
    test('info 顶层 msg_type 优先', () {
      expect(
        ChatAttachmentHandler.collectMsgType(
          _collect({'msg_type': 'location'}),
          const {},
        ),
        MessageType.location,
      );
    });

    test('info 缺失 → payload 内 msg_type 兜底', () {
      expect(
        ChatAttachmentHandler.collectMsgType(
          _collect(const {}, kind: 1),
          const {'msg_type': 'image'},
        ),
        MessageType.image,
      );
    });

    test('两处都缺失 → 按 kind 推导（kind=6 → location）', () {
      expect(
        ChatAttachmentHandler.collectMsgType(_collect(const {}), const {}),
        MessageType.location,
      );
    });

    test('脏值 e2ee（旧加密收藏）→ 按 kind 推导', () {
      expect(
        ChatAttachmentHandler.collectMsgType(
          _collect({'msg_type': 'e2ee'}, kind: 2),
          const {},
        ),
        MessageType.image,
      );
    });

    test('脏值 unsupported → 按 kind 推导', () {
      expect(
        ChatAttachmentHandler.collectMsgType(
          _collect({'msg_type': 'unsupported'}, kind: 5),
          const {},
        ),
        MessageType.file,
      );
    });

    test('audio 别名归一成 voice（与 MessageTypeNormalizer 同口径）', () {
      expect(
        ChatAttachmentHandler.collectMsgType(
          _collect({'msg_type': 'audio'}, kind: 3),
          const {},
        ),
        MessageType.voice,
      );
    });

    test('kind 7 → visitCard；未知 kind → custom', () {
      expect(
        ChatAttachmentHandler.collectMsgType(
          _collect(const {}, kind: 7),
          const {},
        ),
        MessageType.visitCard,
      );
      expect(
        ChatAttachmentHandler.collectMsgType(
          _collect(const {}, kind: 0),
          const {},
        ),
        MessageType.custom,
      );
    });
  });

  group('ChatAttachmentHandler.collectOutboundPayload（回归钉住）', () {
    test('历史位置收藏：缺顶层 msg_type 也能还原 location 并绑定目标会话', () {
      final payload = ChatAttachmentHandler.collectOutboundPayload(
        _collect({
          'payload': {
            'msg_type': 'location',
            'peer_id': '104603643803863040',
            'conversation_uk3': 'C2G_50_104603643803863040',
            'title': '海运中心',
            'address': '临海大道59号',
            'latitude': '22.532',
            'longitude': '113.942',
            'thumb': 'u50/location/xxx.png',
            'size': 1024,
            'file_hash256': 'abc123',
          },
        }),
        targetPeerId: '777',
      );
      // 修复前：msg_type 缺失 → toTypeMessage 命中占位分支，
      // 发出的消息正文就是「[不支持的消息]」
      expect(payload['msg_type'], MessageType.location);
      expect(payload['peer_id'], '777', reason: '必须是目标会话 peer，不是收藏源 peer');
      expect(payload.containsKey('conversation_uk3'), isFalse);
      // 位置内容原样保留（LocationMessageBuilder 从 metadata 读这些键）
      expect(payload['title'], '海运中心');
      expect(payload['address'], '临海大道59号');
      expect(payload['thumb'], 'u50/location/xxx.png');
      expect(payload['file_hash256'], 'abc123');
    });

    test('解密形（加密收藏解密后内容平铺 info 顶层）同样可还原', () {
      final payload = ChatAttachmentHandler.collectOutboundPayload(
        _collect({
          'msg_type': 'location',
          'peer_id': '999',
          'title': '海运中心',
          'address': '临海大道59号',
          'latitude': '22.5',
          'longitude': '113.9',
          'thumb': 'u50/t.png',
        }),
        targetPeerId: '777',
      );
      expect(payload['msg_type'], MessageType.location);
      expect(payload['peer_id'], '777');
      expect(payload['title'], '海运中心');
    });

    test('文本收藏：text 平铺 info 顶层 → 进 payload', () {
      final payload = ChatAttachmentHandler.collectOutboundPayload(
        _collect({'text': 'hello'}, kind: 1),
        targetPeerId: '777',
      );
      expect(payload['msg_type'], MessageType.text);
      expect(payload['text'], 'hello');
    });

    test('历史视频收藏：嵌套 video map 内容提升到顶层（uri 不为空）', () {
      final payload = ChatAttachmentHandler.collectOutboundPayload(
        _collect({
          'payload': {
            'msg_type': 'video',
            'peer_id': '104603643803863040',
            'thumb': {'uri': 'u50/video/thumb.jpg', 'size': 1024},
            'video': {
              'uri': 'u50/video/main.mp4',
              'size': 5120000,
              'width': 1920,
              'height': 1080,
            },
          },
        }, kind: 4),
        targetPeerId: '777',
      );
      expect(payload['msg_type'], MessageType.video);
      // toTypeMessage 的 VideoMessage 分支只读顶层 uri，不提升就是坏视频
      expect(payload['uri'], 'u50/video/main.mp4');
      expect(payload['size'], 5120000);
      expect(payload['width'], 1920);
      expect(payload['height'], 1080);
      // 嵌套结构原样保留（缩略图读取方依赖 thumb map）
      expect(payload['thumb'], {'uri': 'u50/video/thumb.jpg', 'size': 1024});
    });

    test('仍未解密的加密收藏 → 拒发（fail-closed）', () {
      expect(
        () => ChatAttachmentHandler.collectOutboundPayload(
          _collect({
            'payload': 'b64(nonce).b64(ciphertext)',
            'msg_type': 'e2ee',
            'e2ee': {'nonce': 'x'},
          }),
          targetPeerId: '777',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('内容无法还原（空 payload）→ 抛异常而非生产空消息', () {
      expect(
        () => ChatAttachmentHandler.collectOutboundPayload(
          _collect({'payload': <String, dynamic>{}}, kindId: 'collect-9'),
          targetPeerId: '777',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
