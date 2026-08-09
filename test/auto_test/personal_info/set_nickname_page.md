# `page/personal_info/set_nickname/set_nickname_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 输入框自动聚焦并回填当前昵称 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_nickname/set_nickname_page.dart` | 底部展示昵称字符规则说明 | 已通过 | 批次19 | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_nickname/set_nickname_provider.dart` | 进页面时剩余字数初始值 | 已通过 | 批次74 | 1 | 1 | 0 | 批次74 真机复验通过：改昵称「117👩」（3 字符+1 emoji，UTF-16 5 码元 / 字素簇 4）后重新进昵称页，build() 初始剩余字数 = 20（字素簇口径；旧 String.length 口径会是 19）。保存后服务端搜索 58628 回读昵称「117👩」—— 排除乐观更新。测试后已改回 117。注：复验需输入 emoji，adb input text 非 ASCII 被杀，已用 ADBKeyBoard IME + ADB_INPUT_B64 广播解决 |
| 无待办 | - | `page/personal_info/set_nickname/set_nickname_page.dart` | 右侧剩余字数计数实时更新 | 已通过 | 批次28 | 1 | 1 | 0 | 批次28 真机复验通过：输入 ZWJ 家庭 emoji「117👩‍👩‍👧」（5 码位 / 8 个 UTF-16 code unit）计数为 20，即该 emoji 计 1 个字素簇（修前 UTF-16 口径会显示 13）。保存后**用服务端搜索自己**（`user_search` 58628）回读到「117👩‍👩‍👧」—— 排除乐观更新的落库硬证据。测试后已把昵称改回 117。原修复记录： 核实后修正定性：后端**根本不校验**昵称（在 user_agg 的透传白名单里，注释写明「无校验原样落库」），客户端是唯一防线，且客户端内部两个口径就在打架 —— 输入框 `maxLength:24` 走 LengthLimitingTextInputFormatter 按字素簇截断，provider 却用 `String.length`（UTF-16 code unit，一个 👨‍👩‍👧‍👦 占 11），输入框放行的内容被判超长、存不下去。已双端统一到字素簇：客户端改 `.characters.length`；后端把 nickname 移出透传白名单并按 `string:length/1`（grapheme 口径）校验 2~24，非法 UTF-8 走 `unicode:characters_to_list` 返回错误而非抛 badarg 变 500。后端补 6 条 eunit（含 ZWJ emoji 计 1、非法 UTF-8、非 binary），反证通过。待真机验：输入 emoji 时计数与保存行为 |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 超出长度时计数变红警示 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 非法输入展示校验错误提示行 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 保存按钮按可保存态启用或置灰 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 点保存收起键盘并提交昵称 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_nickname/set_nickname_page.dart` | 保存中显示菊花并禁止重复点击 | 已通过 | 批次30 | 0 | 0 | 0 | 实测两连击（快速连点保存两次）：logcat 仅 1 次 PUT /api/v1/user/update（07:49:50 唯一 Request → 234ms 成功），第二次点击被 isSaving 拦截（页面 L39 onPressed canSave&&!isSaving + provider L184 isSaving 守卫双防线）；菊花=代码证实 L52-53 isSaving→CupertinoActivityIndicator(radius:10)，请求仅 234ms 瞬态禁截图无法目击；保存成功退栈+上级昵称文案立即刷新（实测 117A） |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 保存成功退栈并回传刷新标志 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_nickname/set_nickname_page.dart` | 保存失败弹出更新失败提示 | 已通过 | 批次30 | 0 | 0 | 0 | 实测断网（Active default network: none）改昵称点保存：logcat 0 次 user/update（http_client 网络检查拦截 fail-open 返回 false 不发请求）→ 页面停留不退栈 + L48 showError(nicknameUpdateFailed) toast（EasyLoading 不进语义树，代码证实）；同位置正常网络已证保存成功+退栈，点击链路有效；测试后昵称已恢复 117 |
| 回归复测 | 2026-08-07 | `page/personal_info/set_nickname/set_nickname_page.dart` | 输入达24字符时硬截断 | 待重验 | - | 0 | 0 | 0 | |
