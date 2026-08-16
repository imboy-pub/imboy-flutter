# `page/wallet/red_packet_detail_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 展示详情加载中转圈态 | 已通过 | 批次102 | 0 | 0 | 0 | 代码证实：_isLoading→CircularProgressIndicator（L115-120）；请求~100ms完成真机难捕获（同批次101转圈标注） |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 红包不存在时展示兜底页 | 已通过 | 批次102 | 0 | 0 | 0 | 生产remote console推孤儿红包（payload.id=99999999999999999999不存在）→点開→详情页「红包不存在或已被删除」get_ui实测 |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 拉取详情失败错误提示 | 已通过 | 批次102 | 0 | 0 | 0 | 同上链路：detail==null分支toast「获取红包详情失败」get_ui实测；catch分支（「获取红包详情异常」）代码证实L81-84（华为EMUI断网不可控，网络异常路径无法真机触发） |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 顶部渐变头展示祝福语 | 已通过 | 批次27 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 高亮展示本人已领金额 | 已通过 | 批次27 | 0 | 0 | 0 | 0.32+元，uiautomator完整dump证实 |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 未领到红包时展示替代文案 | 已通过 | 批次27 | 0 | 0 | 0 | 0领取态，代码分支唯一 |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 切换已抢光与进行中统计条 | 已通过 | 批次27 | 0 | 0 | 0 | 两分支均真机验证 |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 渲染领取记录列表与时间 | 已通过 | 批次27 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 计算并标记手气最佳领取人 | 已通过 | 批次27 | 0 | 0 | 0 | 拼手气1.68标/0.32不标 |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 无人领取时展示空态提示 | 已通过 | 批次27 | 0 | 0 | 0 | |
| 无待办 | 2026-08-06 | `page/wallet/red_packet_detail_page.dart` | 展示领取人身份标识 | 已通过 | 批次26/27 | 1 | 1 | 0 | 已修并真机复验：用户：117 / 用户：IMBoy |
| 无待办 | - | `page/wallet/red_packet_detail_page.dart` | 展示零信任端解密角标 | 已通过 | 批次27 | 0 | 0 | 0 | 文案硬编码未走 i18n |
