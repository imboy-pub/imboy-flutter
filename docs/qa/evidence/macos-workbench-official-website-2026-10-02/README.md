# macOS 工作台官网入口 / Official website entry

源码候选 `b57aa5f7d6d2ebf405aa4c3f8e392094a9848e44`，真实 macOS App 引擎执行既有集成测试，1项通过、exit0。生产工作台在无OA配置时显示“资料”和官网；点击入口将精确 https://imboy.pub/ 传给真实 macOS URL launcher，原生成功返回，界面未显示打不开网页的错误。

测试只观察Pigeon请求，然后通过 messenger.delegate 原样转发至真实系统插件，不伪造原生成功。未启动登录、数据库或读写用户偏好；没有源码变更。1193项源码和依赖配置前后哈希一致。

本目录为测试候选的文档后继。result.json记录命令、冻结源码及日志哈希；runner.py.txt保存实际控制器。原始日志仍为私有临时文件。系统浏览器网页的渲染像素、客户OA单点登录、iOS均未由此验证。

A real native plugin accepted the exact official website URL. This proves the fallback entry launch, not browser-page pixels or customer OA integration.
