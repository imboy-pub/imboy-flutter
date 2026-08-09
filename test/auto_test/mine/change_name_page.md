# `page/mine/user_device/change_name_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 进入页面自动聚焦并回填原值 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测 autofocus 聚焦（EditText focused）；回填实测：从列表页重进后输入框 text="A"（=服务端 device_name 最新值）；⚠️详情页内二次进入回填旧快照（widget.model.deviceName 不随改名刷新，displayName 兜底设计所致，非组件 bug） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 输入变化驱动完成按钮高亮 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L42-49 listener 驱动 valueChanged + L96 highlighted；输入后提交成功佐证状态流转（高亮为视觉态，禁截图不可实测） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 空值提交被拦截并重置变更态 | 已通过 | 批次29 | 0 | 0 | 0 | 清空输入框后点完成→logcat 无 change_name 请求（L63-66 trim 空拦截 setState valueChanged=false） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 点击完成提交新名称 | 已通过 | 批次29 | 0 | 0 | 0 | 输入 "1" 点完成→logcat POST /api/v1/user_device/change_name 发出+响应+「清除缓存: user_device」成功链→列表页实测显示新名（服务端已改名） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 键盘回车键直接提交 | 已通过 | 批次29 | 0 | 0 | 0 | 输入 MRD-AL00 后 keyevent 66（ENTER）→ 05:39:47 请求发出 + 自动 pop 回设备详情（onFieldSubmitted=_submit L147） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 提交期间拦截重复点击 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L67 _isSubmitting 门控 + L98-99 onPressed 置 null（瞬态不可实测） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 提交期间输入框转为只读 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L146 readOnly: _isSubmitting（瞬态不可实测） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 提交期间按钮展示加载态 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L97 isLoading: _isSubmitting 透传 RoundedElevatedButton（瞬态不可实测） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 提交成功后自动返回上一页 | 已通过 | 批次29 | 0 | 0 | 0 | 提交成功（点完成/回车两路径）均实测自动 pop 回设备详情（L73-75 res&&mounted→pop） |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 回调抛异常时兜底错误提示 | 已通过 | 批次29 | 0 | 0 | 0 | 飞行模式提交→页面不 pop（成功才 pop）→失败路径；代码 L76-77 catch→AppLoading.showError(tipFailed)=EasyLoading overlay 不进语义树；回调自身 catch L510-514 返回 false |
| 无待办 | - | `page/mine/user_device/change_name_page.dart` | 输入按单词首字母自动大写 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L110 textCapitalization: TextCapitalization.words；adb input 注入不经过 IME 大写逻辑无法实测 |
