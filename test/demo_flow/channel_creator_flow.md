# DF-12 创建频道 → 发布内容 → 评论 → 管理

> 优先级：P1
> 状态：`只读/API/本地页面部分通过，写入阻塞`

## 1. 目标

验证频道创建者可以创建频道、发布文本/文章内容，查看评论和订阅者，并使用管理员入口维护频道。

## 2. 前置条件

- [ ] 使用非生产环境和专用测试频道。
- [ ] 明确创建者、管理员、订阅者三种角色。
- [ ] 频道发布、评论、邀请和删除均可能写入服务端；删除频道默认不执行。

## 3. TODO 步骤

- [ ] 创建测试频道并完成基本资料。
  - 预期：名称、头像、简介和可见性保存成功。
  - 页面计划：[channel_create_page.md](../auto_test/channel/channel_create_page.md)、[channel_edit_page.md](../auto_test/channel/channel_edit_page.md)
- [ ] 发布一条文本内容和一篇文章。
  - 预期：内容发布成功，详情页可见，刷新后仍存在。
  - 页面计划：[channel_compose_page.md](../auto_test/channel/channel_compose_page.md)、[channel_article_page.md](../auto_test/channel/channel_article_page.md)
- [ ] 以订阅者账号查看内容并发表评论/互动。
  - 预期：评论、计数和权限符合频道设置。
  - 页面计划：[channel_comment_page.md](../auto_test/channel/channel_comment_page.md)
- [ ] 创建者查看管理员和订阅者列表。
  - 预期：角色、订阅状态和列表刷新正确。
  - 页面计划：[channel_admin_page.md](../auto_test/channel/channel_admin_page.md)、[channel_subscriber_page.md](../auto_test/channel/channel_subscriber_page.md)
- [ ] 使用频道邀请入口邀请测试账号。
  - 预期：邀请链接/二维码可打开，授权账号能完成订阅。
  - 页面计划：[channel_invitation_page.md](../auto_test/channel/channel_invitation_page.md)

## 4. 验收标准

- [ ] 创建、发布、订阅者查看、评论和管理形成完整证据链。
- [ ] 创建者、管理员、订阅者的权限边界清晰。
- [ ] 失败时不把本地乐观内容当作服务端已发布。

## 5. 当前覆盖与阻塞

- 现有频道页面计划覆盖较多，但跨页面创建者流程尚未闭环。
- 频道附件授权、邀请和管理员操作需非生产数据或人工确认。
- 2026-08-09：已完成频道只读/API及本地页面的部分检查；创建频道、发布内容、评论互动、管理员/订阅者角色维护和邀请写入均因缺少隔离测试频道/角色授权而 `BLOCKED`。
- 不能用普通频道浏览或本地乐观内容替代创建者完整闭环证据。

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/channel_creator_flow_test.dart`，并要求显式设置频道写入开关。
