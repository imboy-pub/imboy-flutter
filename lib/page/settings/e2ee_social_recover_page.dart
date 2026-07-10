import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart'
    show kE2eeRecoveryNeededKey;
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// E2EE 社交恢复 - 恢复密钥页面
/// 零信任架构：通过代理分片恢复密钥
class E2EESocialRecoverPage extends StatefulWidget {
  const E2EESocialRecoverPage({super.key});

  @override
  State<E2EESocialRecoverPage> createState() => _E2EESocialRecoverPageState();
}

class _E2EESocialRecoverPageState extends State<E2EESocialRecoverPage> {
  bool _isLoading = true;
  bool _isRecovering = false;
  List<Map<String, dynamic>> _shards = [];

  // 零信任架构：自动联系代理收集解密分片
  int _collectedCount = 0;
  String? _currentProxyName;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _statusMessage = t.main.e2eePreparing;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadShards();
      }
    });
  }

  Future<void> _loadShards() async {
    setState(() {
      _isLoading = true;
      _statusMessage = t.common.e2eeLoadingShards;
    });

    try {
      // 零信任架构：服务端返回空列表，实际分片存储在代理设备
      // 这里我们使用模拟数据来展示 UI，实际实现需要从本地存储获取分片信息
      final shards = await E2EESocialService.getShards();

      // 如果服务端返回空列表（零信任架构），从本地存储读取
      if (shards.isEmpty) {
        final localShards = await _loadLocalShards();
        setState(() {
          _shards = localShards;
          _isLoading = false;
          _statusMessage = localShards.isEmpty
              ? t.common.e2eeNoShards
              : t.chat.e2eeReady;
        });
      } else {
        setState(() {
          _shards = shards;
          _isLoading = false;
          _statusMessage = t.chat.e2eeReady;
        });
      }
    } on Exception {
      setState(() {
        _isLoading = false;
        _shards = [];
        _statusMessage = t.common.e2eeLoadFailed;
      });
    }
  }

  /// 从本地存储加载分片信息（零信任架构）
  Future<List<Map<String, dynamic>>> _loadLocalShards() async {
    try {
      // 零信任架构：从本地安全存储读取分片元数据
      final shards = await E2EESocialService.getLocalShardMetadata();

      setState(() {
        _shards = shards;
        _isLoading = false;
        _statusMessage = shards.isEmpty
            ? t.common.e2eeNoShards
            : t.chat.e2eeReadyWithShards(count: shards.length);
      });

      return shards;
    } on Exception {
      setState(() {
        _isLoading = false;
        _shards = [];
        _statusMessage = t.common.e2eeLoadFailed;
      });
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final threshold = _shards.isNotEmpty
        ? (_shards[0]['threshold'] as int? ?? 2)
        : 2;
    final totalShards = _shards.length;
    final canRecover = totalShards >= threshold;

    return Scaffold(
      appBar: AppBar(title: Text(t.main.e2eeRecoverKeyTitle)),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                _buildInfoCard(threshold, totalShards, canRecover),
                const SizedBox(height: AppSpacing.regular),
                if (_isRecovering) _buildProgressCard(threshold),
                if (!_isRecovering && _shards.isNotEmpty) _buildShardsList(),
                if (!_isRecovering && _shards.isEmpty) _buildEmptyView(),
                if (!_isRecovering) _buildRecoverButton(canRecover, threshold),
              ],
            ),
    );
  }

  Widget _buildInfoCard(int threshold, int totalShards, bool canRecover) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canRecover
              ? [
                  AppColors.iosGreen.withValues(alpha: 0.1),
                  AppColors.iosGreen.withValues(alpha: 0.2),
                ]
              : [
                  AppColors.iosOrange.withValues(alpha: 0.1),
                  AppColors.iosOrange.withValues(alpha: 0.2),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  canRecover
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.info,
                  color: canRecover ? AppColors.iosGreen : AppColors.iosOrange,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canRecover
                            ? t.main.e2eeCanRecoverKey
                            : t.main.e2eeInsufficientShards,
                        style: context.textStyle(
                          FontSizeType.large,
                          fontWeight: FontWeight.bold,
                          color: canRecover
                              ? AppColors.iosGreen
                              : AppColors.iosOrange,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.tiny),
                      Text(
                        t.common.e2eeShardAvailableInfo(
                          available: totalShards,
                          required: threshold,
                        ),
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: canRecover
                              ? AppColors.iosGreen
                              : AppColors.iosOrange,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.tiny),
                      Text(
                        t.main.e2eeSocialZeroTrustHint1,
                        style: context.textStyle(
                          FontSizeType.caption2,
                          color: AppColors.iosGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int threshold) {
    final progress = _collectedCount / threshold;
    final progressColor = progress >= 1.0
        ? AppColors.iosGreen
        : AppColors.iosBlue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.regular),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CupertinoActivityIndicator(radius: 10),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusMessage,
                          style: context.textStyle(
                            FontSizeType.medium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_currentProxyName != null) ...[
                          const SizedBox(height: AppSpacing.tiny),
                          Text(
                            t.common.e2eeContactingProxy(
                              name: _currentProxyName!,
                            ),
                            style: context.textStyle(
                              FontSizeType.footnote,
                              color: AppColors.iosGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.regular),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                color: progressColor,
                backgroundColor: AppColors.iosGray5,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                t.main.e2eeRecoveryProgressLabel(
                  collected: _collectedCount,
                  total: threshold,
                ),
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.iosGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShardsList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
        itemCount: _shards.length,
        itemBuilder: (context, index) {
          final shard = _shards[index];
          return _buildShardCard(shard);
        },
      ),
    );
  }

  Widget _buildShardCard(Map<String, dynamic> shard) {
    final proxyUid = shard['proxy_uid']?.toString() ?? t.common.unknown;
    final shardIndex = shard['shard_index'] ?? 0;
    final totalShards = shard['total_shards'] ?? 3;
    final status = shard['status']?.toString() ?? 'unknown';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'active':
        statusColor = AppColors.iosGreen;
        statusIcon = CupertinoIcons.checkmark_circle_fill;
        break;
      case 'pending':
        statusColor = AppColors.iosOrange;
        statusIcon = CupertinoIcons.time;
        break;
      default:
        statusColor = AppColors.iosGray;
        statusIcon = CupertinoIcons.question_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: AppRadius.borderRadiusSmall,
          ),
          child: Center(
            child: Text(
              '${shardIndex + 1}',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text(t.main.e2eeProxyUser(uid: proxyUid)),
        subtitle: Text(
          t.main.e2eeShardLabel(
            index: shardIndex as Object,
            total: totalShards as Object,
          ),
        ),
        trailing: Icon(statusIcon, color: statusColor, size: 20),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Expanded(
      child: NoDataView(
        text: t.common.e2eeNoRecoveryShards,
        description: t.main.e2eeSocialZeroTrustHint2,
        icon: CupertinoIcons.info,
        iconSize: 64,
        onTop: _loadShards,
        retryLabel: t.main.e2eeReloadShards,
      ),
    );
  }

  Widget _buildRecoverButton(bool canRecover, int threshold) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightTextPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: CupertinoButton.filled(
          onPressed: (canRecover && !_isRecovering) ? _startRecovery : null,
          child: _isRecovering
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 10),
                    const SizedBox(width: AppSpacing.small),
                    Text(t.main.e2eeRecovering),
                  ],
                )
              : Text(
                  canRecover
                      ? t.error.e2eeStartRecoveryBtn(required: threshold)
                      : t.error.e2eeInsufficientShardBtn(
                          required: threshold,
                          current: _shards.length,
                        ),
                ),
        ),
      ),
    );
  }

  Future<void> _startRecovery() async {
    setState(() => _isRecovering = true);

    try {
      final threshold = _shards.isNotEmpty
          ? (_shards[0]['threshold'] as int? ?? 2)
          : 2;

      // 零信任架构：自动联系代理收集解密分片
      final success = await E2EESocialService.recoverKeyWithProxies(
        shards: _shards,
        threshold: threshold,
        onProgress: (collected, total) {
          if (mounted) {
            setState(() {
              _collectedCount = collected;
              if (collected < total) {
                final shard = _shards[collected];
                _currentProxyName = shard['proxy_uid']?.toString() ?? '';
                _statusMessage = t.main.e2eeCollectingShards(
                  collected: collected,
                  total: threshold,
                );
              } else {
                _statusMessage = t.main.e2eeShardsCollected;
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isRecovering = false);

        if (success) {
          // P2-5: 恢复成功后清空 E2EE 解密缓存并清除「恢复待办」横幅标记，
          // 使本地已下载的密文消息在下次渲染时用恢复后的私钥重新解密显示。
          E2EEService.clearCache();
          unawaited(StorageService.to.setBool(kE2eeRecoveryNeededKey, false));
          showCupertinoDialog<void>(
            context: context,
            builder: (context) {
              return CupertinoAlertDialog(
                title: Text(t.common.e2eeRecoverSuccess),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.main.e2eeKeyRestored),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      t.main.e2eeUsedShards(count: _collectedCount),
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.iosGray,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      t.main.e2eeSocialZeroTrustHint3,
                      style: context.textStyle(
                        FontSizeType.tiny,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    child: Text(t.common.buttonOk),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          );
        } else {
          showCupertinoDialog<void>(
            context: context,
            builder: (context) {
              return CupertinoAlertDialog(
                title: Text(t.common.e2eeRecoverFailed),
                content: Text(_statusMessage),
                actions: [
                  CupertinoDialogAction(
                    child: Text(t.common.buttonRetry),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoDialogAction(
                    child: Text(t.common.buttonCancel),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              );
            },
          );
        }
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _isRecovering = false;
          _statusMessage = t.common.e2eeRecoveryFailed;
        });

        showCupertinoDialog<void>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text(t.common.e2eeRecoverFailed),
              content: Text(t.common.e2eeRecoverKeyFailed),
              actions: [
                CupertinoDialogAction(
                  child: Text(t.common.buttonRetry),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  child: Text(t.common.buttonCancel),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      }
    }
  }
}
