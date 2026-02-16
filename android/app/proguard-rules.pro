# ==========================
# Flutter 默认混淆配置（建议保留）
# ==========================
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# 保留 Flutter 插件注册类
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ==========================
# 高德地图 SDK 混淆配置（增强版）
# ==========================
# 保留所有高德地图相关的类和接口
-keep class com.amap.api.** { *; }
-keep class com.autonavi.** { *; }
-keep class com.amap.location.** { *; }
-keep class com.aps.** { *; }
-keep interface com.amap.api.** { *; }
-keep class com.loc.** { *; }

# 不警告高德地图相关类
-dontwarn com.amap.api.**
-dontwarn com.autonavi.**
-dontwarn com.amap.location.**
-dontwarn com.aps.**
-dontwarn com.loc.**

# 保留高德地图 Native 库
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留高德地图的枚举类
-keepclassmembers enum com.amap.api.** {
    *;
}

# 保留高德地图的内部类
-keep class com.amap.api.**$* { *; }

# ==========================
# 高德 Flutter 插件混淆规则（增强版）
# ==========================
-keep class com.amap.flutter.** { *; }
-keep class com.amap_flutter_map_plus.** { *; }
-keep class com.amap_flutter_location_plus.** { *; }
-keep class com.amap_flutter_base_plus.** { *; }
-dontwarn com.amap.flutter.**
-dontwarn com.amap_flutter_map_plus.**
-dontwarn com.amap_flutter_location_plus.**
-dontwarn com.amap_flutter_base_plus.**

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

# ==========================
# 修复 NoClassDefFoundError 和 IndexOutOfBoundsException
# ==========================
# 保留所有集合类的访问方法
-keepclassmembers class * {
    public <methods>;
}

# 保留 Parcelable 相关类
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# 保留 Serializable 相关类
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
}

