import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
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
      appBar: AppBar(title: Text(t.e2eeSocialCreateTitle)),
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
            Text(
              t.e2eeSocialShardSettings,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              t.e2eeSocialTotalShards,
              _totalShards,
              3,
              5,
              (value) => setState(() => _totalShards = value),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              t.e2eeSocialThreshold,
              _threshold,
              2,
              _totalShards - 1,
              (value) => setState(() => _threshold = value),
            ),
            const SizedBox(height: 16),
            Text(
              t.e2eeSocialShardStoredNote,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              t.e2eeSocialThresholdHint(count: _threshold),
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.activeBlue,
              ),
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
                Text(
                  t.e2eeSocialSelectProxy,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _showProxyPicker,
                  child: Text(t.e2eeSocialAddProxy),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.e2eeSocialProxyNeeded(count: _totalShards),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_selectedProxies.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(t.e2eeSocialAddProxyHint),
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
    final nickname =
        proxy['nickname'] ?? t.e2eeSocialProxyDefaultName(uid: proxy['uid']);
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
                      ? t.e2eeSocialCreateNeedMore(count: _totalShards)
                      : t.e2eeSocialCreateBtn,
                ),
        ),
      ),
    );
  }

  Future<void> _showProxyPicker() async {
    final selectedUids = _selectedProxies
        .map((p) => p['uid'] as String)
        .toList();

    final result = await Navigator.push(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (_) => E2EEProxySelectorPage(
          selectedUids: selectedUids,
          requiredCount: _totalShards,
        ),
      ),
    );

    if (result != null && result is List) {
      setState(() {
        _selectedProxies = List<Map<String, dynamic>>.from(result);
      });
    }
  }

  Future<void> _createShards() async {
    setState(() => _isLoading = true);

    try {
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

        if (kDebugMode) {
          debugPrint('[E2EE] sending shards to ${shards.length} proxies...');
        }
        final sentCount = await E2EESocialService.sendShardsToProxies(
          shards.cast<Map<String, dynamic>>(),
        );

        if (kDebugMode) {
          debugPrint('[E2EE] sent $sentCount/${shards.length} shards');
        }

        showCupertinoDialog<void>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text(t.e2eeSocialCreateSuccessTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.e2eeSocialTotalShardsInfo(
                      count: result['total_shards'] as int,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.e2eeSocialShardSentViaWs,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.e2eeSocialThresholdInfo(
                      count: result['threshold'] as int,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.e2eeSocialSentCount(
                      sent: sentCount,
                      total: shards.length,
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.e2eeSocialZeroTrustNote,
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
      }
    } on Exception {
      if (mounted) {
        setState(() => _isLoading = false);
        showCupertinoDialog<void>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text(t.e2eeSocialCreateFailTitle),
              content: Text(t.e2eeSocialCreateFailBody),
              actions: [
                CupertinoDialogAction(
                  child: Text(t.buttonOk),
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
