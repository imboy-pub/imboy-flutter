/// channel_publish_rules 纯函数契约测试（CP-1 ~ CP-2）
///
/// 覆盖发布栏多图聚合规划：
/// - CP-1 planChannelMediaPublish — ≥2 张图聚合为单条 imageText、单图/视频/文件
///   逐条、混选时图片组插回首张图片位置、失败重试子集再规划；
/// - CP-2 imageTextItemOf — payload → `{uri, w, h}` 元素形态。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_publish_rules.dart';
import 'package:imboy/service/message_type_constants.dart';

ChannelMediaUpload _img(String uri) => (
  msgType: ChannelMessageType.image,
  content: '$uri.png',
  payload: {'name': 'n', 'size': 1, 'uri': uri, 'w': 100, 'h': 80},
);

ChannelMediaUpload _video(String uri) => (
  msgType: ChannelMessageType.video,
  content: 'v.mp4',
  payload: {'uri': uri},
);

void main() {
  group('CP-1 planChannelMediaPublish', () {
    test('空输入 → 无作业', () {
      expect(planChannelMediaPublish(const {}), isEmpty);
    });

    test('≥2 张图片聚合为单条 imageText：images 按选择顺序、content 用占位符', () {
      final jobs = planChannelMediaPublish({
        0: _img('img/a'),
        1: _img('img/b'),
        2: _img('img/c'),
      });
      expect(jobs, hasLength(1));
      final job = jobs.single;
      expect(job.msgType, ChannelMessageType.imageText);
      expect(job.content, '[media]');
      expect(job.payload['media_only'], isTrue);
      expect(job.indices, [0, 1, 2]);
      final images = job.payload['images'] as List;
      expect(images, hasLength(3));
      expect(images[0]['uri'], 'img/a');
      expect(images[1]['uri'], 'img/b');
      expect(images[2]['uri'], 'img/c');
      expect(images[0]['w'], 100);
      expect(images[0]['h'], 80);
    });

    test('单张图片不聚合，保持 image 类型原样发布', () {
      final jobs = planChannelMediaPublish({5: _img('img/a')});
      expect(jobs, hasLength(1));
      expect(jobs.single.msgType, ChannelMessageType.image);
      expect(jobs.single.content, 'img/a.png');
      expect(jobs.single.indices, [5]);
      expect(jobs.single.payload.containsKey('images'), isFalse);
    });

    test('图文混选：视频独立成条，图片组插回首张图片位置', () {
      final jobs = planChannelMediaPublish({
        0: _video('vid/v'),
        1: _img('img/a'),
        2: _img('img/b'),
      });
      expect(jobs, hasLength(2));
      // 首张图片在规划序列的位置 1（视频在前），聚合组插回该位置
      expect(jobs[0].indices, [0]);
      expect(jobs[0].msgType, ChannelMessageType.video);
      expect(jobs[1].msgType, ChannelMessageType.imageText);
      expect(jobs[1].indices, [1, 2]);
    });

    test('pending 键乱序传入也按选择顺序聚合', () {
      final jobs = planChannelMediaPublish({
        2: _img('img/c'),
        0: _img('img/a'),
        1: _img('img/b'),
      });
      final images = jobs.single.payload['images'] as List;
      expect([for (final e in images) e['uri']], ['img/a', 'img/b', 'img/c']);
    });

    test('失败重试子集：剩余 ≥2 张仍聚合，仅 1 张退化为单图', () {
      final retried = planChannelMediaPublish({
        1: _img('img/b'),
        2: _img('img/c'),
      });
      expect(retried.single.msgType, ChannelMessageType.imageText);
      expect(retried.single.indices, [1, 2]);

      final lastOne = planChannelMediaPublish({2: _img('img/c')});
      expect(lastOne.single.msgType, ChannelMessageType.image);
    });
  });

  group('CP-2 imageTextItemOf', () {
    test('保留 uri 与正宽高，name/size 等其余字段不带入', () {
      expect(imageTextItemOf({'uri': 'u', 'w': 3, 'h': 4, 'name': 'n'}), {
        'uri': 'u',
        'w': 3,
        'h': 4,
      });
    });

    test('宽高缺失或非正数时省略（渲染只强依赖 uri）', () {
      expect(imageTextItemOf({'uri': 'u'}), {'uri': 'u'});
      expect(imageTextItemOf({'uri': 'u', 'w': 0, 'h': 0}), {'uri': 'u'});
    });
  });

  group('channelMediaContent', () {
    test('文件名为空/空白时用占位符，否则原样', () {
      expect(channelMediaContent(''), '[media]');
      expect(channelMediaContent('  '), '[media]');
      expect(channelMediaContent('a.png'), 'a.png');
    });
  });
}
