# DF-19 联系人 → 备注/标签 → 分组筛选

> 优先级：P1
> 状态：`联系人只读/API和本地标签UI部分通过，写入阻塞`

## 1. 目标

验证好友建立后，用户可以修改联系人备注、创建标签、给好友打标签并按标签筛选。

## 2. 前置条件

- [ ] 已有明确授权的测试好友关系。
- [ ] 使用专用标签名和备注内容，不修改真实第三方资料。
- [ ] 删除标签、解除关系等破坏性动作默认不执行。

## 3. TODO 步骤

- [ ] 从联系人打开测试好友资料和更多设置。
  - 预期：好友信息、备注和管理入口正确。
  - 页面计划：[contact_page.md](../auto_test/contact/contact_page.md)、[people_info_more_page.md](../auto_test/contact/people_info_more_page.md)
- [ ] 修改好友备注并重新加载资料。
  - 预期：备注服务端保存成功，联系人列表同步展示。
  - 页面计划：[contact_setting_page.md](../auto_test/contact/contact_setting_page.md)
- [ ] 创建“demo”标签并给测试好友打标签。
  - 预期：标签保存成功，好友与标签关系可见。
  - 页面计划：[contact_setting_tag_page.md](../auto_test/contact/contact_setting_tag_page.md)、[contact_tag_list_page.md](../auto_test/user_tag/contact_tag_list_page.md)、[user_tag_save_page.md](../auto_test/user_tag/user_tag_save_page.md)
- [ ] 按标签筛选联系人并打开好友资料。
  - 预期：筛选结果与标签关系一致。

## 4. 验收标准

- [ ] 备注、标签、好友关系和筛选结果重新加载后保持一致。
- [ ] 失败时不把本地临时标签显示为服务端已保存。
- [ ] 标签删除和好友关系破坏操作默认阻塞。

## 5. 当前覆盖与阻塞

- 页面级计划覆盖联系人设置和 user_tag，但还没有跨页面流程。
- 需要明确好友测试账号，避免产生第三方通知或资料变更。
- 2026-08-09：`contact_api_test.dart` 的联系人只读检查通过，本地标签 UI 部分检查通过，计入本轮汇总。
- 备注修改、标签创建/关联和分组筛选的服务端写入未执行；缺少可回收测试好友和授权，保持 `BLOCKED`。

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/contact_management_flow_test.dart`，只使用可回收测试好友和标签。
