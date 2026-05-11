import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/theme/default/app_radius.dart';

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
    _statusMessage = t.e2eePreparing;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadShards();
      }
    });
  }

  Future<void> _loadShards() async {
    setState(() {
      _isLoading = true;
      _statusMessage = t.e2eeLoadingShards;
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
          _statusMessage = localShards.isEmpty ? t.e2eeNoShards : t.e2eeReady;
        });
      } else {
        setState(() {
          _shards = shards;
          _isLoading = false;
          _statusMessage = t.e2eeReady;
        });
      }
    } on Exception {
      setState(() {
        _isLoading = false;
        _shards = [];
        _statusMessage = t.e2eeLoadFailed;
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
            ? t.e2eeNoShards
            : t.e2eeReadyWithShards(count: shards.length);
      });

      return shards;
    } on Exception {
      setState(() {
        _isLoading = false;
        _shards = [];
        _statusMessage = t.e2eeLoadFailed;
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
      appBar: AppBar(title: Text(t.e2eeRecoverKeyTitle)),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                _buildInfoCard(threshold, totalShards, canRecover),
                const SizedBox(height: 16),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canRecover
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  canRecover ? Icons.check_circle : Icons.info_outline,
                  color: canRecover ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canRecover
                            ? t.e2eeCanRecoverKey
                            : t.e2eeInsufficientShards,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: canRecover ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.e2eeShardAvailableInfo(
                          available: totalShards,
                          required: threshold,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: canRecover
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.e2eeSocialZeroTrustHint1,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
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
    final progressColor = progress >= 1.0 ? Colors.green : Colors.blue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CupertinoActivityIndicator(radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_currentProxyName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            t.e2eeContactingProxy(name: _currentProxyName!),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                color: progressColor,
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(height: 8),
              Text(
                t.e2eeRecoveryProgressLabel(
                  collected: _collectedCount,
                  total: threshold,
                ),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _shards.length,
        itemBuilder: (context, index) {
          final shard = _shards[index];
          return _buildShardCard(shard);
        },
      ),
    );
  }

  Widget _buildShardCard(Map<String, dynamic> shard) {
    final proxyUid = shard['proxy_uid']?.toString() ?? t.unknown;
    final shardIndex = shard['shard_index'] ?? 0;
    final totalShards = shard['total_shards'] ?? 3;
    final status = shard['status']?.toString() ?? 'unknown';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
        title: Text(t.e2eeProxyUser(uid: proxyUid)),
        subtitle: Text(t.e2eeShardLabel(index: shardIndex as Object, total: totalShards as Object)),
        trailing: Icon(statusIcon, color: statusColor, size: 20),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Expanded(
      child: NoDataView(
        text: t.e2eeNoRecoveryShards,
        description: t.e2eeSocialZeroTrustHint2,
        icon: Icons.info_outline,
        iconSize: 64,
        onTop: _loadShards,
        retryLabel: t.e2eeReloadShards,
      ),
    );
  }

  Widget _buildRecoverButton(bool canRecover, int threshold) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    const SizedBox(width: 8),
                    Text(t.e2eeRecovering),
                  ],
                )
              : Text(
                  canRecover
                      ? t.e2eeStartRecoveryBtn(required: threshold)
                      : t.e2eeInsufficientShardBtn(
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
                _statusMessage = t.e2eeCollectingShards(
                  collected: collected,
                  total: threshold,
                );
              } else {
                _statusMessage = t.e2eeShardsCollected;
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isRecovering = false);

        if (success) {
          showCupertinoDialog<void>(
            context: context,
            builder: (context) {
              return CupertinoAlertDialog(
                title: Text(t.e2eeRecoverSuccess),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.e2eeKeyRestored),
                    const SizedBox(height: 8),
                    Text(
                      t.e2eeUsedShards(count: _collectedCount),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.e2eeSocialZeroTrustHint3,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    child: Text(t.buttonOk),
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
                title: Text(t.e2eeRecoverFailed),
                content: Text(_statusMessage),
                actions: [
                  CupertinoDialogAction(
                    child: Text(t.buttonRetry),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoDialogAction(
                    child: Text(t.buttonCancel),
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
          _statusMessage = t.e2eeRecoveryFailed;
        });

        showCupertinoDialog<void>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text(t.e2eeRecoverFailed),
              content: Text(t.e2eeRecoverKeyFailed),
              actions: [
                CupertinoDialogAction(
                  child: Text(t.buttonRetry),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  child: Text(t.buttonCancel),
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
