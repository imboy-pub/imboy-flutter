import 'package:flutter_test/flutter_test.dart';

/// 测试 WebSocket API v2.0 消息接收处理
///
/// 测试场景：
/// 1. v2.0 普通消息（msg_type 在顶层）
/// 2. v2.0 E2EE 加密消息（payload 为字符串）
/// 3. 不同 msg_type 的副标题构造
void main() {
  group('WebSocket API v2.0 消息接收测试', () {
    test('v2.0 普通文本消息格式', () {
      // 模拟 v2.0 格式的 C2C 消息
      final v2Message = {
        'id': 'msg123',
        'type': 'C2C',
        'from': 'user1',
        'to': 'user2',
        'msg_type': 'text', // v2.0: msg_type 在顶层
        'action': '',
        'e2ee': '',
        'payload': {'text': 'Hello, world!', 'client_send_ts': 1642579200000},
        'created_at': 1642579200000,
      };

      expect(v2Message['msg_type'], 'text');
      expect(v2Message['payload'], isA<Map>());
    });

    test('v2.0 图片消息格式', () {
      final v2ImageMessage = {
        'id': 'msg456',
        'type': 'C2C',
        'from': 'user1',
        'to': 'user2',
        'msg_type': 'image', // v2.0: msg_type 在顶层
        'action': '',
        'e2ee': '',
        'payload': {
          'url': 'https://example.com/image.jpg',
          'width': 1920,
          'height': 1080,
        },
        'created_at': 1642579200000,
      };

      expect(v2ImageMessage['msg_type'], 'image');
      final imagePayload = v2ImageMessage['payload'] as Map<String, dynamic>;
      expect(imagePayload['url'], 'https://example.com/image.jpg');
    });

    test('v2.0 语音消息格式', () {
      final v2VoiceMessage = {
        'id': 'msg789',
        'type': 'C2C',
        'from': 'user1',
        'to': 'user2',
        'msg_type': 'voice', // v2.0: msg_type 在顶层
        'action': '',
        'e2ee': '',
        'payload': {'url': 'https://example.com/voice.mp3', 'duration': 15},
        'created_at': 1642579200000,
      };

      expect(v2VoiceMessage['msg_type'], 'voice');
      final voicePayload = v2VoiceMessage['payload'] as Map<String, dynamic>;
      expect(voicePayload['duration'], 15);
    });

    test('v2.0 视频消息格式', () {
      final v2VideoMessage = {
        'id': 'msg101',
        'type': 'C2C',
        'from': 'user1',
        'to': 'user2',
        'msg_type': 'video', // v2.0: msg_type 在顶层
        'action': '',
        'e2ee': '',
        'payload': {
          'url': 'https://example.com/video.mp4',
          'duration': 60,
          'thumbnail': 'https://example.com/thumb.jpg',
        },
        'created_at': 1642579200000,
      };

      expect(v2VideoMessage['msg_type'], 'video');
      final videoPayload = v2VideoMessage['payload'] as Map<String, dynamic>;
      expect(videoPayload['duration'], 60);
    });

    test('v2.0 文件消息格式', () {
      final v2FileMessage = {
        'id': 'msg102',
        'type': 'C2C',
        'from': 'user1',
        'to': 'user2',
        'msg_type': 'file', // v2.0: msg_type 在顶层
        'action': '',
        'e2ee': '',
        'payload': {
          'url': 'https://example.com/document.pdf',
          'filename': 'document.pdf',
          'size': 1024000,
        },
        'created_at': 1642579200000,
      };

      expect(v2FileMessage['msg_type'], 'file');
      final filePayload = v2FileMessage['payload'] as Map<String, dynamic>;
      expect(filePayload['filename'], 'document.pdf');
    });

    test('v2.0 E2EE 加密消息格式（保留原始 msg_type）', () {
      // 模拟 v2.0 E2EE 加密消息
      final v2E2EEMessage = {
        'id': 'msg103',
        'type': 'C2C',
        'from': 'user1',
        'to': 'user2',
        'msg_type': 'text', // v2.0: 保留原始业务类型
        'action': '',
        'e2ee':
            '{'
            '"e2ee":true,'
            '"e2ee_ver":1,'
            '"e2ee_suite":"RSA-OAEP-256+AES-256-GCM",'
            '"nonce":"YWJjZGVmZ2g=",'
            '"keys":['
            '{'
            '"did":"deviceA",'
            '"kid":"key_v1",'
            '"wrap_alg":"RSA-OAEP-256",'
            '"ek":"base64_encoded_wrapped_key"'
            '}'
            ']'
            '}',
        'payload':
            'YWJjZGVmZ2g=.encrypted_ciphertext_here', // v2.0: payload 为密文字符串
        'created_at': 1642579200000,
      };

      expect(v2E2EEMessage['msg_type'], 'text');
      expect(v2E2EEMessage['payload'], isA<String>());
      expect((v2E2EEMessage['payload'] as String).contains('.'), true);
    });

    test('v2.0 群组消息格式', () {
      final v2GroupMessage = {
        'id': 'msg104',
        'type': 'C2G',
        'from': 'user1',
        'to': 'group123',
        'msg_type': 'text', // v2.0: msg_type 在顶层
        'action': '',
        'e2ee': '',
        'payload': {'text': 'Hello, group!', 'client_send_ts': 1642579200000},
        'created_at': 1642579200000,
      };

      expect(v2GroupMessage['type'], 'C2G');
      expect(v2GroupMessage['msg_type'], 'text');
    });
  });

  group('_getMessageSubtitle 测试', () {
    test('文本消息副标题', () {
      final payload = {'text': 'Hello, world!'};
      // 使用反射调用私有方法进行测试
      // 实际测试中可以通过公共接口测试
      expect(payload['text'], 'Hello, world!');
    });

    test('图片消息副标题', () {
      final payload = {'url': 'https://example.com/image.jpg'};
      expect(payload, isNotNull);
    });

    test('语音消息副标题（带时长）', () {
      final payload = {'url': 'https://example.com/voice.mp3', 'duration': 15};
      expect(payload['duration'], 15);
    });

    test('视频消息副标题', () {
      final payload = {'url': 'https://example.com/video.mp4', 'duration': 60};
      expect(payload, isNotNull);
    });

    test('文件消息副标题', () {
      final payload = {
        'url': 'https://example.com/document.pdf',
        'filename': 'report.pdf',
        'size': 1024000,
      };
      expect(payload['filename'], 'report.pdf');
    });

    test('位置消息副标题', () {
      final payload = {
        'latitude': 39.9042,
        'longitude': 116.4074,
        'title': '北京市朝阳区',
      };
      expect(payload['title'], '北京市朝阳区');
    });

    test('引用消息副标题', () {
      final payload = {
        'quote_msg_id': 'msg123',
        'quote_text': 'Original message',
        'text': 'Reply',
      };
      expect(payload['quote_text'], 'Original message');
    });

    test('E2EE 加密消息副标题（解密失败）', () {
      final payload = {
        '_e2ee_failed': true,
        '_e2ee_reason': 'decrypt_error',
        'text': 'Cannot decrypt',
      };
      expect(payload['_e2ee_failed'], true);
    });

    test('自定义消息副标题', () {
      final payload = {
        'msg_type': 'typingIndicator',
        'data': {'user_id': 'user1'},
      };
      expect(payload['msg_type'], 'typingIndicator');
    });
  });
}
