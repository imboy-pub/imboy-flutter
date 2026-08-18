# DF-14 群相册 → 群文件 → 媒体预览

> 优先级：P1
> 状态：`API只读通过 / 本地相册创建与列表回读通过（2026-08-17） / 文件与照片上传阻塞（本地对象存储不可用） / 媒体预览闭环阻塞`

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

`integration_test/demo_flow/group_content_local_api_flow_test.dart` 已落地（相册创建回读 + 上传阻塞受控记录）；本地 Garage 上线后同一测试会在上传成功路径自动继续验证列表回读、view_url 签发与下载内容一致。UI 级（九宫格/图片详情/音频预览）仍建议后续用固定测试素材补 `flutter test` 页面用例。
