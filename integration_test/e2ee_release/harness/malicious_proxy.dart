/// C11 可控恶意服务器代理（冒烟层注入器）。
///
/// 对齐 attack-matrix.md §4.1 的注入点分类；冒烟层在帧进入设备收件箱前
/// 经由这些注入器改写，用于验证 harness 的 fail-closed 断言器可被真实触发。
/// 真实层的 MITM 插入方式（本地 proxy 配置点）见 attack-matrix.md §4.1：
/// App 以 dart-define 把 API/WS 端点指向本地可控代理，代理上游指向授权后端。
library;

import 'dart:convert';

import 'backend_transport.dart';

/// 注入点分类（attack-matrix.md §4.1）。
enum AttackInjection {
  /// W1：同一密文帧重复投递。
  replay,

  /// W1/W3：打乱多条密文投递顺序。
  reorder,

  /// W1：翻转密文字节（Olm 认证必须失败）。
  tamperCiphertext,

  /// W1：改写 protected_header（PFv3 hash 校验必须失败）。
  tamperHeader,

  /// W2：改写身份目录握手材料（错会话/错身份必须 fail-closed）。
  directorySwap,

  /// W3：洪泛垃圾帧（设备须拒绝且不崩溃）。
  flood,
}

/// 帧级注入器：全部返回新帧，不修改入参（不可变风格）。
abstract final class MaliciousProxy {
  /// replay：同一帧重复投递两次。
  static List<WireFrame> replay(WireFrame frame) => <WireFrame>[frame, frame];

  /// reorder：倒序返回（配合 ≥3 帧使用）。
  static List<WireFrame> reorder(Iterable<WireFrame> frames) =>
      frames.toList(growable: false).reversed.toList(growable: false);

  /// tamperCiphertext：翻转目标设备信封中密文的首字节。
  /// 若密文过短则整体替换为攻击者密文。
  static WireFrame tamperCiphertext(WireFrame frame) {
    final mutated = _mapDeep(frame.body);
    final envelope = _targetEnvelope(mutated);
    final raw = envelope['ciphertext'] as String;
    final bytes = base64Url.decode(raw);
    if (bytes.isEmpty) {
      envelope['ciphertext'] = base64Url.encode(
        utf8.encode('attacker-controlled-ciphertext'),
      );
    } else {
      bytes[0] = bytes[0] ^ 0xff;
      envelope['ciphertext'] = base64Url.encode(bytes);
    }
    return _withBody(frame, mutated);
  }

  /// tamperHeader：改写 protected_header 内容但不更新 header_hash。
  static WireFrame tamperHeader(WireFrame frame) {
    final mutated = _mapDeep(frame.body);
    final envelope = _targetEnvelope(mutated);
    final header = envelope['protected_header'] as String;
    final bytes = base64Url.decode(header);
    bytes[bytes.length - 1] = bytes[bytes.length - 1] ^ 0x01;
    envelope['protected_header'] = base64Url.encode(bytes);
    return _withBody(frame, mutated);
  }

  /// directorySwap：把真实目录身份键替换为攻击者键（W2 握手材料改写）。
  /// 返回值供 SimulatedDevice.establishSession 的 directoryIdentityOverride。
  static String swapDirectoryIdentity(String realKey) =>
      base64.encode(utf8.encode('attacker-identity-${realKey.length}'));

  /// flood：以模板帧生成 n 条垃圾帧（message_id 递增，密文替换为垃圾）。
  static List<WireFrame> flood(WireFrame template, int count) => List.generate(
    count,
    (i) => tamperCiphertext(
      template.copyWith(messageId: '${template.messageId}-flood-$i'),
    ),
    growable: false,
  );

  static Map<String, dynamic> _mapDeep(Map<String, dynamic> source) =>
      jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

  static Map<String, dynamic> _targetEnvelope(Map<String, dynamic> body) {
    final e2ee = body['e2ee'] as Map<String, dynamic>;
    final devices = e2ee['devices'] as Map<String, dynamic>;
    return devices.values.first as Map<String, dynamic>;
  }

  static WireFrame _withBody(WireFrame frame, Map<String, dynamic> body) =>
      WireFrame(
        messageId: frame.messageId,
        senderUid: frame.senderUid,
        senderDid: frame.senderDid,
        recipientUid: frame.recipientUid,
        recipientDid: frame.recipientDid,
        body: body,
        wireSeq: frame.wireSeq,
      );
}
