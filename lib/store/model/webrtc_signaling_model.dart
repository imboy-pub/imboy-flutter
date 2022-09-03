class WebRTCSignalingModel {
  String type;
  String to;
  Map payload;
  WebRTCSignalingModel({
    required this.type,
    required this.to,
    required this.payload,
  });

  get webrtctype {
    type = type.toLowerCase();
    if (type.startsWith('webrtc_')) {
      type = type.replaceFirst('webrtc_', '');
    }
    return type;
  }

  factory WebRTCSignalingModel.fromJson(Map<String, dynamic> json) {
    return WebRTCSignalingModel(
      type: json['type'],
      to: json['to'],
      payload: json['payload'],
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'to': to,
        'payload': payload,
      };
}
