# macOS 原生 OA 会话隔离验收

本期用户以 macOS 替代 iOS。命令：`python3 scripts/oa_webview_macos_session_gate.py`，原生退出 0，`PASS_NATIVE_MACOS_WEBVIEW_SESSION`。

实际运行生产 `OaWebViewContainer`、WKWebView、原生 Cookie/缓存清理及 exact-origin 策略；使用独立 UUID bundle，并在容器挂载前核实实际 PackageInfo。测试专用 delegate 只接受本次 loopback host、端口和叶证书 DER SHA，未修改系统或生产信任。

真实本地 TLS 接收端确认：A→B 首次及全部入口请求不带 A Cookie；B 页面没有旧 localStorage；旧 A 退出不清 B Cookie且迟到A不会恢复；B退出后C所有入口请求无B Cookie；跨origin跳转零请求。原生断言与服务端记录须同时通过。

`source-binding.tsv` 绑定实际最终源码，`terminal.json` 与 `observations.json` 保存结果，`native.log` 是原始合成日志。首次独立包签名构建失败保留在 recovery.json，不计 PASS。生产源码未修改；Android原入口保留。插件清理的是当前App共享WebView datastore，测试独立包不清用户App数据。

本结果补本地合成OA的 macOS Cookie证据，不代表客户OA或iOS联调，也不代表整体验收或生产部署。
