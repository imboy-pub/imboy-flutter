# `page/channel/channel_admin_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_admin_page.dart` | 管理员列表加载与骨架屏渲染 | 已通过 | 批次39 | 0 | 0 | 0 | 真机：创建者(117)+IMBoy 管理员两行渲染，角色·时间·徽标齐全；ShimmerList 骨架屏代码确认 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 加载失败态展示与点击重试 | 已通过 | 批次39 | 0 | 0 | 0 | 代码确认 NoDataView(error_outline)+onTop:_loadAdmins 重试 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 无管理员时空态渲染 | 已通过 | 批次84 | 0 | 0 | 0 | 08-14 真机三频道实锤空态渲染正常；原「创建者恒在列表」备注被推翻：生产表无创建者行（见行18 阻塞） |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 添加入口打开选人弹层并过滤已有管理员 | 已通过 | 批次39 | 0 | 0 | 0 | 真机：弹层打开仅 automation-buddy/leeyi 可选手；自己(uid117)与已添加的 IMBoy(51698) 被过滤 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 选人弹层搜索按昵称账号过滤 | 已通过 | 批次39 | 0 | 0 | 0 | 真机搜索过滤正常 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 选人后角色选择弹窗编辑者与管理员 | 已通过 | 批次39 | 0 | 0 | 0 | 真机角色弹窗两选项渲染，选管理员提交成功 |
| 无待办 | - | `page/channel/channel_admin_page.dart` | 添加管理员成功失败提示与列表刷新 | 已通过 | 批次39 | 0 | 0 | 0 | 真机：IMBoy 添加为管理员(role=2)后列表即时刷新显示；测试数据待清理 |
| 阻塞 | 需第二账号订阅测试频道并被设为管理员 | `page/channel/channel_admin_page.dart` | 修改角色弹窗回显当前角色勾选 | 待重验 | 批次39 | 0 | 0 | 0 | APK 已含 BUG#126 修复 fb17acdb(04-15 早于 08-14 装机)；08-14 真机实查 uid50 全部管理频道管理员列表均空(批次39 测试数据已被清理)、订阅者 0 无从构造，弹窗回显链路不可达；待第二账号配合构造管理员数据后复验 |
| 阻塞 | 需第二账号订阅测试频道并被设为管理员 | `page/channel/channel_admin_page.dart` | 修改角色提交结果提示与刷新 | 待重验 | 批次39 | 0 | 0 | 0 | APK 条件已满足；08-14 真机实查 uid50 全部管理频道管理员列表均空(批次39 测试数据已被清理)、订阅者 0 无从新加，修改角色链路真机不可达；后端 update_admin_role TargetRole<Role 校验代码已确认；待第二账号配合构造管理员数据后复验 |
| 阻塞 | 需第二账号订阅测试频道并被设为管理员 | `page/channel/channel_admin_page.dart` | 移除管理员确认弹窗与结果提示 | 待重验 | 批次39 | 0 | 0 | 0 | 08-14 真机实查：uid50 全部管理频道(qa-batch39/84/67 等)管理员列表均空(批次39 所加 IMBoy 管理员已被清理)，订阅者 0 无从新加，IMBoy 频道本账号无管理权限；移除链路真机不可达，待第二账号配合构造管理员数据后复验 |
| 阻塞 | 需生产后端部署含创建者行写入的版本 | `page/channel/channel_admin_page.dart` | 创建者行显示角色徽标且无操作菜单 | 待重验 | - | 1 | 1 | 0 | 08-14 真机：新建频道 qa-batch84-admin(106933346608875520) 管理员列表仍空，生产创建频道未写创建者行（本地 channel_ds.erl 事务写入已含于 alpha.26）→ 徽标分支真机不可达；APK 已含 fb17acdb+6/6 单测；非回归系缺外部条件转阻塞，待后端部署后复测 |
