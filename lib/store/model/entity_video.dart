class EntityVideo {
  final String md5, name, uri;
  final int width, height;

  /// bytes
  int? filesize; // filesize

  String? author;

  /// microsecond
  double? duration;

  EntityVideo({
    required this.md5,
    required this.name,
    required this.uri,
    // unit Bytes
    this.filesize = 0,
    this.width = 0,
    this.height = 0,
    this.author = '',
    this.duration = 0.0,
  });

  factory EntityVideo.fromJson(Map<String, dynamic> json) {
    return EntityVideo(
      md5: json["md5"],
      name: json["name"],
      uri: json["uri"],
      filesize: json["filesize"]?.toInt(),
      width: json["width"]?.toInt(),
      height: json["height"]?.toInt(),
      duration: double.tryParse('${json['duration']}'),
      author: json['author'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["md5"] = md5;
    data["name"] = name;
    data["uri"] = uri;
    data["filesize"] = filesize;
    data["width"] = width;
    data["height"] = height;
    data["duration"] = duration;
    data["author"] = author;

    return data;
  }
}
