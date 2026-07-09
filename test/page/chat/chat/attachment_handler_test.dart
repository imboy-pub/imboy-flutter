/// ChatAttachmentHandler 消息构建单元测试
///
/// 测试目标（用 currentUserOverride 脱离 UserRepoLocal/StorageService 单例，
/// 用 capturing onMessageCreated 收集生成的 Message 做断言）：
/// 1. handleVideoUpload / handleSelectedVideoUpload：source 存 object_key（不拼 &width、
///    非完整 URL），thumb 进 metadata，duration_ms 正确，回调一次。
/// 2. handleImageUploadPresign（mock AssetEntity）：source 存 object_key，md5/尺寸正确。
/// 3. 阅后即焚元数据注入。
///
/// 跳过（依赖文件 IO + 静态 AttachmentApi，建议设备端 integration_test 覆盖）：
/// uploadFile、handleVoiceSelection。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';

class _MockAssetEntity extends Mock implements AssetEntity {}

void main() {
  const String peerId = 'peer-1';

  // capturing 回调收集生成的 Message
  late List<Message> captured;

  ChatAttachmentHandler buildHandler({
    bool burnEnabled = false,
    int burnAfterMs = 0,
  }) {
    return ChatAttachmentHandler(
      peerId: peerId,
      conversationUk3: 'uk3-xxx',
      burnEnabled: burnEnabled,
      burnAfterMs: burnAfterMs,
      currentUserOverride: const User(id: 'u-self', name: 'Self'),
      onMessageCreated: (Message m) async {
        captured.add(m);
        return true;
      },
    );
  }

  EntityImage buildThumb() => EntityImage(
    fileHash256: 'thumb-md5',
    name: 't.jpg',
    uri: 'u1/file_1_a/t.jpg',
    size: 100,
    width: 80,
    height: 60,
  );

  EntityVideo buildVideo() => EntityVideo(
    fileHash256: 'video-md5',
    name: 'v.mp4',
    uri: 'u1/file_2_b/v.mp4',
    size: 2048,
    width: 640,
    height: 480,
    duration: 12.0,
  );

  setUp(() {
    captured = <Message>[];
  });

  group('handleVideoUpload', () {
    test(
      'source 存 object_key（非 URL、不拼 &width），thumb/md5/duration 进 metadata',
      () async {
        final EntityImage thumb = buildThumb();
        final EntityVideo video = buildVideo();
        await buildHandler().handleVideoUpload(<String, dynamic>{
          'thumb': thumb,
          'video': video,
        });

        expect(captured.length, 1);
        final Message msg = captured.single;
        expect(msg, isA<VideoMessage>());
        final VideoMessage vm = msg as VideoMessage;

        // source == object_key（无 http 前缀、无 &width 拼接）
        expect(vm.source, 'u1/file_2_b/v.mp4');
        expect(vm.source.contains('http'), isFalse);
        expect(vm.source.contains('&width'), isFalse);

        expect(vm.name, 'v.mp4');
        expect(vm.size, 2048);
        expect(vm.width, 640.0);
        expect(vm.height, 480.0);

        final Map<String, dynamic>? md = vm.metadata;
        expect(md?['peer_id'], peerId);
        expect(md?['file_hash256'], 'video-md5');
        expect(md?['thumb'], thumb.toJson());
        expect(md?['duration_ms'], (12.0 * 1000).round());
      },
    );

    test('无 burn 时 metadata 不含 burn 字段', () async {
      await buildHandler().handleVideoUpload(<String, dynamic>{
        'thumb': buildThumb(),
        'video': buildVideo(),
      });
      final Map<String, dynamic>? md =
          (captured.single as VideoMessage).metadata;
      expect(md?.containsKey('burn'), isFalse);
      expect(md?.containsKey('burn_after_ms'), isFalse);
    });

    test('burnEnabled 时注入 burn 元数据', () async {
      await buildHandler(
        burnEnabled: true,
        burnAfterMs: 5000,
      ).handleVideoUpload(<String, dynamic>{
        'thumb': buildThumb(),
        'video': buildVideo(),
      });
      final Map<String, dynamic>? md =
          (captured.single as VideoMessage).metadata;
      expect(md?['burn'], true);
      expect(md?['burn_after_ms'], 5000);
    });
  });

  group('handleSelectedVideoUpload', () {
    test('与 handleVideoUpload 一致：source 存 object_key，回调一次', () async {
      final EntityVideo video = buildVideo();
      await buildHandler().handleSelectedVideoUpload(<String, dynamic>{
        'thumb': buildThumb(),
        'video': video,
      });
      expect(captured.length, 1);
      final VideoMessage vm = captured.single as VideoMessage;
      expect(vm.source, video.uri);
      expect(vm.source.contains('http'), isFalse);
      expect(vm.metadata?['file_hash256'], 'video-md5');
    });
  });

  group('handleImageUploadPresign（mock AssetEntity）', () {
    test('source 存 object_key（不拼 &width），尺寸/md5 正确，回调一次', () async {
      final _MockAssetEntity entity = _MockAssetEntity();
      when(() => entity.width).thenReturn(800);
      when(() => entity.height).thenReturn(600);
      when(() => entity.titleAsync).thenAnswer((_) async => 'photo.jpg');

      final Map<String, dynamic> meta = <String, dynamic>{
        'object_key': 'u1/file_3_c/p.jpg',
        'size': 4096,
        'file_hash256': 'image-md5',
        'width': 800,
        'height': 600,
      };
      await buildHandler().handleImageUploadPresign(meta, entity);

      expect(captured.length, 1);
      final Message msg = captured.single;
      expect(msg, isA<ImageMessage>());
      final ImageMessage im = msg as ImageMessage;

      expect(im.source, 'u1/file_3_c/p.jpg');
      expect(im.source.contains('http'), isFalse);
      expect(im.source.contains('&width'), isFalse);
      expect(im.size, 4096);
      expect(im.width, 800.0);
      expect(im.height, 600.0);
      expect(im.text, 'photo.jpg');
      expect(im.metadata?['peer_id'], peerId);
      expect(im.metadata?['file_hash256'], 'image-md5');
    });
  });
}
