# `page/user_tag/user_tag_relation/tag_relation_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 2 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 进页加载标签统计并显示加载态 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 统计卡显示已选可用最常用标签 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 输入框新增标签并加入当前列表 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 键盘弹起时页面布局不溢出 | 已通过 | 第八批 | 1 | 1 | 0 | |
| 待修复 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 点建议标签快速加入当前标签 | 不通过 | 批次28 | 1 | 0 | 1 | 批次28 真机发现：建议标签**用户根本看不到**。`TagInput._onFocusChanged` 把 `_showSuggestions` 绑死在 `_focusNode.hasFocus`，建议区只在输入框聚焦时展开；而输入框位于页面底部，一聚焦键盘就把整个建议区盖住，想滚上来看又会失焦导致建议区收起 —— 死循环。真机实测统计卡明明写着「可选择 2 / 最常用 qa-tag」，下方却始终是空白。⚠️注意这**不是**「建议列表没渲染」，`_suggestedTags` 与统计卡同源、数据是有的，问题在展开时机与布局。候选方向：聚焦时把建议区滚进可视区（`Scrollable.ensureVisible`），或让建议区常驻不依赖焦点 |
| 待首测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 点重置恢复到进页原始标签 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 点清空弹出二次确认后清空 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 仅有变更时才显示保存入口 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 底部保存提交并回传标签串 | 已通过 | 第八批 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 保存成功弹提示并触觉反馈 | 待重验 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 保存失败弹出保存失败提示 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | 2026-08-07 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 单标签十四字与总数二十上限 | 未测 | - | 0 | 0 | 0 | |
