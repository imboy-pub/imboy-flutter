# OA 单次码 WebView 生命周期

源码基线：78cd2749b0e5f2c23eaa4f100afe6afdab17b9a7。源码 hash 见配套 evidence/source-sha256.txt。日志后仅移动说明注释至对应私有函数，业务逻辑未变。

原 OaTabPage 的 AnimatedSwitcher 以 status 为 key；loading 和 ready 的 WebView 所在层级也不同。首个 page-finished 后会销毁旧控制器并重建，再次 loadRequest 含同一次性 code 的初始 URL。新受控 widget 基线实测 mounts=2（期望1），说明此前只检查签发一次的测试无法发现重复落地。现在 loading/ready 共用 key 和相同 Stack，只移除加载遮罩；失效/错误/显式重启与原有 generation 防护保留。

修复后 flutter test test/enterprise_oa test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart 共142项通过、无跳过；flutter analyze 两个配套 source hash 文件无问题，diff --check 通过。回归断言挂载一次、就绪前无销毁、页面退出销毁一次；倒计时测试改为受控 page-finished 后才检查就绪，不再依赖切换动画残留文案。首次组合检查暴露旧个人第五个 OA Tab 的四项源码断言失败，已删除过时 oa_tab_navigation_registration_test.dart（个人已固定四项，OA 在企业工作台）。现有 enterprise_shell_page_test 真实 widget 检查三/四项入口、配置失败、企业切换、平台限制和按需启动，覆盖当前入口合同；不靠匹配源码字符串证明功能。

此证据使用 fake launcher/WebView，证明 Flutter 挂载生命周期及状态回流，未证明原生 WebView、真实 OA 一次交换/跨企业 Cookie 隔离。当前容器没有 Cookie 清理，这是 OA-01/02 尚待解决的独立缺口；不能把本修复判为 OA 交付完成。真实接收端、60s/并发一次消费及设备仍需完整验收。人工检查调用链/keys/终态，未执行独立 agent 审查；六项目标继续、未执行外向操作。
