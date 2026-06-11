import 'dart:async';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/user_model.dart';

import 'package:imboy/service/secure_token_storage_service.dart'
    show SecureTokenStorageService;

/// 用户本地数据仓库
/// 负责管理用户登录状态、令牌、用户信息等本地数据
class UserRepoLocal {
  // 私有构造函数，实现单例模式
  UserRepoLocal._();

  // 单例实例
  static final UserRepoLocal _instance = UserRepoLocal._();

  /// 获取单例实例
  static UserRepoLocal get to => _instance;

  String get currentUid => StorageService.to.getString(Keys.currentUid);

  bool get isLoggedIn {
    return currentUid.isNotEmpty;
  }

  //
  UserSettingModel get setting {
    Map<String, dynamic> u = StorageService.getMap(Keys.currentUser);
    return UserSettingModel.fromJson(
      u['setting'] as Map<String, dynamic>? ?? {},
    );
  }

  // 令牌 token
  Future<String> get accessToken async {
    try {
      return await SecureTokenStorageService.getToken();
    } on Object catch (e) {
      // 令牌解密失败，数据已被清除，需要重新登录
      _handleTokenDecryptionFailure();
    }
    return '';
  }

  Future<String> get refreshToken async {
    try {
      return await SecureTokenStorageService.getRefreshToken();
    } on Object catch (e) {
      // 令牌解密失败，数据已被清除，需要重新登录
      _handleTokenDecryptionFailure();
    }
    return '';
  }

  /// 处理令牌解密失败的情况
  /// 当密钥丢失或数据损坏时触发，清除本地数据并引导用户重新登录
  void _handleTokenDecryptionFailure() {
    // 标记需要重新登录，避免在当前会话中重复尝试解密
    StorageService.to.setBool('token_decryption_failed', true);
  }

  /// 检查是否存在令牌解密失败标记
  bool get hasTokenDecryptionFailure {
    return StorageService.to.getBool('token_decryption_failed') ?? false;
  }

  /// 清除令牌解密失败标记
  void clearTokenDecryptionFailureFlag() {
    StorageService.to.remove('token_decryption_failed');
  }

  /// 获取当前用户信息
  ///
  /// 注意：如果用户未登录或数据无效，会抛出异常
  /// 建议使用 [currentUser] getter 来安全地获取用户信息
  ///
  /// 抛出：
  /// - [StateError] 当用户未登录或数据无效时
  UserModel get current {
    Map<String, dynamic> user = StorageService.getMap(Keys.currentUser);
    // iPrint("current user ${user.toString()}");
    if (user.isEmpty) {
      // 不再在这里执行导航，由调用方处理
      // WebSocketService.to.closeSocket(permanent: true);
      // Get.offAll(() => const LoginPage());
      throw StateError('User not logged in or user data is empty');
    }
    return UserModel.fromJson(user);
  }

  /// 安全地获取当前用户信息
  ///
  /// 如果用户未登录或数据无效，返回 null
  /// 调用方需要处理 null 情况并执行相应的导航逻辑
  UserModel? get currentUser {
    Map<String, dynamic> user = StorageService.getMap(Keys.currentUser);
    if (user.isEmpty) {
      return null;
    }
    return UserModel.fromJson(user);
  }

  String get lastLoginAccount =>
      StorageService.to.getString(Keys.lastLoginAccount);

  /// Token 验证相关常量
  static const int _minTokenLength = 10;

  /// 验证登录响应 payload 中的必需字段
  ///
  /// 验证规则：
  /// - uid 不能为空
  /// - token 不能为空且长度必须大于 10（基本的 JWT 长度检查）
  /// - refreshtoken 不能为空
  ///
  /// 抛出 [ArgumentError] 当任何必需字段无效时
  void validateLoginPayload(Map<String, dynamic> payload) {
    // 验证 uid
    _validateUid(payload['uid']);

    // 验证 token
    _validateToken(payload['token']);

    // 验证 refreshtoken
    _validateRefreshToken(payload['refreshtoken']);

    final uid = payload['uid'];
  }

  /// 验证 uid 字段
  void _validateUid(dynamic uid) {
    if (uid == null || uid.toString().isEmpty) {
      throw ArgumentError('登录响应缺少有效的 uid 字段');
    }
  }

