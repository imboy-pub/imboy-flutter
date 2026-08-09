# DF-14 群相册 → 群文件 → 媒体预览

> 优先级：P1
> 状态：`TODO`

## 1. 目标

验证群成员可以查看群相册、打开图片详情、浏览群文件，并在有测试音频素材时完成预览。

## 2. 前置条件

- [ ] 使用非生产测试群和专用图片、音频、文件素材。
- [ ] 确认当前账号具备读取群内容的权限。
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

- 群文件音频预览当前明确依赖真实音频素材。
- 附件读取依赖授权 URL 和测试素材，不能只看页面占位符。

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/group_content_flow_test.dart`，第一版使用固定测试图片和只读文件列表。
