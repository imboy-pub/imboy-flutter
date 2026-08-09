# `page/settings/e2ee_key_recovery_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/settings/e2ee_key_recovery_page.dart` | 进入页面加载并展示当前密钥信息 | 已通过 | 批次31 | 0 | 0 | 0 | 真机深链 /e2ee_key_recovery → 密钥信息卡三要素目击：设备 ID HUAWEIMRD-AL00 / 密钥 ID kid_ab3e7fe52eb9f981 / 创建时间 2026-08-07T16:14:40.674950Z + 「已激活」徽章 |
| 无待办 | - | `page/settings/e2ee_key_recovery_page.dart` | 加载期间展示活动指示器 | 已通过 | 批次31 | 0 | 0 | 0 | 代码证实：_isLoading 分支渲染 CupertinoActivityIndicator（e2ee_key_recovery_page.dart L59-62）；真机本地缓存秒出加载瞬间不可目击 |
| 无待办 | - | `page/settings/e2ee_key_recovery_page.dart` | 点击右上刷新重新读取密钥信息 | 已通过 | 批次31 | 0 | 0 | 0 | 真机点右上「刷新」(644,98) → 密钥信息重读完整展示（密钥 ID 不变，重读非重建） |
| 无待办 | - | `page/settings/e2ee_key_recovery_page.dart` | 展示加密说明卡片三条要点 | 已通过 | 批次31 | 0 | 0 | 0 | 真机「关于端到端加密」卡三条要点目击（发送前加密/换设备或删密钥旧消息无法解密/定期备份） |
| 无待办 | - | `page/settings/e2ee_key_recovery_page.dart` | 点击备份卡片弹出底部操作面板 | 已通过 | 批次31 | 0 | 0 | 0 | 真机点「本地备份」卡 → 底部面板（纱罩+导出备份+导入备份）；星标五档=代码证实 List.generate(5) star_fill/star（L481-491，securityLevel=4，图标不进语义树） |
| 无待办 | - | `page/settings/e2ee_key_recovery_page.dart` | 面板点击导出跳转备份导出页 | 已通过 | 批次31 | 0 | 0 | 0 | 真机面板点「导出备份」→ 「导出 E2EE 备份」页（重要提示卡/密码框×2/生成恢复密钥/密码强度条/生成备份文件与备份到云端按钮禁用） |
| 无待办 | - | `page/settings/e2ee_key_recovery_page.dart` | 面板点击导入跳转备份导入页 | 已通过 | 批次31 | 0 | 0 | 0 | 真机面板点「导入备份」→ 「导入 E2EE 备份」页（导入说明警告卡/选择备份文件入口/密码框与导入密钥按钮禁用） |
| 阻塞 | 需可弃用测试账号（须先删除密钥） | `page/settings/e2ee_key_recovery_page.dart` | 无密钥时展示空态卡片与生成入口 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可弃用测试账号（生成不可逆） | `page/settings/e2ee_key_recovery_page.dart` | 点击生成新密钥弹出不可逆警告 | 未测 | - | 0 | 0 | 0 | 危险操作未执行 |
| 阻塞 | 需可弃用测试账号 | `page/settings/e2ee_key_recovery_page.dart` | 确认生成后展示新密钥成功弹窗 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可弃用测试账号 | `page/settings/e2ee_key_recovery_page.dart` | 成功弹窗点击去备份跳转导出页 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可弃用测试账号（删除不可逆） | `page/settings/e2ee_key_recovery_page.dart` | 删除密钥经两阶段高摩擦确认执行 | 未测 | - | 0 | 0 | 0 | 执行后历史消息永久不可解密 |
