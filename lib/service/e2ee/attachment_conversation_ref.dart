/// E2EE-061 —— 附件绑定值里 `conversation_id` 的**单一真值源**
///
/// 方案甲要求三个输入「上传前可定、且**全设备一致**」。前两项由
/// `message_id` / `sender_uid` 天然满足，`conversation_id` 不然：
///
/// ⚠️⚠️ **不能用 `conversationUk3`** —— 群会话的 uk3 是
/// `C2G_<本机uid>_<gid>`（见 `ConversationUk3Generator`），**逐用户不同**。
/// 拿它算绑定值，除发送者外没人能算出同一个 AAD，群附件对所有收件人不可读，
/// 而且失败形态是「密文完好、就是打不开」，最难排查。
///
/// 本模块给出发送侧与接收侧**共用**的推导：同一个函数被两端调用，
/// 就没有"两边各写一份、其中一边被改"的可能。
///
/// | 会话 | conversation_id | 两端一致 |
/// |---|---|---|
/// | C2C | `c2c:<min>:<max>`（整数归一化） | ✅ 与收发方向无关 |
/// | C2G | `<group_id>` | ✅ |
/// | 其他 | `null` | 闸门判 missingBinding → 不封装 |
library;

class AttachmentConversationRef {
  /// 由会话类型与消息两端推导 `conversation_id`。
  ///
  /// [fromUid] / [toUid] 就是消息的 `from` / `to`：
  /// - 发送侧 = (我, 对端)；
  /// - 接收侧 = (对端, 我)。
  ///   C2C 归一化后两者同值；C2G 的 `to` 两端都是 group_id。
  ///
  /// 返回 null = 这个会话推不出稳定标识（C2S / 未知），调用方须 fail-closed。
  static String? of({
    required String chatType,
    required String fromUid,
    required String toUid,
  }) {
    final String t = chatType.toUpperCase();
    if (t == 'C2G') {
      return toUid.isEmpty ? null : toUid;
    }
    if (t == 'C2C') {
      if (fromUid.isEmpty || toUid.isEmpty) return null;
      return c2cKey(fromUid, toUid);
    }
    return null;
  }

  /// 单聊 conv_key：`c2c:<minUid>:<maxUid>`，按**整数**归一化顺序。
  ///
  /// 用 [BigInt] 解析：TSID 是 64 位整数，超过 Web（dart2js）53 位 int 精度；
  /// BigInt 在所有平台精确。非数字时回退字符串序，保证确定性。
  ///
  /// ⚠️ 这是全项目**唯一**一份实现：`ChatAttachmentHandler.deriveUploadScope`
  /// 的 `scope_ref` 也走它。两份实现哪怕只在排序回退上有分歧，
  /// 都会变成「上传 scope 与绑定值对不上」的隐性错配。
  static String c2cKey(String a, String b) {
    final BigInt? ai = BigInt.tryParse(a);
    final BigInt? bi = BigInt.tryParse(b);
    final bool aFirst = (ai != null && bi != null)
        ? ai <= bi
        : a.compareTo(b) <= 0;
    return aFirst ? 'c2c:$a:$b' : 'c2c:$b:$a';
  }
}
