import 'dart:io';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:mime/mime.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'encrypter.dart';

class AssetsService {
  static Future<String?> mimeType(File file) async {
    String? mimeType = lookupMimeType(file.path);
    if (mimeType == null) {
      var dataHeader = await file.readAsBytes();
      mimeType = lookupMimeType(file.path, headerBytes: dataHeader);
    }
    return mimeType;
  }

  static String getImgPath(String name, {String format = 'png'}) {
    return 'assets/images/$name.$format';
  }

  /// Assets.authData() — uses in-memory cache populated by Env.getUploadKey()
  static Map<String, dynamic> authData() {
    int v = DateTimeHelper.second();
    // md5(a + v)

    // H8: read from in-memory cache only (populated from secure storage)
    final uploadKey = Env.uploadKeySync;
    if (uploadKey == null || uploadKey.isEmpty) {
      iPrint('AssetsService.authData: uploadKey is null or empty');
      // 返回空签名，调用方应检查 needRefresh 并等待刷新后重试
      return {'v': v, 'a': '', 's': Env.uploadScene ?? '', 'needRefresh': true};
    }

    String tk = EncrypterService.md5("$uploadKey$v").substring(8, 24);
    return {'v': v, 'a': tk, 's': Env.uploadScene ?? ''};
  }

  /// 同步版本：确保 uploadKey 可用后再生成签名
  /// 如果 uploadKey 为空，先等待刷新完成
  static Future<Map<String, dynamic>> authDataAsync() async {
    var data = authData();
    if (data['needRefresh'] == true) {
      await _refreshUploadKey();
      data = authData();
    }
    return data;
  }

  /// 异步刷新 uploadKey
  /// 当检测到 uploadKey 为空时调用
  static Future<void> _refreshUploadKey() async {
    try {
      // 检查用户是否已登录
      if (!UserRepoLocal.to.isLoggedIn) {
        iPrint('AssetsService._refreshUploadKey: User not logged in');
        return;
      }

      iPrint('AssetsService._refreshUploadKey: Attempting to refresh config');
      final result = await AppInitializer.initConfig();

      if (result.containsKey('error')) {
        iPrint(
          'AssetsService._refreshUploadKey: Failed to refresh - ${result['error']}',
        );
        // 配置刷新失败，可能需要重新登录
        // 这里可以通过事件总线通知需要重新登录
        return;
      }

      iPrint(
        'AssetsService._refreshUploadKey: Successfully refreshed uploadKey',
      );
    } catch (e, s) {
      iPrint('AssetsService._refreshUploadKey: Error - $e; $s');
    }
  }

  /// 检查并确保 uploadKey 可用
  /// 返回 true 表示 uploadKey 可用，false 表示需要处理（如重新登录）
  static bool ensureUploadKeyAvailable() {
    final uploadKey = Env.uploadKeySync;
    if (uploadKey == null || uploadKey.isEmpty) {
      iPrint('AssetsService.ensureUploadKeyAvailable: uploadKey not available');
      _refreshUploadKey();
      return false;
    }
    return true;
  }

  /// Garage presign object_key 形态：`u<uid>/file_<ts>_<hex>/<name>`。
  /// 用于区分新链路 object_key 与旧 go-fastdfs 完整 URL（带 http scheme）。
  static final RegExp _objectKeyReg = RegExp(r'^u\d+/');

  /// 判断 [input] 是否为 Garage presign object_key（而非 go-fastdfs 完整 URL）。
  ///
  /// 规则：非空、不含 `://`（无 scheme）、且以 `u<digits>/` 开头。
  static bool isObjectKey(String input) {
    if (input.isEmpty) return false;
    if (input.contains('://')) return false;
    return _objectKeyReg.hasMatch(input);
  }

  /// 获取URL地址的 v 参数，和当前时间做比较，再决定是否重新生成授权令牌
  /// Assets.viewUrl
  /// 异步版本：当 uploadKey 可能为空时使用
  /// 先确保 uploadKey 已加载，再生成带签名的 URL
  static Future<Uri> viewUrlAsync(String url) async {
    if (isObjectKey(url)) {
      return Uri(path: url);
    }
    int now = DateTimeHelper.second();
    int diff = 3600;

    Uri u = Uri.parse(url);

    int v = 0;
    final vParam = u.queryParameters['v'];
    if (vParam != null && vParam.isNotEmpty) {
      v = int.tryParse(vParam) ?? 0;
    }

    if (v > 0 && now < (v + diff)) {
      return u;
    }

    final data = await authDataAsync();
    Map<String, String> q = Map<String, String>.from(u.queryParameters)
      ..addAll({
        's': data['s']?.toString() ?? '',
        'a': data['a']?.toString() ?? '',
        'v': data['v'].toString(),
      });
    return Uri(
      scheme: u.scheme,
      host: u.host,
      path: u.path,
      port: u.port,
      queryParameters: q,
    );
  }

  static Uri viewUrl(String url) {
    // Garage object_key：同步层不解析，原样透传给 async 下载边界
    // （IMBoyCacheManager / AssetUrlResolver）换取短时 presigned URL。
    if (isObjectKey(url)) {
      return Uri(path: url);
    }
    int now = DateTimeHelper.second();
    int diff = 3600; // 1hour

    // Map<String, dynamic> cache = {};
    // 从服务器去授权码，缓存，服务器设定的缓存时间，
    // 判断有授权码，直接设置响应；
    // 否则，通过aes加密方式想服务器请求授权令牌，并且缓存之

    Uri u = Uri.parse(url);

    // 修复：安全解析 v 参数，避免 int.parse("null") 错误
    int v = 0;
    final vParam = u.queryParameters['v'];
    if (vParam != null && vParam.isNotEmpty) {
      v = int.tryParse(vParam) ?? 0;
    }

    // debugPrint("> viewUrl $v if ${v > 0 && now < (v + diff)} | $url ");
    if (v > 0 && now < (v + diff)) {
      return u;
    }
    Map<String, dynamic> data = authData();
    Map<String, String> q = Map<String, String>.from(u.queryParameters)
      ..addAll({
        's': data['s']?.toString() ?? '',
        'a': data['a']?.toString() ?? '',
        'v': data['v'].toString(),
      });
    // debugPrint("viewUrl 2 ${Uri(
    //   scheme: u.scheme,
    //   host: u.host,
    //   path: u.path,
    //   port: u.port,
    //   queryParameters: q,
    // ).toString()}");
    return Uri(
      scheme: u.scheme,
      host: u.host,
      path: u.path,
      port: u.port,
      queryParameters: q,
    );
  }
}
