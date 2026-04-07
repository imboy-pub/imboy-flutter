class WebRTCSignalingModel {
  String msgId;
  String type;
  String from;
  String to;
  Map<String, dynamic> payload;

  WebRTCSignalingModel({
    required this.msgId,
    required this.type,
    required this.from,
    required this.to,
    required this.payload,
  });

  String get webRtcType {
    type = type.toLowerCase();
    if (type.startsWith('webrtc_')) {
      return type.replaceFirst('webrtc_', '');
    }
    return type;
  }

  factory WebRTCSignalingModel.fromJson(Map<String, dynamic> json) {
    return WebRTCSignalingModel(
      msgId: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      from: (json['from'] ?? '').toString(),
      to: (json['to'] ?? '').toString(),
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': msgId,
    'type': type,
    'from': from,
    'to': to,
    'payload': payload,
  };
}
