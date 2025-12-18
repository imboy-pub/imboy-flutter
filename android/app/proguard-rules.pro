# ==========================
# Flutter 默认混淆配置（建议保留）
# ==========================
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# 保留 Flutter 插件注册类
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ==========================
# 高德地图 SDK 混淆配置
# ==========================
-keep class com.amap.api.** { *; }
-keep class com.autonavi.** { *; }
-keep class com.amap.location.** { *; }
-keep class com.aps.** { *; }
-keep interface com.amap.api.** { *; }
-dontwarn com.amap.api.**
-dontwarn com.autonavi.**

# ==========================
# 高德 Flutter 插件混淆规则
# ==========================
-keep class com.amap.flutter.** { *; }
-dontwarn com.amap.flutter.**

# ==========================
# WebView 支持配置（重要）
# ==========================
# 保留带有 @JavascriptInterface 的方法（用于 JS 调用 Android 原生）
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# 确保包含 WebView 使用的类不被混淆（可视情况缩小范围）
-keep class android.webkit.WebView { *; }

# 针对 webview_flutter 插件的类
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# ==========================
# 荣耀广告ID混淆规则（修复R8缺失类问题）
# ==========================
-dontwarn com.hihonor.ads.identifier.AdvertisingIdClient$Info
-dontwarn com.hihonor.ads.identifier.AdvertisingIdClient
