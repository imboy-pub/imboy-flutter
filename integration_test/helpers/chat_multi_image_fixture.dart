// integration_test/helpers/chat_multi_image_fixture.dart
//
// W3-K 多选真机用例的真实图片 fixture（RUN_ID=chat-multi-20261111 / DEV-01）。
//
// 背景（DEV-01 pass1/pass2 双轮同签名失败 #2）：fixture.invalid 占位 uri 的
// image 消息在真机上由 IMBoyCachedImageProvider 渲染，下载失败重试 3 次后
// rethrow，Image widget 无 errorBuilder → FlutterError.reportError 进入
// test binding 的 _pendingExceptionDetails → 用例终局断言
// `_pendingExceptionDetails != null` 挂起至 10/12min 超时；且逐条转发的
// image 副本会在目标会话页复现同款破图。
//
// 修复：fixture 不再用占位 uri —— 在 setup 阶段经**生产附件管道**真实上传
// 一张小图（presign → PUT Garage → confirm，AttachmentApi.uploadViaPresign，
// 与聊天图片发送同源），以返回的 object_key 作为 ImageMessage.source /
// metadata['uri']。这样：
// - 渲染走真实授权链（object_key → viewUrl 签发 → 下载 → 解码），零
//   FlutterError；
// - 逐条转发走 PlainAttachmentForward.reupload（object_key 判定
//   needsReupload 为 true → 下载原字节 → 目标 scope 重上传），P1 前向链路
//   真实执行。
//
// 仅设备集成测试使用；本地 widget 冒烟共享的 chat_multi_fixtures.dart 保持
// 纯 Dart（无网络依赖）不受影响。

import 'dart:typed_data';

import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 真实图片 fixture（8×8 纯色 PNG，74 字节，可被 Flutter 解码）。
class ChatMultiImageFixture {
  ChatMultiImageFixture._();

  /// 最小合法 PNG 字节（8×8 纯色 RGB，IHDR+IDAT+IEND 完整结构）。
  static final Uint8List pngBytes = Uint8List.fromList(const <int>[
    137, 80, 78, 71, 13, 10, 26, 10, //
    0, 0, 0, 13, 73, 72, 68, 82, //
    0, 0, 0, 8, 0, 0, 0, 8, 8, 2, 0, 0, 0, 75, 109, 41, 220, //
    0, 0, 0, 17, 73, 68, 65, 84, //
    120, 156, 99, 144, 155, 240, 31, 43, 98, 24, 90, 18, 0, 175, 239, //
    107, 65, 65, 228, 114, 169, //
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]);

  /// 经生产附件管道上传一张 fixture 小图，返回 object_key（消息 uri 语义）。
  ///
  /// scope 与聊天发送同源：[ChatAttachmentHandler.deriveUploadScope]
  /// （C2C → `c2c:<minUid>:<maxUid>`，保证登录账号与对端都有读授权；
  /// [type] 为权威源，[conversationUk3] 仅作 type 缺失时的兜底）。
  /// 上传失败直接抛错 —— fixture 缺失就该让用例失败，不降级回占位 uri。
  ///
  /// ⚠️ 必须传 `process: false`（DEV-01 fix-pass1 r1 根因）：direct 上传管道
  /// 在 process=true 时构造 UploadProgressSession → AppLoading/EasyLoading
  /// 浮层，PUT 进度回调 showProgress、上传完成 dispose() await EasyLoading
  /// dismiss —— 其内部 AnimationController.reverse().orCancel 在
  /// LiveTestWidgetsFlutterBinding（integration_test）下测试体 await 期间
  /// 永不完成 → uploadPng 挂死（dev01-fix-pass1-chat_multi_select.log：
  /// finalize 200 后无输出，10min TimeoutException）。process=false 时管道
  /// 不构造 progress session，关键路径零 UI await，上传编排
  /// （register/declare/grant/PUT/finalize → object_key）完全不变。
  /// 外层再套 60s 超时兜底：残留挂起将以用例失败快速暴露，不再吃满 10min。
  static Future<String> uploadPng({
    required String peerId,
    required String type,
    String conversationUk3 = '',
  }) async {
    final objectKey = await ChatMultiImageFixture._upload(
      peerId: peerId,
      type: type,
      conversationUk3: conversationUk3,
    ).timeout(const Duration(seconds: 60));
    return objectKey;
  }

  static Future<String> _upload({
    required String peerId,
    required String type,
    required String conversationUk3,
  }) {
    final scope = ChatAttachmentHandler.deriveUploadScope(
      conversationUk3: conversationUk3,
      currentUid: UserRepoLocal.to.currentUid,
      peerId: peerId,
      type: type,
    );
    return AttachmentApi.uploadViaPresign(
      pngBytes,
      'w3k-fixture-${DateTime.now().millisecondsSinceEpoch}.png',
      'image/png',
      process: false,
      scope: scope.scope,
      scopeRef: scope.scopeRef,
    );
  }
}
