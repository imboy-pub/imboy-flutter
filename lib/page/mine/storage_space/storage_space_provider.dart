import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ic_storage_space/ic_storage_space.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_space_provider.g.dart';

/// StorageSpace 模块的状态
class StorageSpaceState {
  final int totalDiskSpace;
  final int freeDiskSpace;
  final int usedDiskSpace;
  final int appBytes;
  final int cacheBytes;
  final int dataBytes;
  final int chatHistoryBytes;
  final int appAllBytes;
  final bool isLoading;

  const StorageSpaceState({
    this.totalDiskSpace = 0,
    this.freeDiskSpace = 0,
    this.usedDiskSpace = 0,
    this.appBytes = 0,
    this.cacheBytes = 0,
    this.dataBytes = 0,
    this.chatHistoryBytes = 0,
    this.appAllBytes = 0,
    this.isLoading = false,
  });

  StorageSpaceState copyWith({
    int? totalDiskSpace,
    int? freeDiskSpace,
    int? usedDiskSpace,
    int? appBytes,
    int? cacheBytes,
    int? dataBytes,
    int? chatHistoryBytes,
    int? appAllBytes,
    bool? isLoading,
  }) {
    return StorageSpaceState(
      totalDiskSpace: totalDiskSpace ?? this.totalDiskSpace,
      freeDiskSpace: freeDiskSpace ?? this.freeDiskSpace,
      usedDiskSpace: usedDiskSpace ?? this.usedDiskSpace,
      appBytes: appBytes ?? this.appBytes,
      cacheBytes: cacheBytes ?? this.cacheBytes,
      dataBytes: dataBytes ?? this.dataBytes,
      chatHistoryBytes: chatHistoryBytes ?? this.chatHistoryBytes,
      appAllBytes: appAllBytes ?? this.appAllBytes,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class StorageSpaceNotifier extends _$StorageSpaceNotifier {
  @override
  StorageSpaceState build() {
    return const StorageSpaceState();
  }

  /// 初始化数据
  Future<void> initData() async {
    state = state.copyWith(isLoading: true);
    try {
      final freeDiskSpace = await IcStorageSpace.getFreeDiskSpaceInBytes;
      final totalDiskSpace = await IcStorageSpace.getTotalDiskSpaceInBytes;
      final usedDiskSpace = await IcStorageSpace.getUsedDiskSpaceInBytes;

      state = state.copyWith(
        freeDiskSpace: freeDiskSpace,
        totalDiskSpace: totalDiskSpace,
        usedDiskSpace: usedDiskSpace,
      );

      await storageStats();

      if (kDebugMode) {
        final path = await SqliteService.to.dbPath();
        iPrint("StorageSpaceProvider dbPath $path");
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 清理所有缓存
  Future<bool> clearAllCache() async {
    bool res = await IcStorageSpace.clearAllCache();
    if (res) {
      await storageStats();
      try {
        await cacheManager.emptyCache();
      } on Exception {
        // Ignore error
      }
    }
    return res;
  }

  /// 获取存储统计信息
  Future<void> storageStats() async {
    Map<dynamic, dynamic> stats = await IcStorageSpace.storageStats;
    if (kDebugMode) iPrint("StorageSpaceProvider storageStats loaded");

    final appBytes = stats['appBytes'] ?? 0;
    final cacheBytes = stats['cacheBytes'] ?? 0;
    var dataBytes = stats['dataBytes'] ?? 0;

    if (Platform.isAndroid) {
      dataBytes = dataBytes - cacheBytes;
    }

    final appAllBytes = appBytes + cacheBytes + dataBytes;

    state = state.copyWith(
      appBytes: appBytes,
      cacheBytes: cacheBytes,
      dataBytes: dataBytes,
      appAllBytes: appAllBytes,
    );
  }

  /// 获取路径列表（调试用）
  Future<void> pathList() async {
    String home = await IcStorageSpace.homeDirectory();
    List<Object?> items2 = await IcStorageSpace.pathList(home);
    if (kDebugMode) iPrint("StorageSpaceProvider pathList loaded");
    int? size = await IcStorageSpace.pathBytes(home);
    if (kDebugMode) {
      iPrint(
        "StorageSpaceProvider pathList size: ${formatBytes(size ?? 0, num: 1000)} ; len ${items2.length} ",
      );
    }
  }
}
