import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/service/e2ee_social_service.dart';

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
  String _statusMessage = '准备恢复...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadShards();
      }
    });
  }

  Future<void> _loadShards() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '加载分片信息...';
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
          _statusMessage = localShards.isEmpty ? '没有可用的分片' : '准备就绪';
        });
      } else {
        setState(() {
          _shards = shards;
          _isLoading = false;
          _statusMessage = '准备就绪';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _shards = [];
        _statusMessage = '加载失败: $e';
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
            ? '没有可用的分片'
            : '准备就绪（${shards.length} 个分片）';
      });

      return shards;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _shards = [];
        _statusMessage = '加载失败: $e';
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
      appBar: AppBar(title: const Text('恢复密钥')),
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
        borderRadius: BorderRadius.circular(12),
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
                        canRecover ? '可以恢复密钥' : '分片数量不足',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: canRecover ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '可用分片: $totalShards 个，需要 $threshold 个代理协助',
                        style: TextStyle(
                          fontSize: 13,
                          color: canRecover
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '零信任架构：服务端不存储分片，直接联系代理',
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
                            '正在联系: $_currentProxyName',
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
                '进度: $_collectedCount / $threshold 个分片',
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
    final proxyUid = shard['proxy_uid']?.toString() ?? '未知';
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${shardIndex + 1}',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text('代理用户: $proxyUid'),
        subtitle: Text('分片 $shardIndex / $totalShards'),
        trailing: Icon(statusIcon, color: statusColor, size: 20),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '没有可用的恢复分片',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '零信任架构：分片存储在代理设备',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () => _loadShards(),
              child: const Text('重新加载'),
            ),
          ],
        ),
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
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(radius: 10),
                    SizedBox(width: 8),
                    Text('恢复中...'),
                  ],
                )
              : Text(
                  canRecover
                      ? '开始恢复密钥（需要 $threshold 个代理协助）'
                      : '分片不足（需要 $threshold 个，当前 ${_shards.length} 个）',
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
                _currentProxyName = '代理 ${shard['proxy_uid']}';
                _statusMessage = '正在收集分片 ($collected/$threshold)...';
              } else {
                _statusMessage = '分片收集完成，正在重组密钥...';
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isRecovering = false);

        if (success) {
          showCupertinoDialog(
            context: context,
            builder: (context) {
              return CupertinoAlertDialog(
                title: const Text('恢复成功'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('密钥已成功恢复'),
                    const SizedBox(height: 8),
                    Text(
                      '已使用 $_collectedCount 个代理分片',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '零信任架构：分片由代理设备存储，服务端不接触明文',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('确定'),
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
          showCupertinoDialog(
            context: context,
            builder: (context) {
              return CupertinoAlertDialog(
                title: const Text('恢复失败'),
                content: Text(_statusMessage),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('重试'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoDialogAction(
                    child: const Text('取消'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecovering = false;
          _statusMessage = '恢复失败: $e';
        });

        showCupertinoDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: const Text('恢复失败'),
              content: Text('错误: $e'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('重试'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  child: const Text('取消'),
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
