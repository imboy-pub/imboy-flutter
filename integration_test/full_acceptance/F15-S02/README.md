# F15-S02 真后端授权 — 静态设计部分（授权语义矩阵草案）

> execution-contract 第 4 节：协议、RBAC、幂等、租户负例；仅后端/夹具能力。
> 本目录交付**静态设计**：逐路由授权分类 + 每类负例候选。运行时执行未做
> （BLOCKED_ENV：需后端起服务与夹具，资源冻结中）。

## 产物索引

| 文件 | 内容 |
|---|---|
| `authz-matrix-draft.tsv` | **791 条路由 × 授权类 × 负例候选**（含 85 条幂等复核标注） |
| `rbac-roles.tsv` | Admin RBAC 6 角色：super_admin(291 权限)/ops_admin(162)/audit_admin(70)/moderator(54)/security_admin(35)/support(13) |
| `stats.json` | 分类分布、鉴权链事实（中间件顺序/开关默认值/租户 fail-closed）、待运行时复核项 |

## 授权类分布（791 条全分类）

USER_JWT_SIGNATURE 372（主体面）/ ADMIN_COOKIE_RBAC 255 / DYNAMIC_REVIEW 66 /
CS_SURFACE_REVIEW 37 / ENTERPRISE_TENANT_PRINCIPAL 16 / ANON_OPEN 17 /
ANON_OPEN_SIGNATURE 11 / SITE_PUBLIC 7 / STATIC_ASSET 4 / OPTION 3 /
支付回调签名 1 / WEBHOOK_TOKEN 1 / MCP 1。

## 设计要点（负例族的源码依据）

1. **租户面 fail-closed**：`/api/v1/enterprise/*` 与 `/api/v1/cs/*` 即使被误登记
   进 open() 也不直通（auth_middleware_api_v1 源码注释）——跨租户 403/404、
   普通 JWT 进企业面按 principal 类别拒绝，是 F09–F12 域的核心负例族。
2. **设备签名二级校验**：ws/init/refreshtoken/passport（除 Web QR 四条）open
   仍强制 verify_sign——篡改签名应 401，是 F02/F03 域的防重放负例。
3. **凭证不互采信**：CS 面 JWT 与 x-cs-visit-token/x-cs-shop-key 互混应
   credential_missing——F12 域主体混淆负例。
4. **Admin 面**：cookie+HMAC 签名（伪造=401）+ 6 角色 RBAC（低角色访问专属
   action=403「无权限操作」）；角色权限可被 config `adm_role_permissions`
   覆盖——验收实例须冻结该配置。
5. **幂等复核 85 条**：send/add/create/report/pay/order/reply/submit 语义的
   POST 路由，具体业务幂等键（消息/支付/接单）须真实夹具验证。

## 待运行时复核（open items）

- DYNAMIC_REVIEW 剩余 66 条的运行时判定；
- CS credential/seat 的路径形状二分（冻结函数 `is_cs_credential_path`/
  `is_web_seat_path` 的实际覆盖）；
- `api_auth_switch`、`adm_role_permissions` 在验收实例上的冻结值；
- 二次分类仅按前缀（enterprise/cs），EB-04 注释为据。
