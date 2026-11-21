/// 账号导出数据保存 - 平台自适应下载（FL-13）
///
/// 条件导入：
/// - Web（dart.library.js）：浏览器 Blob 下载，落点由浏览器决定，
///   应用不承诺本地路径，也不在共享设备留下应用可读副本。
/// - 原生：写入调用方给定的账号隔离目录（AccountLocalFiles）或
///   系统临时目录，返回绝对路径供分享/审计。
///
/// 两个实现保持同一 API 形状（函数名/参数/返回类型逐一对齐）：
/// `saveAccountExportJson` / `sanitizeAccountExportFileName` /
/// `AccountExportDownloadResult`。
library;

export 'account_export_download_native.dart'
    if (dart.library.js) 'account_export_download_web.dart';
