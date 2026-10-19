# P2 权限与免登调用回归 — T26
- C-T26-1：flutter test test/uiux/p2/behavior_regression_test.dart → 3/3 pass, exit 0
  （seat-contexts 唯一权限请求面；appsUrl 目的地与桥注入基线；inbound 判定不变）
- C-LEGACY-P2：enterprise_workbench + t15_enterprise_layout + enterprise_shell
  + cs_seat_contexts → 46 pass ~12 skips, exit 0
- 结论：T16—T18 重构未改变权限判定、免登链与路由。
