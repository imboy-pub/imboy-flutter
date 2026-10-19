# P3 接单分页隔离回归 — T27
- C-T27-1：flutter test test/uiux/p3/behavior_regression_test.dart → 3/3 pass, exit 0
  （claim CAS expected_version 基线；queue 端点/A0 分页键；wire→模型原样）
- C-LEGACY-P3：cs_queue_layout + cs_seat_gate + cs_api_contract
  + cs_session_preview_scope + cs_session_page → 62 pass ~10 skips, exit 0
- 结论：T19—T21 行重构未改变 claim CAS、分页与 DTO 解析。
