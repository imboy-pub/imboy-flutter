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
class AppLoading {
  const AppLoading._();

  /// 挂载到 MaterialApp.builder。见 run.dart。
  static TransitionBuilder init({TransitionBuilder? builder}) =>
      el.EasyLoading.init(builder: builder);

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
