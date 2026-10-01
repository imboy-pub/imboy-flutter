# 员工组织目录的宽屏分栏与层级路径 — 2026-10-01

English summary: Human organization directory uses department/member panes on wide screens and one list on phones. Native ancestor buttons support direct navigation back without fetching an entire organizational tree. Existing membership, pagination and revocation state remain authoritative.

本轮对应完整合同 UX-03 的局部实现，App 基础 `3b979e8ebe5add98abadf0e7cf7f9b0f8653d4e7`；计划、最终源码与日志 SHA256 见 [证据清单](./evidence/human-directory-layout-2026-10-01/sha256.json)。

复用既有 900px 壳断点，以实际内容可用宽度判定：宽屏左侧组织路径/我的部门/子部门，右侧本级成员；手机维持单列，进入部门后显示路径。路径用原生 CupertinoButton，至少 44pt，长名称截断、路径换行，父层级可直接点击返回，当前层不可重复提交。系统返回与路径共用 _openLevel；沿用原 controller 的 generation、独立分页、搜索清理和失权撤下。部署/API/角色门未变化，不增加一套管理导航或图形依赖。

仅展示已验证的当前层级和路径，未展开全部组织关系图；深链无法取得的祖先不猜测。独立布局文件不持企业身份或数据缓存；本轮没有把部门治理接口暴露给普通成员。

```sh
flutter test --no-pub test/organization/human_directory_page_widget_test.dart test/organization/human_directory_controller_test.dart test/organization/human_directory_access_revocation_test.dart test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart
flutter analyze --no-pub lib/modules/organization/presentation/human_directory_layout.dart lib/modules/organization/presentation/human_directory_page.dart test/organization/human_directory_page_widget_test.dart
```

两命令均退出 0：53 项测试通过，改动文件静态检查无问题。新增宽屏断言验证两个窗格实际横向分开、路径按钮返回企业根、请求作用域及最小热区；400/1200 宽、浅/深主题、双倍字号和长企业名四场景无布局异常。原失权/账号切换/分页/搜索/成员路由与企业壳测试继续通过。基线新增宽屏用例确实失败（原版无窗格），不是构建错误；因新增路径重复展示当前部门，原标题断言按真实 UI 更新为标题和路径两处。

手工检查布局入口与 controller/路径调用、暗色 token、普通成员权限边界；未启动独立审查代理。dart format 和 git diff 检查通过，源文件分别低于 800 行。

这是 widget 与受控数据源证明，未运行真实设备或后端联合旅程，不声称整个组织架构管理、全树关系图或六项目标完成。未推送、部署、生产迁移或对外通知。
