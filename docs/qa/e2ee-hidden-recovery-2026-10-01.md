# E2EE 关闭时恢复入口遵循功能开关 / Hidden recovery entry gate

日期：2026-10-01；App 基线 dcee18cce7bdd7b67fc0260ce20d432171c6ac25。
状态：局部本地验证通过；六项完整交付与投产证明仍未完成。

共享恢复弹窗和横幅遵循 AppFeatureRegistry 的 e2ee 开关；弹窗已打开后关闭开关，恢复按钮也不导航到隐藏页面。备份向导判定在开始、异步本地读取后和远端查询后重验开关，关闭时不查询远端、不补写完成标记、不弹向导。保留密钥、备份口令、历史密文及协议行为。

English summary: Recovery dialogs, banners and automatic backup onboarding respect the existing E2EE UI feature flag. No encryption policy, historical ciphertext or stored keys are removed.

## 验证 / Checks

新测试在修复前复现四项失败，修复后以下 40 项测试通过（exit=0）：

```sh
flutter test test/unit_test/component/dialog/e2ee_recovery_guide_dialog_test.dart test/unit_test/service/e2ee_backup_setup_service_test.dart test/unit_test/app_core/feature_flags/app_feature_registry_test.dart test/unit_test/service/encryption_mode_test.dart test/unit_test/service/e2ee/encryption_mode_hard_off_test.dart test/unit_test/service/e2ee/outbound_encryption_fail_closed_test.dart
```

受影响两个源文件和两个测试文件 dart analyze 无问题，exit=0；git diff --check 通过。关闭/恢复开启、查询期间关闭、已打开弹窗点击、现有加密模式及出站禁止静默降级均覆盖。按全部共享函数调用方做本地人工复核；未使用独立审查代理。

## 局限 / Limits

未作真机验证、完整历史密文恢复或服务端加密配置验收。功能注册表不是响应式流，已显示 UI 随现有父页面重建收敛；导航动作与异步查询重验开关。入口隐藏不等于删除加密协议，也不证明全产品 E2EE 关闭已验收。无部署、对外请求或生产迁移。

## 内容绑定 / Source hashes

| File | SHA256 |
|---|---|
| lib/component/dialog/e2ee_recovery_guide_dialog.dart | `5ba061e07481c727721c0a62b756697c9741bad89a06235836d71d9bd40082bb` |
| lib/service/e2ee_backup_setup_service.dart | `eb3b60b7d98c773b1a1de6051d80324aaf5085a52be152bd388d55118d693fcd` |
| test/unit_test/component/dialog/e2ee_recovery_guide_dialog_test.dart | `88029089bae8a48a3bdd09f5b6924722554fcf14829735f967c864d460cf6f23` |
| test/unit_test/service/e2ee_backup_setup_service_test.dart | `c4fd14939f020274ea70938a290402c01f28ecfd3337342259bc85677dee1057` |
