import 'package:get/get.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class StorageSpaceState {
  RxInt totalDiskSpace = 0.obs;
  // 可用空间
  RxInt freeDiskSpace = 0.obs;
  // 已用空间
  RxInt usedDiskSpace = 0.obs;

  // APP使用空间 APP安装包大小
  // getAppBytes得到应用程序的大小。这包括 APK 文件、优化的编译器输出和解压的原生库。
  // Added in API level 26
  RxInt appBytes = 0.obs;

  // 缓存大小
  // https://developer.android.com/reference/android/app/usage/StorageStats#getCacheBytes()
  // getCacheBytes得到应用程序缓存数据的大小。这包括存储在Context.getCacheDir()和Context.getCodeCacheDir() 下的文件。
  // Context#getCacheDir()这包括存储在和下的文件 Context#getCodeCacheDir()。
  // 如果主要外部/共享存储托管在此存储设备上，则这包括存储在 Context#getExternalCacheDir().
  // iOS MacOS 的 cacheBytes  定义为 NSHomeDirectory() + "/Library/Caches" + NSHomeDirectory() + "/tmp"
  RxInt cacheBytes = 0.obs;

  // 用户数据
  // https://developer.android.com/reference/android/app/usage/StorageStats#getDataBytes()
  // 返回所有数据的大小。Context#getDataDir()这包括存储在、Context#getCacheDir()、 下的文件 Context#getCodeCacheDir()。
  // 如果主要外部/共享存储托管在此存储设备上，则这包括存储在 Context#getExternalFilesDir(String)、 Context#getExternalCacheDir()和 下 的文件Context#getExternalMediaDirs()。
  RxInt dataBytes = 0.obs;

  // 可清理所选聊天记录里的图片、视频、和文件，或者清空所选聊天记录里的所有聊天信息。
  RxInt chatHistoryBytes = 0.obs; // 属于用户数据的一部分

  RxInt get appAllBytes => (appBytes.value + dataBytes.value).obs;
  RxList<CacheObject>? cacheItems;

  StorageSpaceState() {
    ///Initialize variables
  }
}
