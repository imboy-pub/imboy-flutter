import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'storage_space_logic.dart';
import 'storage_space_state.dart';

class StorageSpacePage extends StatelessWidget {
  StorageSpacePage({super.key});

  final StorageSpaceLogic logic = Get.put(StorageSpaceLogic());
  final StorageSpaceState state = Get.find<StorageSpaceLogic>().state;

  @override
  Widget build(BuildContext context) {
    // 初始化数据
    logic.initData();

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'storageSpace'.tr,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildStorageOverview(),
              const SizedBox(height: 16),
              _buildAppUsageSection(),
              const SizedBox(height: 8),
              _buildStorageDetailCards(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Storage progress bar
        LayoutBuilder(
          builder: (context, constraints) {
            return Obx(() {
              final totalWidth = constraints.maxWidth;
              final totalSpace = state.totalDiskSpace.value;
              final usedSpace = state.usedDiskSpace.value;
              final freeSpace = state.freeDiskSpace.value;
              final appBytes = state.appAllBytes.value;

              // Calculate ratios with safety checks
              final usedRatio = totalSpace > 0 ? usedSpace / totalSpace : 0.0;
              final appRatio = usedSpace > 0
                  ? (appBytes / usedSpace).clamp(0.01, 1.0)
                  : 0.01;

              // Ensure free space width is non-negative
              double freeWidth = totalSpace > 0
                  ? (totalWidth * (freeSpace / totalSpace)).clamp(0, totalWidth)
                  : 0.0;

              return SizedBox(
                width: totalWidth,
                height: 20,
                child: Stack(
                  children: [
                    // Used space (with app portion)
                    SizedBox(
                      height: 20,
                      width: totalWidth * usedRatio,
                      child: LinearProgressIndicator(
                        value: appRatio,
                        backgroundColor: Colors.amber,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                    ),
                    // Free space
                    Positioned(
                      right: 0,
                      child: SizedBox(
                        height: 20,
                        width: freeWidth,
                        child: const LinearProgressIndicator(
                          value: 1,
                          backgroundColor: Colors.grey,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            });
          },
        ),
        const SizedBox(height: 8),
        // Legend
        Obx(
              () => Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                Colors.green,
                '$appName${'usedSpace'.tr}${formatBytes(state.appAllBytes.value, num: 1000)}',
              ),
              _buildLegendItem(
                Colors.amber,
                'deviceUsedSpace'.tr +
                    formatBytes(state.usedDiskSpace.value, num: 1000),
              ),
              _buildLegendItem(
                Colors.grey,
                'deviceAvailableSpace'.tr +
                    formatBytes(state.freeDiskSpace.value, num: 1000),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.square, color: color, size: 12),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildAppUsageSection() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appName + 'usedSpace'.tr, style: Get.textTheme.titleMedium),
          Text(
            formatBytes(state.appAllBytes.value, num: 1000),
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
          ),
          Text(
            'tipDeviceSpace'.trArgs([
              state.totalDiskSpace.value > 0
                  ? ((state.appAllBytes.value / state.totalDiskSpace.value) *
                            1000)
                        .toStringAsFixed(3)
                  : '0',
              formatBytes(state.totalDiskSpace.value, num: 1000),
            ]),
            style: Get.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageDetailCards() {
    return Obx(
      () => Column(
        children: [
          _buildStorageCard(
            title: appName + 'cache'.tr,
            value: state.cacheBytes.value,
            description: 'cacheTips'.tr,
            action: ElevatedButton(
              onPressed: () async {
                bool res = await logic.clearAllCache();
                if (res) {
                  EasyLoading.showSuccess('tipSuccess'.tr);
                } else {
                  EasyLoading.showError('tipFailed'.tr);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(60, 28),
              ),
              child: Text('clean'.tr, style: const TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 8),
          _buildStorageCard(
            title: 'userData'.tr,
            value: state.dataBytes.value,
            description: 'userDataTips'.tr,
          ),
          const SizedBox(height: 8),
          _buildStorageCard(
            title: 'appSize'.tr,
            value: state.appBytes.value,
            description: 'appSizeTips'.tr,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard({
    required String title,
    required int value,
    required String description,
    Widget? action,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Get.textTheme.titleMedium),
                const Spacer(),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatBytes(value, num: 1000),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(description, style: Get.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
