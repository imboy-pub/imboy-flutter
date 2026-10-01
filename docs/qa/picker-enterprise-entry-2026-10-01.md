# 企业选择器进入首页与保存校验

状态：本地专项 PASS；完整六项目标仍为 PARTIAL。

基线 3ce51cea 的选择器只保存企业指针并落位工作区，没有切换 ProductExperience。真实组件检查选择企业后预期 workspace，实际仍为 chat；点击之前记住的同一家企业还会直接返回，跳过新的成员资格检查。另一个平台接口检查发现企业指针保存返回 false 时仍发布新企业。

选择器现在校验目标企业、加载工作区、保存企业指针并落位目标范围后，通过既有布局偏好入口进入企业首页。相同企业也执行重新校验。布局保存失败时恢复之前的企业指针、工作区及导航目的地，保留错误供重试；默认工作区读取失败沿用共享工作区逻辑，只从目标企业已加入的工作区回退。

StorageService 增加一个共享的严格偏好写入入口，复用现有插件：返回 true 才成功；false 或异常时重新读取持久层并向调用方报错。布局偏好和企业指针均调用它，删除布局模块内重复实现，避免同类失败在不同入口产生不同结果。普通存储方法的返回协议保持兼容。

90 项相关测试通过，六个改动文件静态检查无问题。新增证据：

- 从个人选择另一家企业后，布局为 workspace，企业和工作区一致。
- 选择之前记住的企业仍访问 detail 校验，并切入企业首页。
- 默认工作区读取 503 时成功落在目标企业的已加入工作区。
- 布局保存异常时恢复原企业、工作区和 chat 布局，显示切换错误。
- 企业指针保存 false / 异常均拒绝发布新企业，缓存重新读取旧值。

测试使用已有 Widget/Dio 合成响应与插件平台接口，不是操作系统存储故障或真机旅程证明。第一次新增场景在测试前置加载等待真实主题请求，进程确认仍运行后终止；这轮不算通过证据。工作区夹具明确提供主题响应后重新完整验证。

尚未证明全局个人顶部入口、页面退出/账号切换期间的完整恢复、补偿写本身失败时的持久状态、无可用工作区的企业首页以及真实 OA/设备端清理。不得据此认定 UX-01 或整体投产资格全部完成。

```sh
flutter test --no-pub test/organization/organization_picker_page_widget_test.dart test/organization/current_organization_store_test.dart test/organization/current_organization_store_uninitialized_test.dart test/unit_test/page/chat_shell/experience_provider_test.dart test/unit_test/page/workspace_shell/workspace_organization_selection_test.dart test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart test/organization/human_directory_page_widget_test.dart
flutter analyze --no-pub lib/service/storage.dart lib/page/chat_shell/experience_provider.dart lib/modules/organization/infrastructure/current_organization_store.dart lib/modules/organization/presentation/organization_picker_page.dart test/organization/organization_picker_page_widget_test.dart test/unit_test/page/chat_shell/experience_provider_test.dart
```

运行记录和源码摘要：`evidence/picker-enterprise-entry-2026-10-01`。未新增依赖、发布、部署或访问真实 OA。
