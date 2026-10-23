/// channel_publish_bar 纯决策函数
///
/// 从 channel_publish_bar.dart 提取的零依赖纯函数，便于单元测试
/// （多图聚合规划不依赖 widget/网络）。
library;

import 'package:imboy/service/message_type_constants.dart';

/// 单个媒体上传结果：待发布消息的三要素。
typedef ChannelMediaUpload = ({
  String msgType,
  String content,
  Map<String, dynamic> payload,
});

/// 一次发布作业：覆盖的上传项下标（用于回填发布成功/失败）+ 消息三要素。
typedef ChannelPublishJob = ({
  List<int> indices,
  String msgType,
  String content,
  Map<String, dynamic> payload,
});

/// CP-1 把已上传完成、尚未发布的媒体项规划为发布作业。
///
/// - ≥2 张图片聚合为**单条** imageText：一帖多图（与「撰写图文」页一致），
///   payload.images 元素 `{uri, w, h}` 见 [imageTextItemOf]，content 用
///   [ChannelMessageType.mediaPlaceholder] 过后端的空 content 校验；
///   作业插在首张图片原来的位置，尽量保持选择顺序；
/// - 单张图片保持 image 类型原样发布（不改变既有单图行为）；
/// - 视频/文件各自一条，互不影响。
///
/// 每次调用只看传入的 pending 子集：部分上传失败后，重试成功的图片按
/// 本次剩余数量再次规划（≥2 张继续聚合，1 张退化为单图）。
List<ChannelPublishJob> planChannelMediaPublish(
  Map<int, ChannelMediaUpload> pending,
) {
  final jobs = <ChannelPublishJob>[];
  final imageIndices = <int>[];
  var groupAt = -1;
  for (final i in pending.keys.toList()..sort()) {
    final upload = pending[i]!;
    if (upload.msgType == ChannelMessageType.image) {
      if (groupAt < 0) groupAt = jobs.length;
      imageIndices.add(i);
      continue;
    }
    jobs.add((
      indices: [i],
      msgType: upload.msgType,
      content: upload.content,
      payload: upload.payload,
    ));
  }
  if (imageIndices.isEmpty) return jobs;
  final first = pending[imageIndices.first]!;
  final single = imageIndices.length == 1;
  jobs.insert(
    groupAt,
    single
        ? (
            indices: imageIndices,
            msgType: first.msgType,
            content: first.content,
            payload: first.payload,
          )
        : (
            indices: imageIndices,
            msgType: ChannelMessageType.imageText,
            content: ChannelMessageType.mediaPlaceholder,
            payload: {
              'media_only': true,
              'images': [
                for (final i in imageIndices)
                  imageTextItemOf(pending[i]!.payload),
              ],
            },
          ),
  );
  return jobs;
}

/// CP-2 单图 payload → imageText.images 元素：只保留 uri 与正宽高，
/// 与 channel_compose_page 的 `{uri, w, h}` 形态对齐（渲染只强依赖 uri）。
Map<String, dynamic> imageTextItemOf(Map<String, dynamic> payload) => {
  'uri': payload['uri'],
  if (payload['w'] is int && (payload['w'] as int) > 0) 'w': payload['w'],
  if (payload['h'] is int && (payload['h'] as int) > 0) 'h': payload['h'],
};

/// 媒体消息 content：文件名为空时用占位符（后端拒收空 content）。
String channelMediaContent(String fileName) =>
    fileName.trim().isEmpty ? ChannelMessageType.mediaPlaceholder : fileName;
