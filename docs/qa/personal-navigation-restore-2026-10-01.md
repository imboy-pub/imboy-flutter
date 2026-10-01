# 个人导航位置恢复与账号隔离

状态：本地专项 PASS；六项目标仍为 PARTIAL。

手机底部导航 Provider 原为自动销毁，切入企业首页后会失去个人标签；重新挂载又将没有 index 参数的路由默认落在消息页。现在保留已有导航 Provider，并按当前账号 UID 重建；返回个人页时以它的标签作为初始值，显式路由 index 仍优先，非法值与越界继续归一化。页面监听状态变更同步 PageController，账号重置时导航和内容保持一致。

桌面导航本来常驻，但缺少账号隔离。现在同样只监听 UID：资料更新保留标签与选中项，换账号或退出则回到消息且清空选中项。不新增持久化存储、历史页面缓存或第二套导航模型。

69 项相关检查通过，改动文件静态检查无问题。新增检查使用真实 Riverpod Provider 生命周期：关闭页面订阅后状态保留；同 UID 昵称变化不重置；换 UID 与退出重置。手机测试子类只替代设置标签的 WebSocket 副作用，实际 build 与生成的 Provider 生命周期保留。桌面同时检查选中联系人不跨账号继承。路由解析检查缺省标签、显式覆盖、非法值与标签数量变化时的越界归一。

代码生成首次使用独立 Dart SDK 因 Flutter 依赖停止；改用 Flutter 后，输出过滤导致其他生成文件被删除。确认是本次生成造成的变化后逐文件恢复为本次基线，仅保留底部导航对应的生成文件。两轮失败均不作为通过证据；恢复后重新完整验证。

```sh
flutter test --no-pub test/unit_test/page/bottom_navigation/bottom_navigation_page_test.dart test/unit_test/page/web_shell/web_shell_provider_test.dart test/unit_test/page/chat_shell/chat_shell_page_test.dart test/unit_test/page/chat_shell/chat_shell_bootstrap_test.dart test/organization/organization_picker_page_widget_test.dart
flutter analyze --no-pub lib/page/bottom_navigation/bottom_navigation_page.dart lib/page/bottom_navigation/bottom_navigation_provider.dart lib/page/web_shell/web_shell_provider.dart test/unit_test/page/bottom_navigation/bottom_navigation_page_test.dart test/unit_test/page/web_shell/web_shell_provider_test.dart
```

证据目录：`evidence/personal-navigation-restore-2026-10-01`。Provider 与路由解析检查不是实际手机首页的完整挂载或真机企业往返证明；企业标签恢复、列表滚动位置、真实 OA、设备及投产验证仍未完成。
