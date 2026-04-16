/// 图片预览初始页计算 —— 纯函数（零外部依赖）
///
/// slice-C-10: `chat_page.dart` L2402-2405 内联的初始页计算
/// 依赖 urls 列表和当前图片 URL，提取后可独立单测钉死所有边界契约。
library;

/// 计算图片画廊预览的初始页码。
///
/// - [imageUrls]   当前会话所有图片 URL 列表（有序）
/// - [currentUrl]  用户点击的图片 URL
///
/// 返回 [currentUrl] 在列表中第一次出现的下标；
/// 不存在（包括空列表、空字符串、未命中）时安全回退到 0。
int resolveInitialImagePage(List<String> imageUrls, String currentUrl) {
  final index = imageUrls.indexOf(currentUrl);
  return index >= 0 ? index : 0;
}
