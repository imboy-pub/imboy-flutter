import 'package:imboy/store/model/model_parse_utils.dart';

class EntityVideo {
  final String md5, name, uri;
  final int width, height;

  /// bytes
  int? size; // filesize

  String? author;

  /// microsecond
  double? duration;

  EntityVideo({
    required this.md5,
    required this.name,
    required this.uri,
    // unit Bytes
    this.size = 0,
    this.width = 0,
    this.height = 0,
    this.author = '',
    this.duration = 0.0,
  });

  factory EntityVideo.fromJson(Map<String, dynamic> json) {
    return EntityVideo(
      md5: parseModelString(json["md5"]),
      name: parseModelString(json["name"]),
      uri: parseModelString(json["uri"]),
      size: parseModelInt(json["size"]),
      width: parseModelInt(json["width"]),
      height: parseModelInt(json["height"]),
      duration: parseModelDouble(json['duration']),
      author: parseModelString(json['author']),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["md5"] = md5;
    data["name"] = name;
    data["uri"] = uri;
    data["size"] = size;
    data["width"] = width;
    data["height"] = height;
    data["duration"] = duration;
    data["author"] = author;

    return data;
  }
}
