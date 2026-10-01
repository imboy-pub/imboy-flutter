# 群资料列表失败及迟到请求

源码基线：06c1fc692753c7f50f001c0844e428bb83f43b20，最终源码 hash 见配套 evidence/source-sha256.txt。

原页面加载失败只设置 _error，已有 _files 时错误视图不展示，因此权限拒绝后仍保留旧列表；旧请求还能回写并清掉新错误。修复在共享 _loadFiles 路径采用请求 generation 与账号检查，成功/失败都只接受当前请求。当前加载失败清掉旧文件、分类统计并失效进行中的统计请求，显示已有错误/重试视图；统计响应同样检查 generation/账号。不保留离线旧列表掩盖加载失败，列表/搜索/筛选/刷新沿用原有服务，授权下载沿用 resolveFresh。既有归一化/过滤提为私有函数，修改后的加载函数 43 行，源文件 790 行，无新依赖。

新受控 widget 回归：已有 old-file → pending old 搜索 → 当前搜索拒绝(403) → 无旧文件且显示错误 → 旧搜索成功返回 late-file → 错误仍在、无 late-file。基线失败（旧文件仍显示），修复后 21 项 widget 检查通过；同次 API 套件五项因未登录跳过，必须记为 PENDING，不能算实际后端通过。三文件 analyze 无问题，diff --check 通过，人工复核全部加载入口及成功/失败写回；没有独立 agent 审查。

命令：flutter test test/unit_test/page/group/file/group_file_page_test.dart test/unit_test/api/group_file_api_test.dart；flutter analyze 三个配套 source hash 文件。完整原始日志见 evidence/group-file-request-order-2026-10-01/。本证据是受控客户端检查，不证明真实企业退出/存储撤权、已有签名 URL 立即失效、其他持久缓存清理、真机或可投产。六项目标继续，未执行外向操作。
