# P1 业务调用回归 — T25
- C-T25-1：flutter test test/uiux/p1/behavior_regression_test.dart → 3/3 pass, exit 0
  （初始序列 build→loadChannel；重试=既有 loadChannel；分页单一通道）
- C-LEGACY-P1：workspace_channel_detail + channel_header_bar + detail_layout
  + message_feed + micro_community_contract → 45 pass ~10 golden skips, exit 0
- 结论：T10—T15 重构未改变业务调用序列/参数/恢复入口。
