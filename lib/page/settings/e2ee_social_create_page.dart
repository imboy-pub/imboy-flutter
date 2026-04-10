import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/page/settings/e2ee_proxy_selector_page.dart';

/// E2EE 社交恢复 - 创建分片页面
/// 选择代理并创建恢复分片
class E2EESocialCreatePage extends StatefulWidget {
  const E2EESocialCreatePage({super.key});

  @override
  State<E2EESocialCreatePage> createState() => _E2EESocialCreatePageState();
}

class _E2EESocialCreatePageState extends State<E2EESocialCreatePage> {
  int _totalShards = 3;
  int _threshold = 2;
  bool _isLoading = false;
  List<Map<String, dynamic>> _selectedProxies = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建恢复分片')),
      body: ListView(
        children: [
          _buildSettingsCard(),
          const SizedBox(height: 16),
          _buildProxySelectionCard(),
          const SizedBox(height: 24),
          _buildCreateButton(),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分片设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              '总分片数',
              _totalShards,
              3,
              5,
              (value) => setState(() => _totalShards = value),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              '恢复阈值',
              _threshold,
              2,
              _totalShards - 1,
              (value) => setState(() => _threshold = value),
            ),
            const SizedBox(height: 16),
            Text(
              '说明：分片将存储在代理设备上，服务端不保存任何分片',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '恢复密钥时需要 $_threshold 个代理协助',
              style: TextStyle(fontSize: 13, color: CupertinoColors.activeBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    int? maxValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.activeBlue,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: (maxValue ?? max).toDouble(),
          divisions: ((maxValue ?? max) - min).clamp(1, 100),
          activeColor: CupertinoColors.activeBlue,
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }

  Widget _buildProxySelectionCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '选择恢复代理',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: _showProxyPicker,
                  child: const Text('添加代理'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '需要 $_totalShards 个信任的联系人作为代理',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_selectedProxies.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('请添加代理联系人'),
                ),
              )
            else
              ...(_selectedProxies.asMap().entries.map((entry) {
                final index = entry.key;
                final proxy = entry.value;
                return _buildProxyItem(index, proxy);
              })),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyItem(int index, Map<String, dynamic> proxy) {
    final nickname = proxy['nickname'] ?? '用户 ${proxy['uid']}';
    final uid = proxy['uid'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple,
          child: Text(
            nickname.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(nickname),
        subtitle: Text('UID: $uid'),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle),
          color: Colors.red,
          onPressed: () {
            setState(() {
              _selectedProxies.removeAt(index);
            });
          },
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: _selectedProxies.length < _totalShards
              ? null
              : _isLoading
              ? null
              : _createShards,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(
                  _selectedProxies.length < _totalShards
                      ? '请先添加 $_totalShards 个代理'
                      : '创建分片',
                ),
        ),
      ),
    );
  }

  Future<void> _showProxyPicker() async {
    // 获取已选中的代理 UID 列表
    final selectedUids = _selectedProxies
        .map((p) => p['uid'] as String)
        .toList();

    // 打开好友选择器页面
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => E2EEProxySelectorPage(
          selectedUids: selectedUids,
          requiredCount: _totalShards,
        ),
      ),
    );

    // 如果用户选择了代理，更新列表
    if (result != null && result is List) {
      setState(() {
        _selectedProxies = List<Map<String, dynamic>>.from(result);
      });
    }
  }

  Future<void> _createShards() async {
    setState(() => _isLoading = true);

    try {
      // 准备代理列表（包含加密的公钥）
      final proxies = _selectedProxies.map((proxy) {
        return {
          'proxy_uid': proxy['uid'],
          'encrypted_public_key': proxy['public_key'] ?? '',
        };
      }).toList();

      final result = await E2EESocialService.createShards(
        totalShards: _totalShards,
        threshold: _threshold,
        proxies: proxies,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        final shards = result['shards'] as List;

        // 零信任架构：通过 WebSocket 将分片发送给代理
        if (kDebugMode) {
          debugPrint('[E2EE] 开始发送分片到 ${shards.length} 个代理...');
        }
        final sentCount = await E2EESocialService.sendShardsToProxies(
          shards.cast<Map<String, dynamic>>(),
        );

        if (kDebugMode) {
          debugPrint('[E2EE] 已成功发送 $sentCount/${shards.length} 个分片');
        }

        showCupertinoDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: const Text('分片创建成功'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '密钥已分割成 ${result['total_shards']} 个分片',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '分片已通过 WebSocket 直接发送到代理设备存储',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '需要 ${result['threshold']} 个代理协助即可恢复密钥',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已发送到 $sentCount 个代理设备（共 ${shards.length} 个）',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '零信任架构：服务端不保存任何分片',
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
      }
    } on Exception {
      if (mounted) {
        setState(() => _isLoading = false);
        showCupertinoDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: const Text('创建失败'),
              content: const Text('创建分片失败，请重试'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('确定'),
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
