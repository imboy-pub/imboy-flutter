/// E2EE-061 Slice 6（下半）—— 把「这个对象怎么开封」送到下载处
///
/// ## 为什么是注册表，不是把 descriptor 一路传参
///
/// 下载漏斗 `IMBoyCacheManager.getSingleFile(url)` **只收一个 URL**，
/// 它上面还压着 `IMBoyCachedImageProvider`（其身份/相等性就是 url）、
/// 各 message builder、图库、markdown、频道 …… 共 9 个调用点。
/// 把 descriptor 一路传下去要动这 9 个调用点与沿途 widget 的构造参数，
/// 而其中多数（头像、频道封面、markdown 图）**永远不会**是加密附件。
///
/// 取而代之：消息在**唯一**的转换入口 `MessageModel.toTypeMessage()` 被解密时，
/// 顺手把「object_key → 开封所需材料」登记进来；下载漏斗按 object_key 查。
/// 一个登记点、一个查询点，替代九处传参。
///
/// ## ⚠️ 已知代价（必须记住）
///
/// **登记表落在内存，冷启动即空。** 若某个密文对象在其消息**尚未**经
/// `toTypeMessage()` 时就被下载，这里查不到 spec，字节会被**当明文交给渲染器**
/// —— 结果是坏图，**不是**泄漏（密文本来就不可读）。
/// 持久化登记属 Slice 8（临时明文与生命周期）一并处理。
///
/// ## 安全性
///
/// 表被「投毒」（另一条消息声称同一个 object_key 并给出自己的 descriptor）
/// 只会让开封失败（AAD / tag 对不上）——**拒绝渲染，不会泄露内容**。
library;

import 'dart:collection';
import 'dart:typed_data';

import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';

/// 开封一个对象所需的全部材料。
class AttachmentOpenSpec {
  final AttachmentDescriptor descriptor;
  final Uint8List bindingHash;
  const AttachmentOpenSpec(this.descriptor, this.bindingHash);
}

class AttachmentOpenRegistry {
  /// 表容量上限。
  // ponytail: 定容 FIFO 而不是 LRU/带过期——它只是把"刚解密的消息"接力给
  // "马上要下载的图"，命中窗口以秒计。上限只为挡住长会话里的无界增长。
  static const int maxEntries = 512;

  static final LinkedHashMap<String, AttachmentOpenSpec> _specs =
      LinkedHashMap<String, AttachmentOpenSpec>();

  /// 从一条**已解密**的消息登记（无 descriptor 时静默跳过）。
  ///
  /// 返回是否登记成功。descriptor 坏掉时 [AttachmentOpener.descriptorFrom]
  /// 会抛异常——这里**吞掉并返回 false**：消息转换不该因为一个坏附件整条失败，
  /// 而查不到 spec 的后果只是那张图打不开（fail-closed 的正确方向）。
  static bool registerFromMessage({
    required Object? payload,
    required String messageId,
    required String chatType,
    required String fromUid,
    required String toUid,
  }) {
    try {
      final descriptor = AttachmentOpener.descriptorFrom(payload);
      if (descriptor == null) return false;
      final binding = AttachmentOpener.bindingFor(
        messageId: messageId,
        chatType: chatType,
        fromUid: fromUid,
        toUid: toUid,
      );
      _put(descriptor.objectKey, AttachmentOpenSpec(descriptor, binding));
      final thumb = descriptor.thumb;
      if (thumb != null) {
        _put(thumb.objectKey, AttachmentOpenSpec(thumb, binding));
      }
      return true;
    } on AttachmentOpenException {
      return false;
    }
  }

  static void _put(String objectKey, AttachmentOpenSpec spec) {
    if (objectKey.isEmpty) return;
    _specs.remove(objectKey);
    _specs[objectKey] = spec;
    while (_specs.length > maxEntries) {
      _specs.remove(_specs.keys.first);
    }
  }

  static AttachmentOpenSpec? lookup(String objectKey) => _specs[objectKey];

  /// 下载漏斗调这个：登记过 ⇒ 开封（**全部完整性校验通过**才返回明文）；
  /// 没登记过 ⇒ 原样返回（今天的明文对象走这条路）。
  ///
  /// 开封失败抛 [AttachmentOpenException]：调用方**不得**重试下载
  /// （重下同一个对象不会变好），也**不得**把密文写进缓存。
  static Uint8List materialize(String objectKey, Uint8List bytes) {
    final spec = lookup(objectKey);
    if (spec == null) return bytes;
    try {
      return AttachmentEncryptor.open(
        ciphertext: bytes,
        descriptor: spec.descriptor,
        bindingHash: spec.bindingHash,
      );
    } on AttachmentSealException catch (e) {
      throw AttachmentOpenException(e.message);
    }
  }

  /// 仅测试用：清表，避免用例间串味。
  static void resetForTest() => _specs.clear();
}
