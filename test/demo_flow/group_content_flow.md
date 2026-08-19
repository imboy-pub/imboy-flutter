# DF-14 群相册 → 群文件 → 媒体预览

> 优先级：P1
> 状态：`本地相册/文件/照片上传与 view_url 授权访问全闭环通过（2026-08-19：上传阻塞已由人工解除，附件授权链路历史首次闭环） / 生产只读契约维持 / 媒体预览 UI 闭环阻塞（待真机与真实素材）`

## 1. 目标

验证群成员可以查看群相册、打开图片详情、浏览群文件，并在有测试音频素材时完成预览。

## 2. 前置条件

- [ ] 使用非生产测试群和专用图片、音频、文件素材。
- [x] 确认当前账号具备读取群内容的权限。（2026-08-17 本地与生产列表/详情只读均 code=0）
- [ ] 上传、删除和分享素材需要人工确认；默认不删除真实文件。

## 3. TODO 步骤

- [ ] 打开群相册并查看九宫格。
  - 预期：缩略图、空态和加载失败重试正确。
  - 页面计划：[group_album_page.md](../auto_test/group/group_album_page.md)、[group_album_photo_page.md](../auto_test/group/group_album_photo_page.md)
- [ ] 点击图片进入详情并缩放/浏览。
  - 预期：图片授权 URL、加载状态和返回路径正确。
  - 页面计划：[group_album_photo_detail_page.md](../auto_test/group/group_album_photo_detail_page.md)
- [ ] 打开群文件并按类型查看列表。
  - 预期：文件列表、分类统计、下载/预览入口正确。
  - 页面计划：[group_file_page.md](../auto_test/group/group_file_page.md)
- [ ] 在存在测试音频时打开音频预览。
  - 预期：准备中、播放失败和返回状态明确。
  - 页面计划：[group_file_audio_preview_page.md](../auto_test/group/group_file_audio_preview_page.md)

## 4. 验收标准

- [ ] 相册、图片详情、文件列表和媒体预览分别有证据。
- [ ] 无素材时标记 `阻塞`，不通过合成或真实用户文件冒充。
- [ ] 权限失败不会误显示文件内容。

## 5. 当前覆盖与阻塞

- 2026-08-19（DEMO-FLOW-20260819）**上传阻塞解除 + 附件授权链路历史首次闭环**：`group_content_local_api_flow_test.dart` 复跑两轮均 `3 passed + 0 skipped All tests passed`（08-17/08-18 为 1 过 2 受控跳）。
  - **环境复核（本轮最先确认的解锁事实，均只读探测）**：本地 Garage 已启动（`127.0.0.1:3900` LISTEN，garage 进程）；运行 release `_rel/imboy/releases/1.0.0-alpha.36/sys.config` 的 `garage.endpoint` 已改为 `http://127.0.0.1:3900`（08-18 记录为过期 IP `192.168.1.150:3900`）；后端 beam 今日 10:25 重启加载新配置。08-18 记录的解锁条件（改 garage.endpoint 并重启后端 + 对象存储在线）**已由人工完成**，本轮仅复核与复跑，未改任何配置。
  - 群文件：`POST /api/v1/group/file/upload`（304 字节 DEMO-FLOW-20260819-FILE 代码生成文本）→ `code=0 msg=success`（file_id=`file_<ts>_<xid>` 形态）→ `group/file/list` 列表回读命中 → **`GET /api/v1/attachment/view_url?object_key=<file_id>/<file_name>` 签发 code=0 → 授权 URL 下载 HTTP 200 且内容与上传逐字节一致（304 B）**。这是本 flow 首次完整走通"上传→列表→view_url 签发→内容回读"授权链路，证明后端 BUG#137 修复（上传补写 scope=group attachment 记录）在本地实测生效。
  - 测试修正（integration_test/demo_flow，本轮唯一测试改动）：group_file 表实际无 object_key 列（`file_url` 列存 Garage 私桶裸 URL，不能直接当 object_key），原测试读 `object_key/url` 字段恒空导致 view_url 段被跳过；已按 BUG#137 修复写入 attachment 表的 `path = <file_id>/<file_name>` 格式构造 object_key，view_url 段随上传成功自动执行。
  - 群相册：`group_album/create` code=0（album_id=`album_<ts>_<xid>`）→ 列表回读命中；照片上传（1x1 代码生成 PNG）`code=0 msg=上传成功` → `group_album/photo/list` 回读命中——照片上传同样随对象存储解锁恢复。
  - 生产只读复跑（`.env.pro` read_env 提取，零写入）：`group_album_api_test.dart` 3 过 3 跳（生产样本群无相册）+ `group_file_api_test.dart` 5 过，合计 8 过 3 跳 0 失败，维持 08-17 口径。
  - 跨会话数据漂移（并行 flow 共用账号）：08-18 使用的测试群 `gid=107539326623287296` 已不在 `group/page` 列表（疑被其他会话处置）；且实测 `attr=join` 过滤不含当前账号自建（owner）群——DF-14 定位用 attr=join 连续两轮未命中同名群，各轮自举新建 `gid=107850811471824896`、`gid=107852100410804224`（title 均为常量 `DEMO-FLOW-20260817-COLLAB`，单成员可回收）；DF-15 用 attr=owner 可正常命中。后续轮次建议本 flow 定位也改用 attr=owner 减少重复建群。
  - 新增可回收数据（全部 DEMO-FLOW-20260819 前缀）：文件 2 份、相册 2 个、照片 2 张、自举群 2 个（群名沿用历史常量）；未删除任何文件/相册（前置条件"默认不删除"维持）。
