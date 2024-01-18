import 'dart:io' show ContentType, HttpHeaders;

import 'package:clock/clock.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/assets.dart';

import 'mime_converter.dart';

const stalePeriod = Duration(days: 30);

class IMBoyCacheManager extends CacheManager {
  static const key = 'imboy_cache_key';

  static final IMBoyCacheManager _instance = IMBoyCacheManager._();

  factory IMBoyCacheManager() {
    return _instance;
  }

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    String? ext,
    Map<String, String>? headers,
  }) async {
    Uri u = AssetsService.viewUrl(url);
    key ??= "${u.scheme}://${u.host}:${u.port}${u.path}";

    final cacheFile = await getFileFromCache(key);
    if (cacheFile != null && cacheFile.validTill.isAfter(DateTime.now())) {
      return cacheFile.file;
    }
    return (await downloadFile(u.toString(), key: key, authHeaders: headers))
        .file;
  }

  IMBoyCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: stalePeriod,
            maxNrOfCacheObjects: 20,
            repo: JsonCacheInfoRepository(databaseName: key),
            // fileSystem: IOFileSystem(key),
            fileService: IMBoyHttpFileService(),
          ),
        );
}

class IMBoyHttpFileService extends FileService {
  final http.Client _httpClient;

  IMBoyHttpFileService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    final req = http.Request('GET', Uri.parse(url));
    if (headers != null) {
      req.headers.addAll(headers);
    }
    String ext = "";

    iPrint("imboy_cache_manager_get url $url");
    if (url.isNotEmpty && url.lastIndexOf(".") != -1) {
      Uri u1 = Uri.dataFromString(url);
      ext = u1.path.substring(
          u1.path.lastIndexOf("."),
          u1.path.lastIndexOf("?") > 0
              ? u1.path.lastIndexOf("?")
              : u1.path.length);
    }
    iPrint("imboy_cache_manager_get ext $ext");
    final httpResponse = await _httpClient.send(req);
    return IMBoyHttpGetResponse(httpResponse, ext: ext);
  }
}

/// Basic implementation of a [FileServiceResponse] for http requests.
class IMBoyHttpGetResponse implements FileServiceResponse {
  IMBoyHttpGetResponse(this._response, {this.ext});

  final DateTime _receivedTime = clock.now();
  final String? ext;
  final http.StreamedResponse _response;

  @override
  int get statusCode => _response.statusCode;

  String? _header(String name) {
    return _response.headers[name];
  }

  @override
  Stream<List<int>> get content => _response.stream;

  @override
  int? get contentLength => _response.contentLength;

  @override
  DateTime get validTill {
    // Without a cache-control header we keep the file for a week
    var ageDuration = stalePeriod;
    final controlHeader = _header(HttpHeaders.cacheControlHeader);
    if (controlHeader != null) {
      final controlSettings = controlHeader.split(',');
      for (final setting in controlSettings) {
        final sanitizedSetting = setting.trim().toLowerCase();
        if (sanitizedSetting == 'no-cache') {
          ageDuration = const Duration();
        }
        if (sanitizedSetting.startsWith('max-age=')) {
          var validSeconds = int.tryParse(sanitizedSetting.split('=')[1]) ?? 0;
          if (validSeconds > 0) {
            ageDuration = Duration(seconds: validSeconds);
          }
        }
      }
    }

    return _receivedTime.add(ageDuration);
  }

  @override
  String? get eTag => _header(HttpHeaders.etagHeader);

  @override
  String get fileExtension {
    if (ext != null) {
      return ext!;
    }
    var fileExtension = '';
    final contentTypeHeader = _header(HttpHeaders.contentTypeHeader);
    if (contentTypeHeader != null) {
      final contentType = ContentType.parse(contentTypeHeader);
      fileExtension = contentType.fileExtension;
    }
    return fileExtension;
  }
}
