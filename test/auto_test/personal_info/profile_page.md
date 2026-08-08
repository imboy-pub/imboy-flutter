# `page/personal_info/profile/profile_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 1 / 待处理 2
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 子页编辑返回后自动重载资料 | 已通过 | §十七 | 1 | 1 | 0 | |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 完善度进度与完善建议展示 | 已通过 | 批次26 | 1 | 1 | 0 | 真机复验通过：chip 已 clickable，点「设置个性签名」正确弹出编辑框 |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 顶部刷新按钮重新拉取资料 | 已通过 | 批次30 | 0 | 0 | 0 | 两次点击刷新无异常，数据回显正常（华为 logcat 缓冲滚动，判定以 UI+数据为准） |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 更多菜单分享资料到外部应用 | 已通过 | 批次29 | 0 | 0 | 0 | 实测点右上角「显示菜单」→ 弹出 PopupMenu（分享资料/导出资料）→ 点分享资料 → 系统分享面板弹出（「分享方式」12 个目标：信息/百度地图/保存到QQ收藏/备忘录/电子邮件/发送到我的电脑等）；未点任何分享目标（防第三方外发），BACK 关闭（SharePlus L793-805 text=昵称+ID） |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 更多菜单导出JSON或TXT到剪贴板 | 已通过 | 批次29 | 0 | 0 | 0 | 实测点导出资料 → CupertinoActionSheet（JSON/TXT/取消）→ 点 JSON：ActionSheet 关闭 + logcat 零异常（_exportToClipboard L840-845 无 try-catch，setData 失败必抛异常入 logcat，实测无）→ 同法点 TXT 零异常；代码证实 JSON=user.toJson().toString() 完整序列化 / TXT=昵称+ID，setData 后 showSuccess toast（EasyLoading 不进语义树） |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 编辑头像弹出拍照相册操作面板 | 已通过 | 批次30 | 0 | 0 | 0 | 拍照/从相册选择/取消 三选项齐全，面板正常弹出与关闭 |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 头像上传中显示遮罩与成功提示 | 已通过 | 批次30 | 0 | 0 | 0 | logcat 铁证：presign→attachment/confirm→PUT user/update→新头像下载 103570 bytes |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 封面相机图标更换个人背景图 | 已通过 | 批次30 | 0 | 0 | 0 | 面板→系统相册→选图→上传→回页正常（华为 documentsui 单选正常） |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 生日选择器保存并回填日期 | 已通过 | 批次30 | 0 | 0 | 0 | 回填「1990-01-01」铁证 + 完善度 75%→88% + 建议变「资料已完善！」 |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 个性签名弹窗编辑并保存 | 已通过 | 批次30 | 0 | 0 | 0 | ASCII 输入「QA test sig 2026-08-08」保存成功，签名行回填（adb 不支持中文输入，用 ASCII 替代） |
| 阻塞 | 待发布生效+真机复验 | `page/personal_info/profile/profile_page.dart` | 职业学校兴趣弹窗编辑并保存 | 待重验 | 批次30 | 1 | 0 | 1 | BUG：职业/学校/兴趣保存失败（确认后回填仍「未设置」，刷新亦然）。根因三处：后端 user_agg:validate_update 白名单缺 profession/school/interests + user 表缺三列 + 前端 profileProvider switch 缺三 case。已修（未 push）：imboy 仓迁移 00000059 加列 + user_agg 白名单 + common.hrl 读侧列；imboyapp 仓 profile_provider +9 行 |
| 无待办 | - | `page/personal_info/profile/profile_page.dart` | 点隐私设置行跳转隐私设置页 | 已通过 | 批次30 | 0 | 0 | 0 | 隐私设置页正常打开：搜索设置（账号搜索/手机号添加/二维码添加 3 开关全开）+ 状态设置（在线状态开/附近的人可见关） |
