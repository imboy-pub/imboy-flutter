# `page/channel/channel_admin_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_admin_page.dart` | 管理员列表加载与骨架屏渲染 | 已通过 | 批次39 | 0 | 0 | 0 | 真机：创建者(117)+IMBoy 管理员两行渲染，角色·时间·徽标齐全；ShimmerList 骨架屏代码确认 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 加载失败态展示与点击重试 | 已通过 | 批次39 | 0 | 0 | 0 | 代码确认 NoDataView(error_outline)+onTop:_loadAdmins 重试 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 无管理员时空态渲染 | 已通过 | 批次84 | 0 | 0 | 0 | 空态组件机制正常（NoDataView admin_panel_settings_outlined）；批次84 备注「生产表无创建者行」系 BUG#135 误判——DB 创建者行一直存在，空态是 admins 端点 403 业务码被客户端静默吞掉所致（见行18 闭环） |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 添加入口打开选人弹层并过滤已有管理员 | 已通过 | 批次39 | 0 | 0 | 0 | 真机：弹层打开仅 automation-buddy/leeyi 可选手；自己(uid117)与已添加的 IMBoy(51698) 被过滤 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 选人弹层搜索按昵称账号过滤 | 已通过 | 批次39 | 0 | 0 | 0 | 真机搜索过滤正常 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 选人后角色选择弹窗编辑者与管理员 | 已通过 | 批次39 | 0 | 0 | 0 | 真机角色弹窗两选项渲染，选管理员提交成功 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 添加管理员成功失败提示与列表刷新 | 已通过 | 批次39 | 0 | 0 | 0 | 真机：IMBoy 添加为管理员(role=2)后列表即时刷新显示；测试数据待清理 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 修改角色弹窗回显当前角色勾选 | 已通过 | 批次103 | 0 | 0 | 0 | 解阻：生产 DB 直插 channel_admin(uid5, role=1) 造数→详情页菜单「管理管理员」→条目尾部…菜单→更改角色→弹窗「编辑/管理员」两选项渲染 get_ui 实测；当前角色勾选 checkmark=L209 `role==currentRole` 代码证实 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 修改角色提交结果提示与刷新 | 已通过 | 批次103 | 0 | 0 | 0 | 同上链路：弹窗点「管理员」→ PUT admin/role → DB role 1→2 实测 + 列表刷新「QA_uid5 编辑→管理员」get_ui 实测；SnackBar 成功提示 L184-189 代码证实（toast 生命周期<1s 截图不可控） |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 移除管理员确认弹窗与结果提示 | 已通过 | 批次103 | 0 | 0 | 0 | 同链路：…菜单→移除管理员→确认弹窗「确定要移除该管理员吗？」+取消/红色确认 get_ui 实测→点确认→DB 行删（count=0）+ 列表仅剩创建者 get_ui 实测；造数已清（uid5 昵称恢复空） |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 创建者行显示角色徽标且无操作菜单 | 已通过 | 批次90 | 1 | 1 | 0 | ⭐BUG#135 全链路闭环：08-14 实测空态真根因=admins 端点权限校验缺陷——创建频道事务只写 channel_admin(role=3) 不写 channel_subscription，创建者 is_subscribed 恒 false → 403 业务码（HTTP 恒 200，89 字节）→ 客户端把无 list 响应静默当空列表；DB 创建者行自创建起一直存在（106933346608875520/uid50/role=3/08-14 11:49:53）。修复 channel_handler_admin.erl admins 权限放宽为「管理员(role>0)或订阅者」（0dd89cb8）+ 回归测试 admins_allows_creator_without_subscription_test_（82/82）；alpha.32 蓝绿部署后真机复验：GET /api/v1/channel/106933346608875520/admins 200 248 字节（此前 89），创建者行渲染「117/创建者·2 天前/创建者」徽标，点击行无操作菜单弹出 |
