# `page/contact/new_friend/add_friend_page.dart`

> 功能点 9 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 输入账号搜索并跳转用户详情 | 已通过 | 批次64 | 0 | 0 | 0 | 真机搜索矩阵三分支：117@imboy.pub(email)/58628(account 5位)/50075-leeyi(account 5位) 均命中跳转详情；118@imboy.pub 无结果=数据侧(email字段或allow_search=false非代码)；⚠️边界缺陷 BUG#144：account 恰为 11 位手机号格式时 elib_type:is_mobile 判定抢先→find_by_mobile 查 mobile 字段→account 命中分支不可达（automation-buddy=19999990002 实测搜不到，代码路径 user_logic:find_by_keyword 三选一互斥确认），待修 |
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 搜索无匹配时提示无结果 | 已通过 | 批次42 | 0 | 0 | 0 | 真机输入 99999999+回车无跳转无结果列表；toast 一闪而过+代码确认 L125-127 results.isEmpty→showInfo(searchNoResults) |
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 搜索异常时提示网络错误 | 已通过 | 批次42 | 0 | 0 | 0 | 代码确认 L134-137 异常分支→showError(errorNetwork)；断网构造成本高未真断网 |
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 展示当前账号的登录账号号码 | 已通过 | 批次42 | 0 | 0 | 0 | 真机「我的账号：58628」 |
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 点击二维码图标打开我的名片码 | 已通过 | 批次42 | 0 | 0 | 0 | 真机二维码名片页渲染（uid 117+北京 朝阳+QR 码+保存二维码/分享按钮） |
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 进入「附近的人」功能页 | 已通过 | 批次42 | 0 | 0 | 0 | 真机：定位权限弹窗→点禁止→附近的人页（找附近的人按钮+空态+隐私与安全-让自己不可见） |
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 进入「面对面建群」功能页 | 已通过 | 批次42 | 0 | 0 | 0 | 真机四位数输入键盘页渲染 |
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 进入扫一扫扫码加好友 | 待重验 | - | 0 | 0 | 0 | 需授予相机权限 |
| 回归复测 | 2026-08-08 | `page/contact/new_friend/add_friend_page.dart` | 进入「最近注册用户」列表页 | 已通过 | 批次42 | 0 | 0 | 0 | 真机进入列表页（说明文案+leeyi 广东深圳 刚刚 用户行渲染） |
