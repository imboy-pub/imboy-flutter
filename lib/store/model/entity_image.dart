class EntityImage {
  final String name, uri;
  final int width, height, size;

  EntityImage({
    required this.name,
    required this.uri,
    this.size = 0,
    this.width = 0,
    this.height = 0,
  });

  factory EntityImage.fromJson(Map<String, dynamic> json) {
    return new EntityImage(
      name: json["name"],
      uri: json["uri"],
      size: json["size"]?.toInt(),
      width: json["width"]?.toInt(),
      height: json["height"]?.toInt(),
    );
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data["name"] = name;
    data["uri"] = uri;
    data["size"] = size;
    data["width"] = width;
    data["height"] = height;
    return data;
  }
}
