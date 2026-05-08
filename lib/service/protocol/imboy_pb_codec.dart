import 'dart:convert';
import 'dart:typed_data';

import 'package:imboy/service/protocol/imboy.pb.dart';

/// Codec for decoding v2 binary WebSocket frame payloads.
///
/// Supports two decode strategies:
/// 1. Protobuf: decode as [IMBoyMessage], convert to Map for downstream
/// 2. JSON fallback: utf8 decode + jsonDecode (legacy v1-in-v2-frame)
class ImboyPbCodec {
  ImboyPbCodec._();

  /// Try to decode [bytes] as a protobuf [IMBoyMessage].
  /// Returns a Map matching the existing JSON message format, or null on failure.
  static Map<String, dynamic>? tryDecode(Uint8List bytes) {
    try {
      final msg = IMBoyMessage.fromBuffer(bytes);
      return _pbMessageToMap(msg);
    } catch (_) {
      return null;
    }
  }

  /// Try to decode [bytes] as UTF-8 JSON text.
  /// Returns parsed Map, or null on failure.
  static Map<String, dynamic>? tryDecodeJsonFallback(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) return parsed;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Convert protobuf [IMBoyMessage] to the Map format expected by downstream.
  static Map<String, dynamic> _pbMessageToMap(IMBoyMessage msg) {
    final map = <String, dynamic>{
      'id': msg.id,
      'type': msg.type.name,
      'from': msg.from.toInt(),
      'to': msg.to.toInt(),
      'msg_type': _contentTypeToName(msg.msgType),
      'action': msg.action,
      'created_at': msg.createdAt.toInt(),
    };

    if (msg.hasServerTs()) {
      map['server_ts'] = msg.serverTs.toInt();
    }
    if (msg.hasExpireSecs()) {
      map['expire_secs'] = msg.expireSecs;
    }
    if (msg.hasConvSeq()) {
      map['conv_seq'] = msg.convSeq.toInt();
    }
    if (msg.hasE2ee()) {
      map['e2ee'] = _e2eeMetaToMap(msg.e2ee);
    }

    // Decode inner payload bytes
    if (msg.payload.isNotEmpty) {
      map['payload'] = _decodeInnerPayload(msg.payload, msg.action);
    }

    return map;
  }

  /// Decode the inner payload bytes.
  /// For known action types, try protobuf-specific payloads first, then JSON.
  /// For unknown actions, try JSON decode.
  static dynamic _decodeInnerPayload(List<int> payloadBytes, String action) {
    // Try protobuf-specific payload decode based on action
    final pbResult = _tryActionPayload(payloadBytes, action);
    if (pbResult != null) return pbResult;

    // Fallback: try JSON decode of the inner payload bytes
    try {
      final text = utf8.decode(payloadBytes, allowMalformed: false);
      return jsonDecode(text);
    } catch (_) {
      // Return raw base64 if neither protobuf nor JSON works
      return base64Encode(payloadBytes);
    }
  }

  /// Try to decode action-specific protobuf payloads.
  static Map<String, dynamic>? _tryActionPayload(
    List<int> bytes,
    String action,
  ) {
    try {
      switch (action) {
        case 'logged_another_device':
          final pb = PayloadLoggedAnotherDevice.fromBuffer(bytes);
          return {'did': pb.did, 'dname': pb.dname};
        case 'please_refresh_token':
          final pb = PayloadRefreshToken.fromBuffer(bytes);
          return {'expire_at': pb.expireAt.toInt()};
        case 'app_upgrade':
          final pb = PayloadAppUpgrade.fromBuffer(bytes);
          return {
            'upgrade_type': pb.upgradeType,
            'vsn': pb.vsn,
            if (pb.hasDownloadUrl()) 'download_url': pb.downloadUrl,
            if (pb.hasDescription()) 'description': pb.description,
            if (pb.changelog.isNotEmpty) 'changelog': pb.changelog.toList(),
            if (pb.hasFileSize()) 'file_size': pb.fileSize.toInt(),
            if (pb.hasFileHash()) 'file_hash': pb.fileHash,
          };
        case 'device_force_offline':
          final pb = PayloadDeviceKicked.fromBuffer(bytes);
          return {'reason': pb.reason};
        case 'c2c_del_everyone':
        case 'c2g_del_everyone':
        case 'c2g_del_for_me':
          final pb = PayloadMsgDeleted.fromBuffer(bytes);
          return {'old_msg_id': pb.oldMsgId};
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static String _contentTypeToName(ContentType ct) {
    switch (ct) {
      case ContentType.TEXT:
        return 'text';
      case ContentType.IMAGE:
        return 'image';
      case ContentType.VIDEO:
        return 'video';
      case ContentType.AUDIO:
        return 'audio';
      case ContentType.FILE:
        return 'file';
      case ContentType.LOCATION:
        return 'location';
      case ContentType.CUSTOM:
        return 'custom';
      case ContentType.E2EE:
        return 'e2ee';
      default:
        return 'text';
    }
  }

  static Map<String, dynamic> _e2eeMetaToMap(E2EEMeta e2ee) {
    return {
      'ver': e2ee.ver,
      'suite': e2ee.suite,
      'nonce': base64Encode(e2ee.nonce),
      'keys': e2ee.keys
          .map(
            (k) => {
              'did': k.did,
              'kid': k.kid,
              'wrap_alg': k.wrapAlg,
              'ek': base64Encode(k.ek),
            },
          )
          .toList(),
    };
  }
}
