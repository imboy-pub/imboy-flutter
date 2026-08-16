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
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 保存成功弹提示并触觉反馈 | 已通过 | 批次81 | 0 | 0 | 0 | 真机（0816 双路径闭环，automation-buddy）：add 保存 qa_loop4→pop 回传+落库（tag='qa_loop4,'、relation 1 行）；清空保存→pop 回传+remove 落库（tag=''、relation 0，服务端 error.log replace_object_tag Res={ok,1} 无 500）。L145-151 成功才 pop，pop 发生即 showSuccess+lightImpact 已执行 |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 保存失败弹出保存失败提示 | 已通过 | 批次82 | 0 | 0 | 0 | 真机（0816 飞行模式，automation-buddy）：飞行模式下连点保存 4 次→页面始终不 pop（成功才 pop L145-151）+生产 DB 零写入（tag=''、relation 0）+logcat 零 Dio 请求日志（_executeWithNetworkCheck L380 网络检查即时拦截 NetworkException→ok:false→L153 showError(saveFailed)）。失败提示为 EasyLoading overlay 不进 a11y 树，工具不可见非功能缺陷 |
| 无待办 | - | `page/user_tag/user_tag_relation/tag_relation_page.dart` | 单标签十四字与总数二十上限 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：输入 15 字符 abcdefghijklmno→添加被拦截（已选不变、无新 chip，tag_input.dart L110-114 超限弹 tagLengthExceeded）；总 20 上限代码佐证（maxTags=20 + L116-119 超限弹 maxTagsExceeded，未实测避免耗时） |
