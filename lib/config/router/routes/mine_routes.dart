library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:feedback/feedback.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/store/model/feedback_model.dart';
import '../barrel/pages_barrel.dart';

List<RouteBase> mineRoutes() => [
  // ==================== 个人中心相关 ====================
  GoRoute(
    path: AppRoutes.mine,
    name: 'mine',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const MinePage()),
  ),
  GoRoute(
    path: '/mine/setting',
    name: 'mine_setting',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const SettingPage()),
  ),
  GoRoute(
    path: '/wallet',
    name: 'wallet',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const WalletPage()),
  ),
  GoRoute(
    path: '/wallet/withdraw',
    name: 'wallet_withdraw',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const WithdrawPage()),
  ),
  GoRoute(
    path: '/red_packet_send',
    name: 'red_packet_send',
    pageBuilder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      return CupertinoPage(
        key: state.pageKey,
        child: RedPacketSendPage(
          chatType: extra?['type'] as String? ?? 'C2C',
          toUid: extra?['to'] as String? ?? '',
        ),
      );
    },
  ),
  GoRoute(
    path: '/red_packet_detail',
    name: 'red_packet_detail',
    pageBuilder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      return CupertinoPage(
        key: state.pageKey,
        child: RedPacketDetailPage(
          packetId: extra?['packetId'] as String? ?? '',
        ),
      );
    },
  ),
  GoRoute(
    path: '/transfer_send',
    name: 'transfer_send',
    pageBuilder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      return CupertinoPage(
        key: state.pageKey,
        child: TransferSendPage(toUid: extra?['to'] as String? ?? ''),
      );
    },
  ),
  GoRoute(
    path: '/favorites',
    name: 'favorites',
    pageBuilder: (context, state) {
      // 选择模式（从聊天「收藏」附件项进入）需要 isSelect + peer；
      // 无 extra 的普通入口回退到默认（isSelect=false, peer={}）
      final extra = state.extra as Map<String, dynamic>?;
      return CupertinoPage(
        key: state.pageKey,
        child: UserCollectPage(
          isSelect: extra?['isSelect'] as bool? ?? false,
          peer: (extra?['peer'] as Map?)?.cast<String, String>() ?? const {},
        ),
      );
    },
  ),
  GoRoute(
    path: '/denylist',
    name: 'denylist',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: DenylistPage()),
  ),
  GoRoute(
    path: '/storage_space',
    name: 'storage_space',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: StorageSpacePage()),
  ),
  GoRoute(
    path: '/devices',
    name: 'devices',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const UserDevicePage()),
  ),
  GoRoute(
    path: '/settings',
    name: 'settings',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: SettingPage()),
  ),
  GoRoute(
    path: '/account_security',
    name: 'account_security',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const AccountSecurityPage()),
  ),
  GoRoute(
    path: '/language',
    name: 'language',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const LanguagePage()),
  ),
  GoRoute(
    path: '/dark_model',
    name: 'dark_model',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const DarkModelPage()),
  ),
  GoRoute(
    path: '/font_size',
    name: 'font_size',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const FontSizePage()),
  ),
  GoRoute(
    path: '/logout_account',
    name: 'logout_account',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const LogoutAccountPage()),
  ),
  GoRoute(
    path: '/e2ee_key_recovery',
    name: 'e2ee_key_recovery',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const E2EEKeyRecoveryPage()),
  ),
  GoRoute(
    path: '/e2ee_transfer',
    name: 'e2ee_transfer',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const E2EETransferPage()),
  ),
  GoRoute(
    path: '/e2ee_social',
    name: 'e2ee_social',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const E2EESocialPage()),
  ),
  GoRoute(
    path: '/e2ee_social_create',
    name: 'e2ee_social_create',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const E2EESocialCreatePage()),
  ),
  GoRoute(
    path: '/e2ee_social_recover',
    name: 'e2ee_social_recover',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const E2EESocialRecoverPage()),
  ),
  GoRoute(
    path: '/e2ee_social_manage',
    name: 'e2ee_social_manage',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const E2EESocialManagePage()),
  ),
  GoRoute(
    path: '/e2ee_proxy_selector',
    name: 'e2ee_proxy_selector',
    pageBuilder: (context, state) {
      final extra = state.extra as Map<String, dynamic>? ?? {};
      final selectedUids = extra['selectedUids'] as List<String>? ?? [];
      final requiredCount = extra['requiredCount'] as int? ?? 3;
      return CupertinoPage(
        key: state.pageKey,
        child: E2EEProxySelectorPage(
          selectedUids: selectedUids,
          requiredCount: requiredCount,
        ),
      );
    },
  ),
  GoRoute(
    path: '/e2ee_backup_export',
    name: 'e2ee_backup_export',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const E2EEBackupExportPage()),
  ),
  GoRoute(
    path: '/e2ee_backup_import',
    name: 'e2ee_backup_import',
    pageBuilder: (context, state) {
      final extra = state.extra as Map<String, dynamic>? ?? {};
      final initialFilePath = extra['initialFilePath'] as String?;
      return CupertinoPage(
        key: state.pageKey,
        child: E2EEBackupImportPage(initialFilePath: initialFilePath),
      );
    },
  ),
  GoRoute(
    path: '/e2ee_transfer_send',
    name: 'e2ee_transfer_send',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const E2EETransferSendPage()),
  ),
  GoRoute(
    path: '/e2ee_transfer_receive',
    name: 'e2ee_transfer_receive',
    pageBuilder: (context, state) {
      final extra = state.extra as Map<String, dynamic>? ?? {};
      final sessionId = extra['sessionId'] as String?;
      return CupertinoPage(
        key: state.pageKey,
        child: E2EETransferReceivePage(sessionId: sessionId),
      );
    },
  ),
  GoRoute(
    path: '/change_password',
    name: 'change_password',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const ChangePasswordPage()),
  ),
  GoRoute(
    path: '/feedback',
    name: 'feedback',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: const BetterFeedback(
        mode: FeedbackMode.navigate,
        child: FeedbackPage(),
      ),
    ),
    routes: [
      GoRoute(
        path: '/detail/:feedbackId',
        name: 'feedback_detail',
        pageBuilder: (context, state) {
          // 从状态管理或其他方式获取 model 数据
          // 这里需要传递 FeedbackModel，可以通过 state.extra 或其他方式
          final extra = state.extra as Map<String, dynamic>?;
          final model = extra?['model'] as FeedbackModel?;
          if (model == null) {
            return CupertinoPage(
              key: state.pageKey,
              child: Scaffold(
                body: Center(child: Text('Feedback model not found')),
              ),
            );
          }
          return CupertinoPage(
            key: state.pageKey,
            child: FeedbackDetailPage(model: model),
          );
        },
      ),
    ],
  ),
  GoRoute(
    path: '/select_region',
    name: 'select_region',
    pageBuilder: (context, state) {
      // 从 state.extra 获取参数
      final extra = state.extra as Map<String, dynamic>?;
      final parent = extra?['parent']?.toString() ?? '';
      final children = extra?['children'] as List? ?? [];
      final callback =
          extra?['callback'] as Future<bool> Function(String, String)? ??
          (a, b) async => true;
      final outCallback =
          extra?['outCallback'] as Future<bool> Function(String)? ??
          (a) async => true;

      return CupertinoPage(
        key: state.pageKey,
        child: SelectRegionPage(
          parent: parent,
          children: children,
          callback: callback,
          outCallback: outCallback,
        ),
      );
    },
  ),
];
