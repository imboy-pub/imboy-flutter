import 'dart:convert';
import 'dart:typed_data';

import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';

/// Actual protocol codecs; offline use does not qualify a backend journey.
class ReleaseWireCodec {
  ReleaseWireCodec(String? selectedProtocol)
    : framed = selectedProtocol == 'imboy.v2' {
    if (!const {
      'imboy.v2',
      'imboy-json',
      'text',
      'sip',
      null,
    }.contains(selectedProtocol)) {
      throw const FormatException('unsupported negotiated protocol');
    }
  }

  final bool framed;
  static const maxBytes = 2 * 1024 * 1024;
  static const _businessTypes = {
    'C2C': FrameType.msgC2C,
    'C2G': FrameType.msgC2G,
    'C2S': FrameType.msgC2S,
    'S2C': FrameType.msgS2C,
  };

  Object encode(Map<String, dynamic> message) {
    _validateMessage(message);
    final type = _businessTypes[message['type']];
    if (type == null) throw const FormatException('unsupported outbound type');
    final text = jsonEncode(message);
    final payload = Uint8List.fromList(utf8.encode(text));
    _checkSize(payload.length + (framed ? ImboyFrame.headerSize : 0));
    return framed
        ? ImboyFrame.encode(type: type, flags: 0, payload: payload)
        : text;
  }

  /// Returns business messages only. Control frames are surfaced separately,
  /// never converted to business ACKs; adapter must handle ping/close explicitly.
  DecodedReleaseFrame decode(Object data) {
    if (data is String) {
      _checkSize(utf8.encode(data).length);
      if (data == 'pong' && !framed) {
        return DecodedReleaseFrame.control(FrameType.heartbeatPong, const []);
      }
      return DecodedReleaseFrame.business(_decodeJson(data));
    }
    if (data is! List<int>) throw const FormatException('invalid WS data');
    _checkSize(data.length);
    if (data.any((byte) => byte < 0 || byte > 255)) {
      throw const FormatException('invalid byte');
    }
    final bytes = Uint8List.fromList(data);
    if (!framed) return DecodedReleaseFrame.business(_decodePayload(bytes));
    final decoded = ImboyFrame.tryDecode(bytes);
    if (decoded == null || decoded.consumed != bytes.length) {
      throw const FormatException('incomplete or trailing frame');
    }
    final frame = decoded.frame;
    if (frame.isCompressed || frame.isEncrypted) {
      throw const FormatException('unsupported frame transformation');
    }
    if (!_businessTypes.values.contains(frame.type)) {
      return DecodedReleaseFrame.control(frame.type, frame.payload);
    }
    return DecodedReleaseFrame.business(_decodePayload(frame.payload));
  }

  Map<String, dynamic> _decodePayload(Uint8List payload) {
    final json = ImboyPbCodec.tryDecodeJsonFallback(payload);
    final result = json ?? ImboyPbCodec.tryDecode(payload);
    if (result == null) throw const FormatException('invalid business payload');
    _validateMessage(result);
    return result;
  }

  Map<String, dynamic> _decodeJson(String text) {
    final result = jsonDecode(text);
    if (result is! Map<String, dynamic>) {
      throw const FormatException('invalid business JSON');
    }
    _validateMessage(result);
    return result;
  }

  void _validateMessage(Map<String, dynamic> message) {
    for (final key in ['id', 'type']) {
      final value = message[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('missing business identity');
      }
    }
  }

  void _checkSize(int size) {
    if (size > maxBytes) throw const FormatException('WS message too large');
  }
}

class DecodedReleaseFrame {
  DecodedReleaseFrame.business(Map<String, dynamic> value)
    : message = Map.unmodifiable(value),
      controlType = null,
      controlPayload = const [];
  DecodedReleaseFrame.control(this.controlType, List<int> payload)
    : message = null,
      controlPayload = List.unmodifiable(payload);

  final Map<String, dynamic>? message;
  final int? controlType;
  final List<int> controlPayload;
}
