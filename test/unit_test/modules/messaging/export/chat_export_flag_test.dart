/// W3-J `chat_export_share_v1` rollout flag 判定测试（FLAG-01 同机制）：
/// 默认 false（fail-closed）、replaceSnapshotForTest 可开启、
/// isEnabled（编译清单路径）对该键恒 false。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';

void main() {
  tearDown(
    () => AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{}),
  );

  test('默认 false（fail-closed）', () {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
    expect(
      AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatExportShareV1),
      isFalse,
    );
  });

  test("replaceSnapshotForTest({'chat_export_share_v1': true}) 可开启", () {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
      FeatureKeys.chatExportShareV1: true,
    });
    expect(
      AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatExportShareV1),
      isTrue,
    );
  });

  test('isEnabled（编译清单路径）对该键恒 false —— 两种判定不可混用', () {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
      FeatureKeys.chatExportShareV1: true,
    });
    // chat_export_share_v1 不在 compiledProductFeatures（产品组合清单由
    // 后端 manifest 生成，不为 UI 灰度键改跨仓合同）。
    expect(
      AppFeatureRegistry.isEnabled(FeatureKeys.chatExportShareV1),
      isFalse,
    );
  });

  test('本地硬关闭集合不含该键（仅受 snapshot 控制）', () {
    // 若未来加入 _localDisabledKeys，此处会提醒同步测试。
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
      FeatureKeys.chatExportShareV1: true,
    });
    expect(
      AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatExportShareV1),
      isTrue,
    );
  });
}
