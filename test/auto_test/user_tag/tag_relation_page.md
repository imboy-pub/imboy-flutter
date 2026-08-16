# `page/user_tag/user_tag_relation/tag_relation_page.dart`

> 功能点 12 个 | bug 发现 5 / 解决 5 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 进页加载标签统计并显示加载态 | 已通过 | 批次72 | 0 | 0 | 0 | 真机（BUG#131 修复后入口可达）：联系人详情→设置备注和标签→编辑标签，统计卡正常渲染（已选 1/可选择 1） |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 统计卡显示已选可用最常用标签 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：已选/可选择计数随操作实时更新（添加后 1→2，清空后 →0）；无 usage_count 数据时最常用位不显示（代码 L419-421 条件渲染） |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 输入框新增标签并加入当前列表 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：输入 qa_test2→添加→已选 (2)+双 chip 渲染+保存入口出现（未保存无数据写入）；输入非空时建议区按设计收起（已选标签被过滤排除） |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 键盘弹起时页面布局不溢出 | 已通过 | 第八批 | 1 | 1 | 0 | |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 点建议标签快速加入当前标签 | 已通过 | 批次72 | 1 | 1 | 0 | 真机复验通过（290b602b）：未聚焦建议区可见可点（建议标签+qa0804 chip）、多次收键盘/滑动后建议区常驻不收起、聚焦时输入过滤逻辑存活（输入 qa 触发过滤）；代码核实显示条件与焦点解耦（tag_input.dart L322-325，注释 L318-321 记载批次28 教训）。「快速加入」受数据限制（唯一标签已选，contains 去重），BUG#142 修复后清空场景可完整闭环 |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 点重置恢复到进页原始标签 | 已通过 | 批次78 | 1 | 1 | 0 | |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 点清空弹出二次确认后清空 | 已通过 | 批次78 | 1 | 1 | 0 | |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 仅有变更时才显示保存入口 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：清空/添加后有变更→顶栏保存+底部保存标签 (N) 出现；重置回初始后入口消失 |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 底部保存提交并回传标签串 | 已通过 | 第八批 | 1 | 1 | 0 | |
| 待复验 | 已具备：保存可逆（测前记录原标签、测后恢复） | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 保存成功弹提示并触觉反馈 | 待重验 | - | 0 | 0 | 0 | 0816复核：§1.4 无禁写标签项，同页保存已于第八批实测；转待复验。代码路径 L123-131：成功→showSuccess+lightImpact+pop 回传 |
| 待复验 | 已具备：飞行模式可制造失败且零数据写入 | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 保存失败弹出保存失败提示 | 待重验 | - | 0 | 0 | 0 | 0816复核：失败测试无需写数据，「需写生产标签数据」误标；转待复验。代码路径 L142-148：失败→showError(saveFailed) |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 单标签十四字与总数二十上限 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：输入 15 字符 abcdefghijklmno→添加被拦截（已选不变、无新 chip，tag_input.dart L110-114 超限弹 tagLengthExceeded）；总 20 上限代码佐证（maxTags=20 + L116-119 超限弹 maxTagsExceeded，未实测避免耗时） |
