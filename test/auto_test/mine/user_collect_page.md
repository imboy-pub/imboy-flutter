# `page/mine/user_collect/user_collect_page.dart`

> 功能点 17 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 首屏加载收藏列表数据 | 已通过 | 批次56 | 0 | 0 | 0 | 真机联网首屏请求 user_collect/page?page=1&size=10 发出+空态渲染；断网静默空态见 L23 BUG#128 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 滚动到底部自动加载下一页 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L108-144 距底 100px 触发 page 下一页+kindId 去重 L122-137；本地无数据未真机 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 搜索框输入防抖触发关键词搜索 | 已通过 | 批次56 | 0 | 0 | 0 | 真机 logcat 实锤 kwd=a 请求（L832-838 500ms 防抖） |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 点击清除按钮重置搜索结果 | 已通过 | 批次56 | 0 | 0 | 0 | 真机清除后请求无 kwd 参数+输入框清空（L739-754 onSuffixTap 重置） |
| 无待办 | - | `page/mine/user_collect/user_collect_page.dart` | 按九类类型筛选收藏内容 | 已通过 | 第八批 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 点击标签按标签筛选收藏 | 已通过 | 批次56 | 0 | 0 | 0 | 真机点 qa-tag chip→logcat tag=qa-tag 请求（L756-773）；面板 9 chips 全渲染 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 长按条目进入多选模式 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L232-239 _enterMultiSelect+onLongPress L453；无数据未真机 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 多选栏全选当前列表全部条目 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L260-268 _selectAllCurrent 遍历 items 全选；无数据未真机 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 批量打标签弹窗输入与去重 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L325-403 弹窗输入+split 逗号+toSet 去重 L367-372；写数据未执行 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 批量删除并汇总成功失败数量 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L270-323 success/fail 计数+partialDeleteSuccess L306；写数据未执行 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 点击关闭退出多选模式 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L241-246 _exitMultiSelect+L937 xmark_circle 按钮 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 左滑置顶或取消置顶并本地持久化 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L545-556 pin/unpin+L220-230 SharedPreferences 持久化（仅本地）；置顶仅存本地，换机重装会丢 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 右滑进入标签编辑页并回写 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L563-601 TagRelationPage(scene:collect)+返回回写 L577-597；未真选（写标签数据风险） |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 右滑删除弹出二次确认对话框 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L688-721 _confirmRemove sureDeleteData 确认框；未执行删除 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 无数据时展示暂无收藏空态 | 已通过 | 批次56 | 0 | 0 | 0 | 真机「暂无收藏内容，快去收藏一些有趣的消息吧」（L873-894 bookmark 图标+文案） |
| 阻塞 | 待新APK | `page/mine/user_collect/user_collect_page.dart` | 加载失败展示错误横幅与重试 | 有BUG待修 | 批次56 | 1 | 1 | 0 | BUG#128 已修（批次34）：断网静默空态三层 fail-open 链——api page() 加 resp.throwIfFailed()（照抄 denylist 模式）+ 页面新增 _applyLoadFailed() 接入 5 条调用路径（滚动加载/搜索/重置/标签搜索/分类切换），失败保留原列表+横幅，成功横幅消失；55 测试全绿。provider loadFailed 标记为并发会话 staged 改动未触碰；修复晚于 APK（14:55），转阻塞等新 APK 真机复验 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_page.dart` | 选择模式下弹出发送给确认框 | 已通过 | 批次56 | 0 | 0 | 0 | 代码确认 L631-686 _sendToDialog 仅 isSelect 模式（聊天页入口）；未真机 |