- 2026-08-18 后端升级后复跑 + s3.imboy.pub 探测（本地后端已升级 `1.0.0-alpha.36` release，beam 08:46 启动）：`group_content_local_api_flow_test.dart` 复跑 `1 passed + 2 skipped（受控）All tests passed`，与 08-17 一致，无回归。
  - 群相册：创建 code=0（album_id=`album_1787029307675_96890` 形态）→ 列表回读命中，维持通过。
  - 群文件上传：304 字节代码生成文本 → HTTP 200 但业务 `code=950 msg=文件上传失败`（后端转存超时约 30s 后失败）；照片上传 `code=500 msg=上传失败`，均受控 skip 维持。
  - **新根因证据（后端仓只读定位）**：`imboy/config/sys.local.config` 与 `config/sys.runtime.config` 中 `upload_url` 已改为 `https://s3.imboy.pub`（34 行），但该字段仅是 `index_handler.erl:56` 暴露给客户端的展示性配置；上传核心路径 `elib_oss.erl` 的 `upload_to_storage/4`（369 行）、`put_object/4`（94 行）、`presign_put/3`（110 行）全部读 `garage_config()` 的 `endpoint`，运行 release（`_rel/imboy/releases/1.0.0-alpha.36/sys.config`）中仍为 `http://192.168.1.150:3900`（过期 LAN IP，本机现为 192.168.0.98）→ 上传仍连不可达地址。**结论：仅改 upload_url 不解锁上传，需同步改 garage.endpoint 并重启后端。**
  - s3.imboy.pub 可达性探测（只读，未写入）：域名在线，HTTPS TLS1.3 证书 CN=s3.imboy.pub 验证通过，根路径返回 404 `Code: NoSuchKey`（Garage S3 典型错误格式）；无签名 PUT 探测返回 400（被拒，无写入）。但本机 DNS 被 TUN 代理 fake-ip（198.18.0.94）遮蔽，公共解析器（223.5.5.5/114.114.114.114）查询也被劫持返回 fake-ip，**无法确认该域名真实指向本地/授权对象存储**；且运行中后端配置未指向它。按安全协议本轮未向 s3.imboy.pub 写入任何测试对象。本机无 Garage 进程、无 docker 容器、3900/3902 端口无监听。
- 2026-08-17 本地媒体链路 API 级验收（新增 `integration_test/demo_flow/group_content_local_api_flow_test.dart`，纯 Dart 无设备，本地 alpha.27 + 测试账号 13900001002 + 测试群 `DEMO-FLOW-20260817-COLLAB`）：最终 `1 passed + 2 skipped（受控）All tests passed`。
  - 群相册：`POST /api/v1/group_album/create` code=0（msg=创建相册成功，album_id=`album_<ts>_<xid>` 形态）→ `group_album/list` 列表回读命中。相册元数据（DB 级）闭环通过。
  - 群文件上传：multipart（304 字节代码生成文本，无 PII）→ HTTP 200 但业务 `code=950 msg=文件上传失败`（后端转存 Garage 失败），按对象存储阻塞受控 skip。
  - 相册照片上传：代码生成 1x1 PNG（非真实照片）→ HTTP 200 但业务 `code=500 msg=上传失败`，同上受控 skip。
- 2026-08-17 附件链路探查（后端仓只读）：`imboy/config/sys.local.config` 配置 Garage endpoint `http://192.168.1.150:3900`、bucket `imboy`、public_base_url `:3902`；当前本机 IP 已变为 `192.168.0.98`，`192.168.1.150:3900/3902` 与 `127.0.0.1:3900/3902` 均连接失败，docker 无 Garage 容器运行 → **本地对象存储不在线是上传阻塞的直接原因**。解锁需要：启动本地 Garage（S3 API 3900 + web 3902）、按当前本机 IP 更新 `sys.local.config` endpoint 并重启后端（本轮未做，不干预其他会话的后端进程）。
- view_url 授权链路（`GET /api/v1/attachment/view_url?object_key=`，600s 签发）契约存在（lib/service/asset_url_resolver.dart），但本轮无成功上传对象，授权访问与内容回读未形成证据，随上传阻塞。
- 2026-08-17 生产只读复跑（`.env.pro`，alpha.36）：`group_album_api_test.dart` 3 通过 + 3 skip（生产样本群无相册）；`group_file_api_test.dart` 5 通过 0 失败。均为只读，未在生产上传/删除。
- 群文件音频预览当前明确依赖真实音频素材。
- 附件读取依赖授权 URL 和测试素材，不能只看页面占位符。
- 2026-08-09：群相册和群文件只读 API 检查计入本轮 `39 passed, 3 skipped, 0 failed` 汇总。
- 首轮批量测试的 6 项失败集中在 `group_album_photo_navigation_test.dart` 3 项、`group_file_page_test.dart` 3 项，根因为页面 Cupertino 图标/稳定 key 已变更而测试定位器过期；已修正测试定位器，两个文件复跑 `29 passed, 0 failed`。
- 图片详情、文件入口和媒体预览的完整业务闭环仍因真实素材/媒体环境不足保持 `BLOCKED`；测试定位器修复不等于服务端附件链路通过。

## 6. 未来自动化目标

`integration_test/demo_flow/group_content_local_api_flow_test.dart` 已完成对象存储解锁后的完整闭环验证（2026-08-19）：上传成功路径自动验证列表回读、view_url 签发与下载内容一致。后续改进：群定位从 attr=join 改为 attr=owner（见 08-19 漂移记录）；UI 级（九宫格/图片详情/音频预览）仍建议后续用固定测试素材补 `flutter test` 页面用例（音频预览依赖真实素材）。
