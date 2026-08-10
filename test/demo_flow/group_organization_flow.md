# DF-15 群分类/标签 → 二维码 → 邀请入群

> 优先级：P1
> 状态：`分类/标签只读通过，二维码本地渲染通过，扫码和写入阻塞`

## 1. 目标

验证用户可以管理群分类和标签，并通过群二维码/邀请入口让授权测试账号找到目标群。

## 2. 前置条件

- [ ] 准备测试群、管理员账号、普通成员账号和第二设备/账号。
- [ ] 二维码有效期、分享目标和邀请权限已确认。
- [ ] 不把二维码发给真实第三方，不执行不可逆的群清理。

## 3. TODO 步骤

- [ ] 打开群分类列表和详情，创建/重命名一个可回收分类。
  - 预期：分类列表、详情、重命名和返回刷新正确。
  - 页面计划：[group_category_page.md](../auto_test/group/group_category_page.md)、[group_category_detail_page.md](../auto_test/group/group_category_detail_page.md)
- [ ] 为测试群添加或修改标签。
  - 预期：标签列表和群关联关系刷新正确。
  - 页面计划：[group_tag_page.md](../auto_test/group/group_tag_page.md)
- [ ] 生成群二维码，使用授权测试账号扫码。
  - 预期：扫码结果识别目标群，过期码和无效码有提示。
  - 页面计划：[group_qrcode_page.md](../auto_test/qrcode/group_qrcode_page.md)、[scanner_result_page.md](../auto_test/scanner/scanner_result_page.md)
- [ ] 在有权限时完成入群确认。
  - 预期：入群结果、群列表和成员数刷新一致。

## 4. 验收标准

- [ ] 分类、标签、二维码识别和入群结果分别可验证。
- [ ] 无效/过期二维码不会误加入群。
- [ ] 需要大群成员数的入口单独标记 `阻塞`。

## 5. 当前覆盖与阻塞

- 分类重命名页面当前有待发布/待复验问题记录。
- 二维码邀请依赖第二账号或第二设备，默认不对外发送。
- 2026-08-09：`group_category_api_test.dart`、`group_tag_api_test.dart` 的只读检查通过；本地二维码渲染通过。
- 分类/标签写入、第二账号扫码、入群确认和成员列表刷新未执行，缺少双端/隔离测试条件，保持 `BLOCKED`。

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/group_organization_flow_test.dart`，优先自动化只读生成二维码和扫码识别。
