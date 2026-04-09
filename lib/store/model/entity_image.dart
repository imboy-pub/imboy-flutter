import 'package:imboy/store/model/model_parse_utils.dart';

class EntityImage {
  final String md5, name, uri;
  final int width, height, size;

  EntityImage({
    required this.md5,
    required this.name,
    required this.uri,
    this.size = 0,
    this.width = 0,
    this.height = 0,
  });

  factory EntityImage.fromJson(Map<String, dynamic> json) {
    return EntityImage(
      md5: parseModelString(json["md5"]),
      name: parseModelString(json["name"]),
      uri: parseModelString(json["uri"]),
      size: parseModelInt(json["size"]),
      width: parseModelInt(json["width"]),
      height: parseModelInt(json["height"]),
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
    return data;
  }
}
