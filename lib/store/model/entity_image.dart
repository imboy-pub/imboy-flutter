import 'package:imboy/store/model/model_parse_utils.dart';

class EntityImage {
  final String fileHash256, name, uri;
  final int width, height, size;

  EntityImage({
    required this.fileHash256,
    required this.name,
    required this.uri,
    this.size = 0,
    this.width = 0,
    this.height = 0,
  });

  factory EntityImage.fromJson(Map<String, dynamic> json) {
    return EntityImage(
      // 双读兼容：新数据 file_hash256(SHA-256)，旧数据 md5
      fileHash256: parseModelString(json["file_hash256"] ?? json["md5"]),
      name: parseModelString(json["name"]),
      uri: parseModelString(json["uri"]),
      size: parseModelInt(json["size"]),
      width: parseModelInt(json["width"]),
      height: parseModelInt(json["height"]),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["file_hash256"] = fileHash256;
    data["name"] = name;
    data["uri"] = uri;
    data["size"] = size;
    data["width"] = width;
    data["height"] = height;
    return data;
  }
}
