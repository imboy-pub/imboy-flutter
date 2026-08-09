# `page/mine/logout_account/logout_account_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 点击导出我的数据生成文件 | 已通过 | 批次29 | 0 | 0 | 0 | 实测 logcat GET /api/v1/user/export_data 成功返回完整 payload（user_info/friends 3 条/groups 3 条/settings/legal_hold）→ getTemporaryDirectory 写 imboy_data_<ts>.json（L69-73） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 导出完成后调起系统分享面板 | 已通过 | 批次29 | 0 | 0 | 0 | 实测系统分享面板弹出（「分享方式」11 个目标：QQ收藏/电子邮件/发送到我的电脑/微信收藏/Huawei Share 等）；未点任何分享目标（防第三方外发），BACK 关闭（SharePlus L155-160） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 导出失败展示错误文案区块 | 已通过 | 批次29 | 1 | 1 | 0 | ⚠️bug已修+真机验证：错误区块原不可达——HttpClient fail-open（http_client.dart L380-398 吞异常返回 ok:false 响应，永不抛异常）→ notifier on Exception 分支死代码 → 飞行模式实测走 data==null 分支（L65-67）不设 error，仅 user_api L222 showError 短暂 toast；修复 L65-73 data==null 时设置 error=operationFailedAgainLater，飞行模式重测：页面渲染 iosRed 错误区块「操作失败，请稍后重试」（get_ui 实测 (360,739)，修复前不可达）；恢复网络导出正常（分享面板弹出完整 payload） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 勾选已阅读并同意条款复选框 | 已通过 | 批次29 | 0 | 0 | 0 | 实测点 CheckBox → checked 切换 + 注销按钮由 disabled 变 clickable（L174-181 CupertinoCheckbox） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 点击整行同样切换勾选状态 | 已通过 | 批次29 | 0 | 0 | 0 | 实测点整行 → checked 取消 + 按钮回 disabled；再点恢复勾选（L184-186 onTap 同 changeValue） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 未勾选时注销按钮保持禁用 | 已通过 | 批次29 | 0 | 0 | 0 | 实测双向：初始 disabled、勾选 clickable、取消勾选回 disabled（onPressed: agreed && !isLoading L237） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 注销按钮使用 iosRed 破坏色 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L227 backgroundColor: AppColors.getIosRed(brightness)、L229-231 disabledBackgroundColor iosRed alpha 0.3（DESIGN.md 破坏性操作规范） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 点击注销弹出不可逆二次确认 | 已通过 | 批次29 | 0 | 0 | 0 | 实测 CupertinoAlertDialog「确定要注销账号吗？此操作将永久删除你的账号和所有数据，且不可恢复」+取消/注销账号（isDestructiveAction）；点取消关闭，未点确认（L240-257） |
| 阻塞 | 待一次性可弃用测试账号 | `page/mine/logout_account/logout_account_page.dart` | 确认后调用服务端注销接口 | 未测 | - | 0 | 0 | 0 | 不可逆破坏性操作（applyLogout L85-99 → POST /api/v1/user/apply_logout，代码已读） |
| 阻塞 | 待一次性可弃用测试账号 | `page/mine/logout_account/logout_account_page.dart` | 注销成功清理本地并跳欢迎页 | 未测 | - | 0 | 0 | 0 | 不可逆破坏性操作（L267 quitLogin + L268 context.go('/welcome')，代码已读） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 注销失败展示错误提示文案 | 已通过 | 批次29 | 1 | 1 | 0 | ⚠️bug已修+真机验证：同 L10 fail-open 模式——断网触发 applyLogout，HttpClient 吞 NetworkException 返回 ok:false 空响应（logcat 实测 `> on UserApi/applyLogout resp: {}` + `failed: Instance of NetworkException, code: -1`），on Exception 死代码致错误区块原不可达；修复 L91-106 result==false 显式设置 error=operationFailedAgainLater；飞行模式实测：二次确认弹窗 → 断网提交 → 页面渲染 iosRed 错误区块「操作失败，请稍后重试」（get_ui 实测 (360,739)）且未跳转欢迎页（账号未注销，仅测失败路径） |
| 无待办 | - | `page/mine/logout_account/logout_account_page.dart` | 加载中禁用导出与勾选交互 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L146-147 导出 onTap isLoading?null、L177-178 CheckBox onChanged isLoading?null、L237 按钮 onPressed agreed&&!isLoading；瞬态不可实测 |
