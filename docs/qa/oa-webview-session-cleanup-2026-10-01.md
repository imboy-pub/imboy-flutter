# OA WebView 会话清理顺序

源码基线：33366b405d612886c02272b591d454fcadf2e0ca。最终业务文件以配套 evidence/source-sha256.txt 绑定。

现有容器不清 Cookie/本地存储，且初始化平台操作未等待。现在登录加载前验证 exact origin，等待 JS 与导航策略装配，经同一个队列停止旧 OA（window.stop + about:blank）、清 Cookie/localStorage/cache 后才 loadRequest；清理失败进入错误态、不加载登录 URL。退出清理也串行；旧页面延迟销毁只能清理自己仍拥有的会话，不能清新页面。旧页面事件不再回流，内部 about:blank 仅在 retired 状态允许，业务导航仍 exact HTTPS origin。没有注入 JWT/secret/header/JS bridge，没有新增依赖或改原生保留目录。

插件能力核对来自实际安装源码：webview_flutter 4.14.1 / platform_interface 2.15.1 的 clearCookies 为全 WebView 清理；Android 4.14.1 的 clearLocalStorage 调用 deleteAllData；WKWebView 3.26.1 清共享 datastore 的 localStorage 与缓存。**已知产品边界：每次打开/退出 OA 会清其他内嵌网页的 Cookie/登录状态，不能声称按站点隔离；尚无独立原生 profile，未证明 IndexedDB/service worker 清理。** 当前实现只解决现有插件提供的会话清理与顺序，最终生产隔离仍待真机及真实 OA 审查。

受控平台接口检查：基线三场景失败，初始登录 URL 在无清理时直接加载。修复检查清理未完成不加载、清理错误不加载并呈 error、停止/blank/清理/新加载顺序、退出清理、动画重叠时旧 dispose 不清新会话、清理中取消不加载旧 code、全部 loadRequest 无自定义 headers。最初三独立 widget tests 的 static Future 队列留在旧 FakeAsync 时钟，失败场景单独运行通过；改为一个完整生命周期检查含上述五段，未修改生产语义来迎合时钟。

flutter test test/enterprise_oa test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart 最终143项通过，无跳过；两文件 analyze 无问题、diff --check 通过、人工复核所有异步写/事件入口。平台 fake 只记录实际容器调用，没有真正 Cookie 数据或网络；不能证明原生 Cookie 全面失效、about:blank 完成导航/在途响应被撤销、远端 OA 会话注销、60s并发单次交换或生产就绪。Android/iOS 真机与同 origin A/B 实际旅程仍 PENDING，其他资料/客服/Internal 验收不因此完成。未进行独立 agent 审查、外向动作或部署。
