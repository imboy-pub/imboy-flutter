/// Web 语义按钮键盘激活桥（DEF-A11YNEW-01，仅 Web 平台编译）。
///
/// 根因：Flutter web 引擎的语义层只把 DOM `click` 事件转成 SemanticsAction.tap
/// （引擎 `_engine/engine/semantics/tappable.dart` 的 `Tappable` 仅注册
/// `click` 监听）。Chromium 对 `role=button` 的 `<flt-semantics>` 自定义元素
/// 只在 Space keyup 时合成 click，Enter 无任何默认激活行为 → 键盘用户
/// Tab 到语义按钮后按 Enter 无反应（收据探针：Space 导航成功、Enter 无导航），
/// 违反 WCAG 2.1.1「Enter=按钮激活」惯例，且登录入口即受阻。
///
/// 修复：在 document 上补一层 keydown 监听，当 DOM 焦点落在引擎标记为可点按
/// 的语义节点（`flt-semantics[flt-tappable]`，该属性由引擎 `Tappable.update`
/// 挂上、仅在语义启用且节点启用时存在）且按下 Enter 时，代为派发一次合成
/// click，让引擎既有链路（`ClickDebouncer.onClick` → SemanticsAction.tap →
/// 框架 onTap）激活按钮。修复后 Enter/Space/鼠标点击三向同效。
///
/// 守卫（避免双激活/误激活）：
/// - 仅处理 `Enter`：Space 已有浏览器默认合成 click，再派发会双激活；
/// - `event.defaultPrevented` 为真时跳过：框架（FocusManager/快捷键）已消费
///   该 Enter（如框架焦点内的按钮自身激活路径），不再叠加语义 tap；
/// - 仅当 `document.activeElement` 是带 `flt-tappable` 的元素才派发：文本框
///   （`<input>`）、滑块（`<input type=range>`）等原生控件焦点态不受影响；
///   语义未启用时 DOM 中不存在该属性，本桥整体为 no-op；
/// - 禁用态按钮引擎不挂 `flt-tappable`（`Tappable.update` 的 `shouldListen`
///   为 false），天然不会被激活。
///
/// 接线：`run.dart` 的 kIsWeb 分支启动期调用一次（语义可稍后由用户 Tab/读屏
/// 激活，监听器常驻成本为一次 keydown 冒泡判断）。
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 安装 Enter→click 激活桥（幂等：run 只调用一次）。
void installWebSemanticsKeyboardActivation() {
  // 与 visibility_observer_web.dart 同款形态：Dart 闭包经 .toJS 显式转
  // JSFunction（package:web 的 EventListener 参数类型即 JSFunction）。
  final listener = ((web.Event e) {
    final event = e as web.KeyboardEvent;
    // DOM 规范中主键盘与数字小键盘 Enter 的 key 值均为 'Enter'。
    if (!event.defaultPrevented && event.key == 'Enter') {
      final target = web.document.activeElement;
      if (target is web.Element && target.hasAttribute('flt-tappable')) {
        // 合成 click 交给引擎 Tappable：与真实鼠标点击走完全相同的
        // ClickDebouncer → SemanticsAction.tap 分发路径。
        target.dispatchEvent(
          web.MouseEvent(
            'click',
            web.MouseEventInit(
              bubbles: true,
              cancelable: true,
              view: web.window,
            ),
          ),
        );
      }
    }
  }).toJS;
  web.document.addEventListener('keydown', listener);
}
