# 空间布局偏好保存一致性

状态：本地专项 PASS；六项交付目标仍为 PARTIAL。

基线 a5b8272a 的 ProductExperienceNotifier 在保存完成前发布新布局，忽略 SharedPreferences 保存/删除返回的 false；同一时刻连续选择也可能因读取旧状态直接跳过后一次操作。既有插件会先改内存偏好缓存，再调用平台写入，异常时只恢复 Riverpod 状态不足以恢复下一次读取结果。

失败检查通过已安装 SharedPreferences 的平台接口注入 false，原函数正常返回，预期失败的断言不成立。修复复用现有插件和存储入口：保存/删除必须返回 true 才更新界面；失败时重新加载已持久化偏好，错误向上传递；保存与恢复默认值按用户操作顺序执行，失败不阻塞下一次重试。明确选择当前默认布局也保存覆盖值，使后续部署默认值不能覆盖用户选择。

平台接口检查覆盖保存和删除的 false / 异常共四种故障，验证界面无新状态发布、缓存与合成持久层保持原值、恢复正常后可重试；延迟保存期间不切布局；连续切换及保存后恢复默认值的落盘顺序正确；默认布局的明确选择在新 ProviderContainer 中保持。此检查使用插件平台接口合成持久层，不是操作系统存储或设备故障证明；若重读本身失败，错误仍向上传递，不认定恢复成功。

51 项相关测试通过，两个改动文件静态检查无问题。范围包括布局偏好、企业选择器、企业底栏/OA 条件入口、账户面板滚动和退出确认。本修改不代表个人进入企业的完整导航、真实 OA Cookie 清理或真机旅程已完成。

```sh
flutter test --no-pub test/unit_test/page/chat_shell/experience_provider_test.dart test/organization/organization_picker_page_widget_test.dart test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart test/unit_test/page/workspace_shell/workspace_account_menu_scroll_test.dart test/unit_test/page/workspace_shell/workspace_account_menu_logout_test.dart
flutter analyze --no-pub lib/page/chat_shell/experience_provider.dart test/unit_test/page/chat_shell/experience_provider_test.dart
```

运行日志、失败基线和源码摘要：`evidence/layout-preference-persistence-2026-10-01`。没有修改插件、引入依赖、访问真实 OA 或执行生产操作。
