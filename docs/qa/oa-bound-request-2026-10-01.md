# OA 企业签发请求 / Organization-bound OA issue request

日期：2026-10-01。App 基线：`11c7bc55`；服务端依赖：`b6d1faf2`。

主导航传入的企业标识经默认生产 launcher 传递到 OaSsoApi，作为 `organization_id` 发给 Human SSO 签发端点。标识保持 EntityId，验证十进制正数 int64 后直接生成 JSON integer 字面量；其他字段通过标准 JSON 编码转义。不经过 int / JavaScript number 转换。缺失标识的独立旧调用保留原三字段请求；宿主明确空标识仍由页面保护拒绝签发。

验证：`flutter test test/enterprise_oa` 131 项通过，新增真实请求字节断言（最大 int64）与非法标识不发送检查；adapter 为本地合成响应，未访问真实服务。针对修改源文件与测试的 flutter analyze 无问题，diff 空白检查通过。日志 `/tmp/gz-oa-bound-request-test.log`、`/tmp/gz-oa-bound-request-analyze.log`。

本步完成企业字段传递，不证明企业应用配置发现、签发交换全链路、同源 OA Cookie 隔离或服务端退出。上下文变化后页面仍锁住登录恢复，需接入经服务端验证的当前企业应用配置后解除。无真机或生产验收，整体目标继续推进。
