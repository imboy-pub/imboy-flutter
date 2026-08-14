# `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart`

> 功能点 11 个 | bug 发现 6 / 解决 5 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 标题显示标签名与成员计数 | 已通过 | §二十七 | 2 | 1 | 1 | 批次72：标签改名后本页标题仍显旧名（需退出重进才刷新），UI 未闭环待处理 |
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 吸顶字母分组头无障碍可见 | 已通过 | §二十七 | 1 | 1 | 0 | |
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 右侧索引条拖动定位到字母组 | 已通过 | 批次32 | 0 | 0 | 0 | 拖动无异常列表正常；2成员数据量无法目视滚动定位 |
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 搜索框输入过滤标签内成员 | 已通过 | 批次32 | 0 | 0 | 0 | 过滤与重拉机制真机验证；命中依赖 friend_ds %kwd% 修复上线（已修未发布） |
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 点清空图标重置搜索结果 | 已通过 | 批次32 | 0 | 0 | 0 | 输入后 xmark 出现；点清除触发 doSearch('') 列表恢复完整 2 成员 |
| 无待办 | - | ``page/user_tag/contact_tag_detail/contact_tag_detail_page.dart`` | 点加号进入选择好友页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 左滑移除成员弹出二次确认 | 已通过 | 批次32 | 0 | 0 | 0 | 左滑露出删除→弹「从标签中移除联系人」→取消不删除 |
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 移除成员后计数与副标题同步 | 已通过 | §二十七 | 1 | 1 | 0 | |
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 更多菜单打开修改标签名面板 | 已通过 | 批次32 | 1 | 1 | 0 | 面板打开正常但 RenderFlex 底部溢出58px（键盘弹出+弹层收缩）已修（批次34）：showModalBottomSheet 固定 SizedBox(172) 键盘弹出时可用高度收缩导致溢出，Column 外包 SingleChildScrollView（静止视觉不变）；新增溢出测试（FakeViewPadding 压入 400px + takeException 断言，反证：移除滚动层变红）；待新 APK 真机复验 |
| 无待办 | - | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 更多菜单删除标签并退回列表 | 已通过 | 批次32 | 0 | 0 | 0 | 确认对话框→API→缓存清除→退回标签列表 |
| 无待办 | — | `page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 空标签时展示空态与添加按钮 | 已通过 | 批次27 | 1 | 1 | 0 | |
