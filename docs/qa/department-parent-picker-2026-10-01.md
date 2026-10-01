# 部门移动改为按名称和归属选择 — 2026-10-01

English summary: Department governance now selects the destination by name and ancestor path instead of typing an internal ID. Known descendants and archived destinations are excluded; server CAS and cycle rejection remain authoritative. The organization root is distinct from cancelling.

本轮对应完整合同 UX-03 / ORG-03 的局部 UX 改进。App 基础 `8d3cf6c3c3c8737799bb6d966dbfd73ed89e2826`；计划、当前源文件及日志 SHA256 见 [证据清单](./evidence/department-parent-picker-2026-10-01/sha256.json)。

原「移动（选择新父部门）」实际弹出父部门 ID 输入框。新选择器展示部门名与已知祖先路径，支持企业根目录；当前归属标勾不可重复提交，自身/已知子孙/非 active 部门不出现在目标中。邻接表加 visited 集合遍历子孙，不因异常循环无限处理；未知祖先不猜测归属。目标 EntityId 保留 string，选根返回空字符串，取消返回 null，由既有 API 将根编码为 parent_id=null。移动仍携带原行 expected_version，服务端错误和最新树刷新继续复用 _runCommand。没有新增角色权限、API 或依赖。

普通部门列表去掉内部编号副标题，归档状态保留。删除两个无其他调用的旧翻译键（父 ID 提示、编号副标题）；十种语言补齐根目录标签，再由 dart run slang 生成出站 Dart，未手工修改生成物。原展开图标仅提为短 UI 函数，展开/详情行为保留。

```sh
flutter test --no-pub test/organization/department_parent_picker_test.dart test/organization/organization_departments_page_widget_test.dart test/organization/organization_api_contract_test.dart
flutter analyze --no-pub lib/modules/organization/presentation/department_parent_picker.dart lib/modules/organization/presentation/organization_departments_page.dart test/organization/department_parent_picker_test.dart test/organization/organization_departments_page_widget_test.dart
dart run slang
```

三命令退出 0：37 项测试通过，改动文件静态检查无问题，十种语言生成成功。基线新用例因原版仍有 ID 输入框而真实失败。新增覆盖按名称移动、自身/两级子孙/归档隐藏、选择器打开后真实模拟服务端层级变化的 cycle 拒绝、根选择与取消不同、当前父不可重复点击、大于 JS 安全整数的 ID 无损、400px 明暗主题/双倍字号/长名称及至少 44pt 热区。原管理员 CRUD、成员治理、CAS 以及普通成员隐藏权限入口继续通过。

测试用受控 HTTP adapter 模拟服务端状态，不声称本轮证明真实数据库治理。既有 API move 的 null-parent、CAS 和后端成环裁决没有删除。手工核验调用、翻译引用删除、图标和角色门，未运行独立审查代理；格式与 diff 检查通过。

完整关系图、真实设备/后端联合旅程与六项目标仍未完成；本轮未推送、部署、生产迁移或对外通知。