  /// 验证 token 字段
  void _validateToken(dynamic token) {
    if (token == null ||
        token is! String ||
        token.trim().isEmpty ||
        token.length < _minTokenLength) {
      // 安全考虑：不在日志中记录敏感 token 值
      throw ArgumentError(
        '登录响应包含无效的 token 字段: token 不能为空且长度必须大于 $_minTokenLength',
      );
    }
  }

  /// 验证 refreshtoken 字段
  void _validateRefreshToken(dynamic refreshToken) {
    if (refreshToken == null ||
        refreshToken is! String ||
        refreshToken.trim().isEmpty) {
      throw ArgumentError('登录响应包含无效的 refreshtoken 字段');
    }
  }

  Future<bool> changeSetting(UserSettingModel setting) async {
    Map<String, dynamic> u = StorageService.getMap(Keys.currentUser);
    u['setting'] = setting.toMap();
    await StorageService.setMap(Keys.currentUser, u);
    return true;
  }

  Future<bool> changeInfo(Map<String, dynamic> payload) async {
    await StorageService.setMap(Keys.currentUser, payload);
    return true;
  }

  Future<bool> loginAfter(String account, Map<String, dynamic> payload) async {
    // 验证必需字段
    validateLoginPayload(payload);

    StorageService.to.setString(Keys.lastLoginAccount, account);
    List<String>? li = StorageService.to.getStringList(Keys.loginHistory);
    if (li == null) {
      li = [account];
      unawaited(StorageService.to.setList(Keys.loginHistory, li));
    } else {
      // 移除已存在的账号（如果有），然后插入到最前面
      li.remove(account);
      li.insert(0, account);
      unawaited(StorageService.to.setList(Keys.loginHistory, li));
    }

    await StorageService.to.setString(
      Keys.currentUid,
      payload['uid'].toString(),
    );

    await SecureTokenStorageService.saveToken(payload['token'] as String);
    await SecureTokenStorageService.saveRefreshToken(
      payload['refreshtoken'] as String,
    );

    payload.remove('token');
    payload.remove('refreshtoken');

    // await StorageService.to.setString(Keys.currentUid, payload['uid']);
    await StorageService.setMap(Keys.currentUser, payload);
    SqliteService.to.db;
    // 初始化 WebSocket 链接
    // 检查WS链接状
    WebSocketService.to;

    // https://github.com/jpush/jpush-flutter-plugin/blob/master/documents/APIs.md
    // 获取 registrationId，这个 JPush 运行通过 registrationId 来进行推送.
    // push.getRegistrationID().then((rid) {
    //   debugPrint("push registrationId $rid");
    // });
    // 设置别名，极光后台可以通过别名来推送，一个 App 应用只有一个别名，一般用来存储用户 id。
    /*
    if (Platform.isAndroid) {
      await push.setAlias(payload['uid']);
    }
    */
    return true;
  }

  Future<bool> quitLogin() async {
    try {
      iPrint("> quitLogin: Starting logout process");
      if (to.isLoggedIn) {
        iPrint("> quitLogin: User is logged in");
        //WebSocketService.to.sendMessage("logout");
      } else {
        iPrint("> quitLogin: User is not logged in");
      }

      iPrint("> quitLogin: Removing storage data");
      await StorageService.to.remove(Keys.currentUid);
      await StorageService.to.remove(Keys.wsUrl);
      await StorageService.to.remove(Keys.uploadUrl);
      await StorageService.to.remove(Keys.uploadKey);
      await StorageService.to.remove(Keys.uploadScene);

      iPrint("> quitLogin: Clearing E2EE cache");
      // 清理E2EE设备密钥缓存，确保重新登录后获取最新密钥
      try {
        E2EEService.clearCache();
        iPrint("> quitLogin: E2EE cache cleared");
      } on Object catch (e) {}

      iPrint("> quitLogin: Clearing secure tokens");
      try {
        await SecureTokenStorageService.clear();
        iPrint("> quitLogin: Secure tokens cleared successfully");
      } on Object catch (e) {
        // FlutterKeychain 不支持 macos
      }

      iPrint("> quitLogin: Closing WebSocket");
      await WebSocketService.to.closeSocket(permanent: true);
      iPrint("> quitLogin: Closing database");
      SqliteService.to.close();
      iPrint("> quitLogin: Logout process completed successfully");
      return true;
    } on Object catch (e) {
      return false;
    }
  }
}
