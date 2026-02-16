import 'dart:async';
import 'dart:convert';

import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/rsa.dart';

/// E2EE 分片消息处理器
///
/// 零信任架构：处理 E2EE 社交恢复分片的 WebSocket 消息
/// - 监听 S2C 消息，处理分片存储请求
/// - 监听 C2C 消息，处理分片解密请求
class E2EEShardMessageHandler {
  // 单例模式
  static final E2EEShardMessageHandler _instance =
      E2EEShardMessageHandler._internal();
  static E2EEShardMessageHandler get to => _instance;
  E2EEShardMessageHandler._internal();

  // 事件订阅
  StreamSubscription<WebSocketMessageReceivedEvent>? _messageSubscription;

  // 解密请求的 Completer 映射（用于等待代理响应）
  final Map<String, Completer<String?>> _decryptRequests = {};

  /// 初始化处理器
  /// 在应用启动时调用，开始监听 WebSocket 消息
  void init() {
    if (_messageSubscription != null) {
      print('E2EE分片消息处理器已初始化');
      return;
    }

    _messageSubscription = AppEventBus.on<WebSocketMessageReceivedEvent>()
        .listen(_handleWebSocketMessage);

    print('E2EE分片消息处理器已初始化');
  }

  /// 释放资源
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _decryptRequests.clear();
  }

  /// 处理 WebSocket 消息
  void _handleWebSocketMessage(WebSocketMessageReceivedEvent event) {
    try {
      final type = event.type.toUpperCase();
      final data = event.data;

      // 【修复】先从顶层 data 读取 msg_type（payload 可能是密文）
      // 只处理 E2EE 社交恢复分片消息，其他消息直接跳过
      final msgType = data['msg_type']?.toString() ?? '';
      if (msgType != 'e2ee_social_shard') {
        return; // 不是分片消息，让其他处理器处理
      }

      // 安全地获取 payload - 可能是 Map 或 String（加密消息）
      final payloadRaw = data['payload'];
      Map<String, dynamic>? payload;

      if (payloadRaw is Map) {
        payload = payloadRaw.cast<String, dynamic>();
      } else if (payloadRaw is String) {
        // payload 是字符串，可能是加密消息
        // 尝试解析为 JSON
        try {
          final decoded = jsonDecode(payloadRaw);
          if (decoded is Map) {
            payload = decoded.cast<String, dynamic>();
          }
        } catch (e, s) {
          // 不是有效的 JSON，跳过此消息
          print('⚠️ [E2EE] payload 是字符串但不是有效 JSON，跳过 $payloadRaw ; e $e, s: $s ;');
          return;
        }
      }

      if (payload == null) return;

      final action = payload['action']?.toString() ?? '';

      print('🔐 [E2EE] 收到分片消息: type=$type, action=$action');

      switch (type) {
        case 'S2C':
          _handleS2CMessage(action, payload, data);
          break;
        case 'C2C':
          _handleC2CMessage(action, payload, data);
          break;
      }
    } catch (e) {
      print('E2EE分片消息处理失败: $e');
    }
  }

  /// 处理 S2C 消息（服务端到客户端）
  ///
  /// 零信任架构：处理分片存储请求
  void _handleS2CMessage(
    String action,
    Map<String, dynamic> payload,
    Map<String, dynamic> data,
  ) {
    switch (action) {
      case 'store_shard':
        _handleStoreShard(payload);
        break;
      case 'shard_stored':
        _handleShardStored(payload);
        break;
      default:
        print('未知的 S2C action: $action');
    }
  }

  /// 处理分片存储请求
  ///
  /// 零信任架构：代理将分片存储在本地安全存储中
  void _handleStoreShard(Map<String, dynamic> payload) {
    try {
      final shardId = payload['shard_id']?.toString() ?? '';
      if (shardId.isEmpty) {
        print('分片 ID 为空，跳过存储');
        return;
      }

      print('📦 [E2EE] 存储分片: shardId=$shardId');

      // 存储分片到安全存储
      E2EESocialService.storeReceivedShard(payload)
          .then((_) {
            // 添加到分片 ID 列表
            StorageSecureService.to.addShardId(shardId);

            print('✅ [E2EE] 分片存储成功: shardId=$shardId');

            // 发送确认消息给服务端
            _sendShardStoredConfirmation(shardId, payload);
          })
          .catchError((error) {
            print('❌ [E2EE] 分片存储失败: $error');
          });
    } catch (e) {
      print('❌ [E2EE] 处理 store_shard 失败: $e');
    }
  }

  /// 发送分片存储确认消息
  void _sendShardStoredConfirmation(
    String shardId,
    Map<String, dynamic> originalPayload,
  ) {
    try {
      final ws = WebSocketService.to;
      final fromUid = originalPayload['uid'] ?? 0;

      final confirmMessage = {
        'type': 'S2C',
        'to': hashidEncode(fromUid),
        'payload': {
          'msg_type': 'e2ee_social_shard',
          'action': 'shard_stored',
          'shard_id': shardId,
        },
      };

      final messageId = E2EESocialService.generateMessageId();
      ws.sendMessage(jsonEncode(confirmMessage), messageId);

      print('✅ [E2EE] 已发送分片存储确认: shardId=$shardId');
    } catch (e) {
      print('❌ [E2EE] 发送分片存储确认失败: $e');
    }
  }

  /// 处理分片存储确认
  void _handleShardStored(Map<String, dynamic> payload) {
    final shardId = payload['shard_id']?.toString() ?? '';
    print('✅ [E2EE] 代理已确认存储分片: shardId=$shardId');

    // TODO: 更新 UI 状态，通知用户分片已成功存储
    // 可以通过事件总线发送通知
  }

  /// 处理 C2C 消息（客户端到客户端）
  ///
  /// 零信任架构：处理代理解密请求
  void _handleC2CMessage(
    String action,
    Map<String, dynamic> payload,
    Map<String, dynamic> data,
  ) {
    switch (action) {
      case 'decrypt_shard':
        _handleDecryptShardRequest(payload);
        break;
      case 'decrypted_shard':
        _handleDecryptedShardResponse(payload);
        break;
      default:
        print('未知的 C2C action: $action');
    }
  }

  /// 处理分片解密请求
  ///
  /// 零信任架构：代理使用自己的私钥解密分片，返回给密钥所有者
  void _handleDecryptShardRequest(Map<String, dynamic> payload) {
    try {
      final shardId = payload['shard_id']?.toString() ?? '';
      if (shardId.isEmpty) {
        print('分片 ID 为空，跳过解密');
        return;
      }

      print('🔓 [E2EE] 收到解密请求: shardId=$shardId');

      // 从安全存储读取分片
      StorageSecureService.to
          .getE2EEShard(shardId)
          .then((shardJson) {
            if (shardJson == null) {
              print('❌ [E2EE] 分片不存在: shardId=$shardId');
              _sendDecryptShardError(shardId, '分片不存在');
              return;
            }

            final shard = jsonDecode(shardJson) as Map<String, dynamic>;
            final requesterUid = payload['uid'] ?? 0;

            // 验证请求者是否是分片所有者
            if (shard['uid'] != requesterUid) {
              print('❌ [E2EE] 无权访问此分片: shardId=$shardId');
              _sendDecryptShardError(shardId, '无权访问此分片');
              return;
            }

            // 获取加密的分片
            final encryptedShard = shard['encrypted_shard']?.toString() ?? '';

            // 零信任架构：代理使用自己的私钥解密分片
            // 分片是通过 RSA-OAEP-256 加密的，使用代理的公钥
            // 代理需要使用自己的私钥解密
            _decryptShardWithPrivateKey(shardId, encryptedShard, payload)
                .then((decryptedShard) {
                  if (decryptedShard != null) {
                    print('✅ [E2EE] 分片解密成功: shardId=$shardId');
                    _sendDecryptedShard(shardId, decryptedShard, payload);
                  } else {
                    print('❌ [E2EE] 分片解密失败: shardId=$shardId');
                    _sendDecryptShardError(shardId, '解密失败');
                  }
                })
                .catchError((error) {
                  print('❌ [E2EE] 解密过程中出错: $error');
                  _sendDecryptShardError(shardId, '解密过程中出错');
                });
          })
          .catchError((error) {
            print('❌ [E2EE] 读取分片失败: $error');
            _sendDecryptShardError(shardId, '读取分片失败');
          });
    } catch (e) {
      print('❌ [E2EE] 处理 decrypt_shard 失败: $e');
    }
  }

  /// 发送解密后的分片
  void _sendDecryptedShard(
    String shardId,
    String decryptedShard,
    Map<String, dynamic> originalPayload,
  ) {
    try {
      final ws = WebSocketService.to;
      final toUid = originalPayload['uid'] ?? 0;

      final responseMessage = {
        'type': 'C2C',
        'to': hashidEncode(toUid),
        'payload': {
          'msg_type': 'e2ee_social_shard',
          'action': 'decrypted_shard',
          'shard_id': shardId,
          'decrypted_shard': decryptedShard,
        },
      };

      final messageId = E2EESocialService.generateMessageId();
      ws.sendMessage(jsonEncode(responseMessage), messageId);

      print('✅ [E2EE] 已发送解密分片: shardId=$shardId');
    } catch (e) {
      print('❌ [E2EE] 发送解密分片失败: $e');
    }
  }

  /// 发送解密分片错误
  void _sendDecryptShardError(String shardId, String error) {
    try {
      final ws = WebSocketService.to;

      final errorMessage = {
        'type': 'C2C',
        'payload': {
          'msg_type': 'e2ee_social_shard',
          'action': 'decrypt_error',
          'shard_id': shardId,
          'error': error,
        },
      };

      final messageId = E2EESocialService.generateMessageId();
      ws.sendMessage(jsonEncode(errorMessage), messageId);

      print('❌ [E2EE] 已发送解密错误: shardId=$shardId, error=$error');
    } catch (e) {
      print('❌ [E2EE] 发送解密错误失败: $e');
    }
  }

  /// 使用代理的私钥解密分片
  ///
  /// 零信任架构：代理使用自己的私钥解密分片
  /// 分片是通过 RSA-OAEP-256 加密的
  ///
  /// [shardId] 分片 ID
  /// [encryptedShard] 加密的分片数据（Base64 编码）
  /// [originalPayload] 原始请求 payload
  /// Returns: 解密后的分片数据（Base64 编码）
  Future<String?> _decryptShardWithPrivateKey(
    String shardId,
    String encryptedShard,
    Map<String, dynamic> originalPayload,
  ) async {
    try {
      // 1. 获取代理的私钥
      final privateKeyPem = await RSAService.privateKey();
      if (privateKeyPem == null || privateKeyPem.isEmpty) {
        print('❌ [E2EE] 代理私钥不存在');
        return null;
      }

      // 2. 解析私钥
      final privateKey = RSAService.parsePrivateKeyFromPem(privateKeyPem);

      // 3. 解码 Base64 加密分片
      final encryptedBytes = base64Decode(encryptedShard);

      // 4. 使用 RSA-OAEP 解密
      final decryptedBytes = RSAService.rsaDecrypt(privateKey, encryptedBytes);

      // 5. 重新编码为 Base64 以便传输
      final decryptedShard = base64.encode(decryptedBytes);

      print('✅ [E2EE] RSA-OAEP 解密成功: shardId=$shardId');
      return decryptedShard;
    } catch (e) {
      print('❌ [E2EE] RSA-OAEP 解密失败: shardId=$shardId, error=$e');
      return null;
    }
  }

  /// 处理解密分片响应
  ///
  /// 零信任架构：收到代理返回的解密分片
  void _handleDecryptedShardResponse(Map<String, dynamic> payload) {
    final shardId = payload['shard_id']?.toString() ?? '';
    final decryptedShard = payload['decrypted_shard']?.toString() ?? '';

    print('🔓 [E2EE] 收到解密分片: shardId=$shardId');

    // 通知等待的 Completer
    final completer = _decryptRequests[shardId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(decryptedShard);
      _decryptRequests.remove(shardId);
      print('✅ [E2EE] 已通知解密请求: shardId=$shardId');
    } else {
      print('⚠️ [E2EE] 未找到对应的解密请求: shardId=$shardId');
    }
  }

  /// 请求代理解密分片
  ///
  /// 零信任架构：恢复密钥时，向代理请求解密分片
  ///
  /// [proxyUid] 代理用户 ID（HashID 编码）
  /// [shardId] 分片 ID
  /// [timeout] 超时时间（秒），默认 30 秒
  /// Returns: 解密后的分片，超时或失败返回 null
  Future<String?> requestDecryptedShard({
    required String proxyUid,
    required String shardId,
    int timeout = 30,
  }) async {
    try {
      print('🔓 [E2EE] 请求代理解密分片: shardId=$shardId, proxyUid=$proxyUid');

      // 创建 Completer 用于等待响应
      final completer = Completer<String?>();
      _decryptRequests[shardId] = completer;

      // 发送解密请求
      final ws = WebSocketService.to;
      final message = {
        'type': 'C2C',
        'to': proxyUid,
        'payload': {
          'msg_type': 'e2ee_social_shard',
          'action': 'decrypt_shard',
          'shard_id': shardId,
        },
      };

      final messageId = E2EESocialService.generateMessageId();
      final success = await ws.sendMessage(jsonEncode(message), messageId);

      if (!success) {
        _decryptRequests.remove(shardId);
        print('❌ [E2EE] 发送解密请求失败');
        return null;
      }

      // 等待响应（带超时）
      final result = await completer.future.timeout(
        Duration(seconds: timeout),
        onTimeout: () {
          _decryptRequests.remove(shardId);
          print('❌ [E2EE] 解密请求超时: shardId=$shardId');
          return null;
        },
      );

      return result;
    } catch (e) {
      _decryptRequests.remove(shardId);
      print('❌ [E2EE] 请求解密分片失败: $e');
      return null;
    }
  }
}

/// 辅助函数：HashID 编码
String hashidEncode(dynamic id) {
  if (id is int) {
    // 简单的 Base62 编码实现
    const alphabet =
        '123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
    if (id == 0) return alphabet[0];

    String result = '';
    int num = id;
    while (num > 0) {
      result = alphabet[num % 52] + result;
      num ~/= 52;
    }
    return result;
  }
  return id.toString();
}
