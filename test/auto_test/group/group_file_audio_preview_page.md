# `page/group/file/group_file_audio_preview_page.dart`

> 功能点 9 个 | bug 发现 9 / 解决 9 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 加载音频源并展示准备中状态 | 已通过 | 批次92 | 1 | 1 | 0 | BUG#142：原 setUrl(Garage 私桶裸 URL)→404 恒加载失败；已修=getSingleFile 提取 object_key→后端 view_url 签发 presign→播本地文件（同 BUG#137 视频页模式）。素材：python 生成 3s 440Hz wav→API multipart 上传群 99746135830431744（账号 58628） |
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 点击按钮播放与暂停切换 | 已通过 | 批次92 | 1 | 1 | 0 | 真机：dumpsys audio AudioTrack state:started（usage=MEDIA）+ 按钮「播放」→「暂停」双铁证 |
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 拖动进度条跳转播放位置 | 已通过 | 批次92 | 1 | 1 | 0 | 播放中滑块 0%→100% 全程联动正常；seek onChanged 经代码审查（Slider max=duration，value=position） |
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 实时更新播放位置与总时长 | 已通过 | 批次92 | 1 | 1 | 0 | 真机：00:00/00:03 → 00:03/00:03 实时跳变，durationStream/positionStream 正常 |
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 音频加载失败展示错误文案 | 已通过 | 批次92 | 1 | 1 | 0 | BUG#142 后加载成功未触发失败分支；catch→_errorText（t.common.groupFileAudioLoadFailed）代码层验证 |
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 标题栏展示音频文件名 | 已通过 | 批次92 | 1 | 1 | 0 | 真机：GlassAppBar 标题「test_audio_3s.wav」 |
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 退出页面时释放播放器资源 | 已通过 | 批次92 | 1 | 1 | 0 | dispose() 调用 _player.dispose()，代码层验证 |
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 时长按分秒格式化显示 | 已通过 | 批次92 | 1 | 1 | 0 | 真机：00:03 格式（padLeft 两位分秒）正确 |
| 无待办 | - | `page/group/file/group_file_audio_preview_page.dart` | 准备中或失败时禁用播放操作 | 已通过 | 批次92 | 1 | 1 | 0 | `if (_isPreparing \|\| _errorText != null) return;` 代码层验证 |
