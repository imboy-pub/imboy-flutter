# F15-S02 写者声明（WRITER CLAIM）

- **写者**：ZCode 会话（同前四卡写者）
- **身份**：F15-S02「真后端授权」的**静态设计部分**——授权语义矩阵草案与负例候选；
  运行时验证（起后端、真实夹具、协议/RBAC/幂等/租户负例执行）**未做**，
  需后端与夹具能力（F01-S02）+ 资源租约
- **写入时间**：2026-10-03T04:5xZ（本地 12:5x）
- **产物**：`authz-matrix-draft.tsv`（791 条×授权类×负例候选）、
  `rbac-roles.tsv`（6 角色）、`stats.json`、`README.md`、本文件、`state.json`

## 授权链事实来源（全部源码可溯）

- 中间件顺序：`imboy_app.erl:96-107`
- API 面判定：`src/api/auth_middleware_api_v1.erl`（open/option 直通、租户面
  fail-closed、支付回调/webhook/MCP/CS 五类特殊凭证、设备签名二级校验）
- Admin 面：`src/adm/adm_auth_middleware.erl`（cookie+HMAC）+
  `src/adm/adm_acl.erl`（RBAC 守卫）+ `adm_index_handler:role_acl/1`（6 角色）
- F12 业务 spec 只读（execution-contract 第 3 节）

## 对并行执行者的约定

同前四卡条款：本目录本会话独占至移交；接管前追加记录；公共位置冻结；
imboy 仓全程只读。
