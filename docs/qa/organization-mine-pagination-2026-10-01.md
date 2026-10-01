# 企业选择列表的完整分页 — 2026-10-01

English summary: Organization selectors, home, entry cards and directory switching now consume every membership page through one API helper. Overlapping IDs converge, later-page failures remain retryable, and account changes discard an incomplete batch.

本轮对应完整合同 UX-01 的局部缺口，基础 App HEAD `3745b161452c477b5f7ebaa543179e28760f1cc9`。计划、源码和日志 SHA256 见 [证据清单](./evidence/organization-mine-pagination-2026-10-01/sha256.json)，不把三端或六项目标标为完成。

原企业选择器/首页只调用默认 size=10 的 mine 首页；入口卡与通讯录切换只读 size=100 首页。后端返回 total_page，客户端未继续读取，目标企业会缺席，目录的资格重核验也会误认为后续页目标不在企业列表。新增测试在修改前两个失败：仅发第一页请求，后续页失败却被伪装为完整成功。

复用既有 OrganizationApi.mine，新增 allMine 顺序读取第一页声明的全部页，每页请求 size=100。ID 使用 EntityId Map 收敛重叠，同 ID 后页更新字段；只有全部成功才返回列表。五个既有入口改为共用该方法，不新增导航入口或依赖。读取开始绑定当前账号，每页结束重核验账号，账号变化抛错并停止后续页，不返回混合账号企业集合。目录切换的 prepare/commit、企业身份资格与工作空间逻辑继续使用现有实现。

验证命令：

```sh
flutter test --no-pub test/organization/organization_mine_pagination_test.dart test/organization/organization_api_contract_test.dart test/organization/organization_picker_page_widget_test.dart test/organization/organization_home_page_widget_test.dart test/organization/organization_entry_card_test.dart test/organization/human_directory_page_widget_test.dart
flutter analyze --no-pub lib/modules/organization/infrastructure/organization_api.dart lib/modules/organization/presentation/organization_picker_page.dart lib/modules/organization/presentation/organization_home_page.dart lib/modules/organization/presentation/organization_entry_provider.dart lib/modules/organization/presentation/human_directory_org_switch_sheet.dart lib/modules/organization/presentation/human_directory_page.dart test/organization/organization_mine_pagination_test.dart
```

两命令均退出 0；56 项测试通过，7 个改动文件静态检查无问题。新增三项覆盖 11 个企业跨页、重叠 ID、后页失败/重试和中途换账号停止请求。既有测试覆盖选择/加入/默认工作空间、主页与目录的换账号/失权边界。手工检查所有 Organization mine 展示/资格调用，不将 WorkspaceApi.mine 混改；未运行独立审查代理。初次分析提示新增测试两处 if 缺大括号，修正后当前文件复验通过。

结果是客户端 API 替身及 widget 证据，未运行真实后端联合旅程或真机，不据此证明大字号/暗色/所有 scope 功能。后端分页期间数据变动仍受既有 offset 合同限制，本轮去重不宣称列表快照隔离。没有推送、部署、生产迁移或对外通知。
