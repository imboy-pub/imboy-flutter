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

  /// Assets.authData()
  static Map<String, dynamic> authData() {
    int v = DateTimeHelper.second();
    // md5(a + v)

    // 检查 uploadKey 是否为空
    final uploadKey = Env.uploadKey;
    if (uploadKey == null || uploadKey.isEmpty) {
      iPrint('AssetsService.authData: uploadKey is null or empty, triggering refresh');
      // 触发异步刷新配置
      _refreshUploadKey();
      return {'v': v, 'a': '', 's': Env.uploadScene ?? '', 'needRefresh': true};
    }

    String tk = EncrypterService.md5("$uploadKey$v").substring(8, 24);
    // iPrint("AssetsService_authData ${Env.uploadKey} $v");
    return {'v': v, 'a': tk, 's': Env.uploadScene ?? ''};
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
        iPrint('AssetsService._refreshUploadKey: Failed to refresh - ${result['error']}');
        // 配置刷新失败，可能需要重新登录
        // 这里可以通过事件总线通知需要重新登录
        return;
      }

      iPrint('AssetsService._refreshUploadKey: Successfully refreshed uploadKey');
    } catch (e, s) {
      iPrint('AssetsService._refreshUploadKey: Error - $e; $s');
    }
  }

  /// 检查并确保 uploadKey 可用
  /// 返回 true 表示 uploadKey 可用，false 表示需要处理（如重新登录）
  static bool ensureUploadKeyAvailable() {
    final uploadKey = Env.uploadKey;
    if (uploadKey == null || uploadKey.isEmpty) {
      iPrint('AssetsService.ensureUploadKeyAvailable: uploadKey not available');
      _refreshUploadKey();
      return false;
    }
    return true;
  }

  /// 获取URL地址的 v 参数，和当前时间做比较，再决定是否重新生成授权令牌
  /// Assets.viewUrl
  static Uri viewUrl(String url) {
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
