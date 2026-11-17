part of 'message.dart';

/// 处理 E2EE 消息解密（v2.0 格式）
///
/// ## v2.0 E2EE 格式
/// - **payload**：密文字符串（格式：`base64(nonce).base64(ciphertext)`）
/// - **e2ee 元数据**：包含加密参数（keys 数组、nonce、suite 等）
///
/// ## 解密流程
/// 1. 从 payload 获取密文字符串
/// 2. 从 e2ee 元数据获取加密参数
/// 3. 调用 `E2EEService.decryptE2EEMessage` 解密
/// 4. 解析解密后的 JSON 内容
/// 5. 返回解密后的 payload
///
/// ## 参数
/// - [data]: 原始消息数据（包含 payload 和 e2ee 字段）
/// - [msgId]: 消息 ID
/// - [msgType]: 消息类型（C2C/C2G）
/// - [createdAtMs]: 创建时间戳（毫秒）
///
/// ## 返回值
/// 解密后的 payload（`Map<String, dynamic>`），如果解密失败则返回包含 `_e2ee_failed` 标记的 payload
Future<Map<String, dynamic>> _handleE2EEMessage({
  required Map<String, dynamic> data,
  required String msgId,
  // ignore: unused_element_parameter
  required String chatType,
  required int createdAtMs,
}) async {
  // WebSocket API v2.0: 保留原始消息的 msg_type（内容类型）
  final originalMsgType = parseModelString(
    data['msg_type'],
    defaultValue: 'text',
  );

  // 0. PFv3 分流（必须在 v1/v2 的密文形状检查之前）：
  //    v3 的密文在 e2ee.devices 内，外层 payload 为空串。
  //    decryptInboundV3 返回 null 表示不是 v3，继续走下面的 v1/v2 路径。
  final v3Result = await E2EEService.decryptInboundV3(data: data);
  if (v3Result != null) {
    if (v3Result['_e2ee_failed'] == true) {
      iPrint(
        '❌ [E2EE] v3 解密失败: msgId=$msgId, reason=${v3Result['_e2ee_reason']}',
      );
      return {
        'msg_type': originalMsgType,
        'text': E2EEService.e2eeFailedPlaceholderText(v3Result['_e2ee_reason']),
        '_e2ee_failed': true,
        '_e2ee_reason': v3Result['_e2ee_reason'],
        // 保留原始密文供自愈重试（C3-β，与 v1/v2、Megolm 失败分支同
        // 语义）：缺此键失败行重试恒跳过，单聊 PFv3 消息永远救不回。
        // raw 与 data 同引用时由落库侧 identical() 补偿浅拷贝防成环。
        '_e2ee_raw': v3Result['_e2ee_raw'],
      };
    }
    iPrint('✅ [E2EE] v3 解密成功: msgId=$msgId');
    return v3Result;
  }

  // C2G Megolm v2 使用扁平 e2ee metadata，正文仍在顶层 payload；它既不是
  // PFv3，也不能交给 legacy RSA/Olm 形状解析。这里必须接入统一的 Megolm
  // 入站路由，否则真实 WebSocket 群消息会在后续 `keys` 校验处被误判为
  // invalid_keys。该分流与 C2C PFv3 分流并列，保持生产接收链可追踪。
  final e2eeRawForMegolm = data['e2ee'];
  final e2eeForMegolm = e2eeRawForMegolm is Map
      ? Map<String, dynamic>.from(e2eeRawForMegolm)
      : <String, dynamic>{};
  final isMegolmGroup =
      e2eeForMegolm['protocol'] == 'megolm' &&
      (e2eeForMegolm['gid']?.toString() ?? '').isNotEmpty;
  if (isMegolmGroup) {
    final megolmResult = await E2EEService.decryptIncomingPayload(
      payload: data,
    );
    if (megolmResult['_e2ee_failed'] == true) {
      iPrint(
        '❌ [E2EE] Megolm 解密失败: msgId=$msgId, reason=${megolmResult['_e2ee_reason']}',
      );
    } else {
      iPrint('✅ [E2EE] Megolm 解密成功: msgId=$msgId');
    }
    return megolmResult;
  }

  // 1. 获取密文字符串
  final ciphertext = data['payload']?.toString();
  if (ciphertext == null || ciphertext.isEmpty) {
    iPrint('❌ [E2EE] payload 为空: msgId=$msgId');
    return {
      'msg_type': originalMsgType, // 保留原始消息类型
      'text': E2EEService.e2eeFailedPlaceholderText('empty_payload'),
      '_e2ee_failed': true,
      '_e2ee_reason': 'empty_payload',
    };
  }

  // 2. 获取 e2ee 元数据
  final e2eeRaw = data['e2ee'];
  Map<String, dynamic>? e2ee;

  if (e2eeRaw != null && e2eeRaw.toString().isNotEmpty) {
    if (e2eeRaw is String) {
      try {
        final decoded = jsonDecode(e2eeRaw);
        if (decoded is Map<String, dynamic>) {
          e2ee = decoded.cast<String, dynamic>();
        }
      } on Object catch (e) {
        iPrint(
          '❌ [E2EE] e2ee 字符串解析失败: msgId=$msgId, '
          'error=${e.runtimeType}',
        );
      }
    } else if (e2eeRaw is Map<String, dynamic>) {
      e2ee = e2eeRaw.cast<String, dynamic>();
    }
  }

  if (e2ee == null || e2ee.isEmpty) {
    iPrint('❌ [E2EE] e2ee 元数据为空: msgId=$msgId');
    return {
      'msg_type': originalMsgType, // 保留原始消息类型
      'text': E2EEService.e2eeFailedPlaceholderText('missing_e2ee_metadata'),
      '_e2ee_failed': true,
      '_e2ee_reason': 'missing_e2ee_metadata',
      // 不保存原始密文，避免将密文写入 SQLite
    };
  }

  // 3. 调用 E2EEService.decryptE2EEMessage 解密
  try {
    final plaintext = await E2EEService.decryptE2EEMessage(
      ciphertext: ciphertext,
      e2ee: e2ee,
    );

    // 4. 解析解密后的 JSON 内容
    final decoded = jsonDecode(plaintext);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('解密后的内容不是 JSON 对象');
    }

    final payload = decoded.cast<String, dynamic>();

    // 5. 保留原始消息类型（如果解密后的内容没有 msg_type）
    if (!payload.containsKey('msg_type') || payload['msg_type'] == null) {
      payload['msg_type'] = originalMsgType;
      iPrint('🔧 [E2EE] 保留原始 msg_type: $originalMsgType');
    }

    // 6. 保留原始元数据
    if (data.containsKey('client_send_ts')) {
      payload['client_send_ts'] = data['client_send_ts'];
    }
    if (data.containsKey('sender_did')) {
      payload['sender_did'] = data['sender_did'];
    }
    if (data.containsKey('sender_dtype')) {
      payload['sender_dtype'] = data['sender_dtype'];
    }

    // 7. 保存原始消息元数据（避免循环引用）
    if (!payload.containsKey('_e2ee')) {
      // 只保存必要的元数据，避免循环引用
      payload['_e2ee'] = {
        'id': data['id'],
        'type': data['type'],
        'from': data['from'],
        'to': data['to'],
        'msg_type': originalMsgType,
        'created_at': data['created_at'],
      };
    }

    iPrint('✅ [E2EE] v2.0 解密成功: msgId=$msgId, msgType=${payload['msg_type']}');
    return payload;
  } on Object catch (e) {
    iPrint('❌ [E2EE] 解密失败: msgId=$msgId, error=${e.runtimeType}');

    // 检查是否是密钥不匹配错误
    // 【审计修复 F-04】收窄判定：只匹配 decryptE2EEMessage 抛出的精确异常
    // 'No key found for device: $myDid'（见 e2ee_service.dart decryptE2EEMessage）。
    // 此前用 contains('密钥')/contains('device') 会命中"生成 RSA 密钥对失败"
    // "deviceId 为空"等所有含这些词的异常，误触发丢密文 + 弹不匹配对话框，
    // 链式诱导用户走销毁密钥的恢复路径。其余异常统一走 decrypt_error 分支。
    final errorStr = e.toString().toLowerCase();
    final isKeyMismatch = errorStr.contains('no key found for device');

    if (isKeyMismatch) {
      // 获取发送方 UID（消息来源），用于通知发送方刷新我们的公钥缓存
      final peerId = data['from']?.toString();

      // 触发E2EE密钥不匹配事件，引导用户重新登录
      AppEventBus.fire(
        E2EEKeyMismatchEvent(
          messageId: msgId,
          reason: '密钥不匹配',
          peerId: peerId, // 发送方 UID，用于清除发送方对我们的公钥缓存
        ),
      );

      // 密钥不匹配：保存原始密文，支持自愈机制重试恢复 (C3)。
      // 文案走通用加密占位：重登引导由 E2EEKeyMismatchEvent 监听者
      // （chat_page）与失败气泡点击（showE2EERecoveryGuide）负责，
      // 此处不再内嵌「点击下方按钮重新登录」类误导性指引。
      return {
        'msg_type': originalMsgType,
        'text': E2EEService.e2eeFailedPlaceholderText('key_mismatch'),
        '_e2ee_failed': true,
        '_e2ee_reason': 'key_mismatch',
        '_e2ee_raw': data, // 存储完整密文以便后续重试自愈解密 (C3)
      };
    }

    // 其他解密错误：保存原始密文，支持自愈机制重试恢复 (C3)
    return {
      'msg_type': originalMsgType, // 保留原始消息类型
      'text': E2EEService.e2eeFailedPlaceholderText('decrypt_error'),
      '_e2ee_failed': true,
      '_e2ee_reason': 'decrypt_error',
      '_e2ee_raw': data, // 存储完整密文以便后续重试自愈解密 (C3)
    };
  }
}
