import 'package:flutter/foundation.dart';

class StringHelper {
  ///
  /// Splits the given String [s] in chunks with the given [chunkSize].
  ///
  static List<String> chunk(String s, int chunkSize) {
    var chunked = <String>[];
    for (var i = 0; i < s.length; i += chunkSize) {
      var end = (i + chunkSize < s.length) ? i + chunkSize : s.length;
      chunked.add(s.substring(i, end));
    }
    return chunked;
  }

  static String ext(String url) {
    String ext = '';
    debugPrint("StringHelper_ext url $url");
    if (url.isNotEmpty && url.lastIndexOf(".") != -1) {
      Uri u1 = Uri.dataFromString(url);
      ext = u1.path.substring(
          u1.path.lastIndexOf(".") + 1,
          u1.path.lastIndexOf("?") > 0
              ? u1.path.lastIndexOf("?")
              : u1.path.length);
    }
    if (ext.toUpperCase() == 'JPG') {
      ext = 'JPEG';
    }
    debugPrint("StringHelper_ext ext $ext");
    return ext;
  }
}
