# `page/personal_info/set_region/set_region_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/personal_info/set_region/set_region_page.dart` | 进页初始化并回显当前地区 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_region/set_region_page.dart` | 顶部搜索框防抖过滤地区列表 | 已通过 | 批次30 | 0 | 0 | 0 | 实测输入 xyz → 地区列表清空（applyTopSearch 无匹配，get_ui 目击「地区」section 下零项），清空后恢复全量；防抖 300ms 代码证实 L52-59 Timer；中文子串匹配（title+children 深度搜索）代码证实 provider L111-141 |
| 回归复测 | 2026-08-07 | `page/personal_info/set_region/set_region_page.dart` | 已选地区回显区高亮加粗显示 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_region/set_region_page.dart` | 有变更时显示还原按钮 | 已通过 | 批次30 | 0 | 0 | 0 | 实测三级链路点叶子（中国大陆→北京→东城）后回主页面：已选地区回显「北京 东城」主色加粗（L121-128）+ 还原按钮（refresh 图标）出现 @(612,548)（L130-138 hasChanged 时渲染）；完成按钮可点（L73） |
| 无待办 | - | `page/personal_info/set_region/set_region_page.dart` | 点还原恢复到进页初始选择 | 已通过 | 批次30 | 0 | 0 | 0 | 实测点还原按钮：已选地区回「请选择」（进页初始空值）+ 还原按钮消失 + 层级提示行消失（revertToInitial L155-164 重置 selectedRegion/hasChanged/regionPath 并同步 RegionCache）；完成按钮回禁用（L73 onPressed hasChanged 门控） |
| 回归复测 | 2026-08-07 | `page/personal_info/set_region/set_region_page.dart` | 含子级项显示箭头并进入子页 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/set_region/set_region_page.dart` | 点叶子节点更新选择路径 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_region/set_region_page.dart` | 子页搜索框过滤子级地区 | 已通过 | 批次30 | 0 | 0 | 0 | 实测子页（中国大陆）输入 zzz → 省级列表清空（_SubRegionPage L274-291 300ms 防抖 setState 过滤），清空后恢复全量 |
| 无待办 | - | `page/personal_info/set_region/set_region_page.dart` | 子页点完成保存后连退两级 | 已通过 | 批次30 | 1 | 1 | 0 | 批次30 真机复验：层级提示行 _SelectionLevelHint L217-237 目击——二级页（中国大陆）与三级页（北京）均显示「已选 北京 东城（第 2 级）：可直接点右上角完成，也可继续...」（L13 提示行）；连退两级=子页完成按钮 L306-310 pop+pop 代码证实（未点完成保存，避免改写账号地区）；测试未保存地区已还原（点还原恢复初始） |
| 回归复测 | 2026-08-07 | `page/personal_info/set_region/set_region_page.dart` | 完成按钮按有无变更启用置灰 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/set_region/set_region_page.dart` | 保存成功后上级地区立即刷新 | 已通过 | §十七 | 1 | 1 | 0 | |
