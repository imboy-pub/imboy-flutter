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

  get webRtcType {
    type = type.toLowerCase();
    if (type.startsWith('webrtc_')) {
      return type.replaceFirst('webrtc_', '');
    }
    return type;
  }

  factory WebRTCSignalingModel.fromJson(Map<String, dynamic> json) {
    return WebRTCSignalingModel(
      msgId: json['id'],
      type: json['type'],
      from: json['from'],
      to: json['to'],
      payload: json['payload'],
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
