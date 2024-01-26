import 'dart:io';

import 'package:get/get.dart';
import 'package:ic_storage_space/ic_storage_space.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/sqlite.dart';

import 'storage_space_state.dart';

class StorageSpaceLogic extends GetxController {
  final StorageSpaceState state = StorageSpaceState();

  Future<void> initData() async {
    state.freeDiskSpace.value = await IcStorageSpace.getFreeDiskSpaceInBytes;
    state.totalDiskSpace.value = await IcStorageSpace.getTotalDiskSpaceInBytes;
    state.usedDiskSpace.value = await IcStorageSpace.getUsedDiskSpaceInBytes;

    storageStats();

    String path = await SqliteService.to.dbPath();
    iPrint("StorageSpaceLogic dbPath $path");
    // [  +39 ms] I/flutter (30689): iPrint StorageSpaceLogic dbPath /data/user/0/pub.imboy.apk/databases/imboy_javj8a_5.db
    // [+1934 ms] I/System.out(30689): deleteFiles: /data/user/0/pub.imboy.apk/cache
    // [        ] I/System.out(30689): deleteFiles: /data/user/0/pub.imboy.apk/cache/imboy_cache_key
    // [        ] I/System.out(30689): deleteFiles: /data/user/0/pub.imboy.apk/files
    // [  +11 ms] I/System.out(30689): deleteFiles: /storage/emulated/0/Android/data/pub.imboy.apk/cache
  }

  Future<bool> clearAllCache() async {
    bool res = await IcStorageSpace.clearAllCache();
    if (res) {
      storageStats();
      try {
        await cacheManager.store.emptyCache();
      } catch (e) {
        //
      }
    }
    return res;
  }

  Future<void> storageStats() async {
    Map<dynamic, dynamic> stats = await IcStorageSpace.storageStats;
    iPrint("StorageSpace_logic storageStats ${stats.toString()}");
    state.appBytes.value = stats['appBytes'] ?? 0;
    state.cacheBytes.value = stats['cacheBytes'] ?? 0;
    state.dataBytes.value = stats['dataBytes'] ?? 0;
    if (Platform.isAndroid) {
      state.dataBytes.value =
          (stats['dataBytes'] ?? 0) - state.cacheBytes.value;
    }
    state.appAllBytes.value =
        state.appBytes.value + state.cacheBytes.value + state.dataBytes.value;
  }

  Future<void> pathList() async {
    String home = await IcStorageSpace.homeDirectory();
    List<Object?> items2 = await IcStorageSpace.pathList(home);
    iPrint("StorageSpace_logic pathList home $home ");
    int? size = await IcStorageSpace.pathBytes(home);
    iPrint(
        "StorageSpace_logic pathList size: ${formatBytes(size ?? 0, num: 1000)} ; len ${items2.length} ");

    // for (var p in items2) {
    // iPrint("StorageSpace_logic p: $p");
    // }
  }
}
