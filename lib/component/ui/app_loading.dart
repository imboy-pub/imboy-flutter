import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart' as el;

/// 应用内 Loading / Toast 统一入口。
///
/// 这是**唯一**允许 import flutter_easyloading 的业务文件——page / modules /
/// service / store 一律通过 [AppLoading] 调用，第三方依赖收敛于此一处。
/// 边界门禁据此禁止其它文件直接 import flutter_easyloading。
///
/// 未来若要替换底层实现（自研 overlay 或换库），只改本文件，调用点零改动。
///
/// ponytail: 薄 facade，零抽象接口——单一实现不套 interface（YAGNI）。
/// 上限——全静态方法 + 方法签名直接沿用 EasyLoading 的形状（status/duration
/// 语义也是它的），所以换实现时"只改本文件"要看新实现能否照单接住这套语义；
/// 另外静态方法不可注入，widget 测试里没法替换成无 UI 的假实现。
/// 升级触发——真的需要两个实现同时存在时才抽 interface：典型是测试要 fake 掉
/// loading（当前 499 处调用在测试中都会真的走 EasyLoading），或按平台分叉 UI。
class AppLoading {
  const AppLoading._();

  // 使用 GlobalKey 确保 EasyLoading 宿主 Widget 在整个生命周期中（包括热重载和打开 Flutter Inspector）
  // 保持状态与 Element 实例的唯一性，从而避免 "EasyLoading supports one active Host" 重复挂载报错。
  static final GlobalKey _easyLoadingKey = GlobalKey(
    debugLabel: 'AppEasyLoadingKey',
  );

  static Widget _defaultInit(BuildContext context, Widget? child) {
    return el.FlutterEasyLoading(key: _easyLoadingKey, child: child);
  }

  /// 挂载到 MaterialApp.builder。见 run.dart。
  static TransitionBuilder init({TransitionBuilder? builder}) {
    if (builder == null) {
      return _defaultInit;
    }
    return (BuildContext context, Widget? child) {
      final host = el.FlutterEasyLoading(key: _easyLoadingKey, child: child);
      return builder(context, host);
    };
  }

  static Future<void> show({String? status}) =>
      el.EasyLoading.show(status: status);

  static Future<void> showProgress(double value, {String? status}) =>
      el.EasyLoading.showProgress(value, status: status);

  static Future<void> showSuccess(String status, {Duration? duration}) =>
      el.EasyLoading.showSuccess(status, duration: duration);

  static Future<void> showError(String status, {Duration? duration}) =>
      el.EasyLoading.showError(status, duration: duration);

  static Future<void> showInfo(String status, {Duration? duration}) =>
      el.EasyLoading.showInfo(status, duration: duration);

  static Future<void> showToast(String status, {Duration? duration}) =>
      el.EasyLoading.showToast(status, duration: duration);

  static Future<void> dismiss({bool animation = true}) =>
      el.EasyLoading.dismiss(animation: animation);
}
