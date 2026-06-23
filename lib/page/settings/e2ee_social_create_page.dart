import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/page/settings/e2ee_proxy_selector_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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
      appBar: AppBar(title: Text(t.chat.e2eeSocialCreateTitle)),
      body: ListView(
        children: [
          _buildSettingsCard(),
          const SizedBox(height: AppSpacing.regular),
          _buildProxySelectionCard(),
          const SizedBox(height: AppSpacing.xLarge),
          _buildCreateButton(),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.common.e2eeSocialShardSettings,
              style: TextStyle(
                fontSize: FontSizeType.medium.size,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.regular),
            _buildSlider(
              t.main.e2eeSocialTotalShards,
              _totalShards,
              3,
              5,
              (value) => setState(() => _totalShards = value),
            ),
            const SizedBox(height: AppSpacing.regular),
            _buildSlider(
              t.main.e2eeSocialThreshold,
              _threshold,
              2,
              _totalShards - 1,
              (value) => setState(() => _threshold = value),
            ),
            const SizedBox(height: AppSpacing.regular),
            Text(
              t.common.e2eeSocialShardStoredNote,
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: AppColors.iosGray,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              t.main.e2eeSocialThresholdHint(count: _threshold),
              style: TextStyle(
                fontSize: FontSizeType.footnote.size,
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
            Text(label, style: TextStyle(fontSize: FontSizeType.normal.size)),
            Text(
              '$value',
              style: TextStyle(
                fontSize: FontSizeType.normal.size,
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
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.main.e2eeSocialSelectProxy,
                  style: TextStyle(
                    fontSize: FontSizeType.medium.size,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _showProxyPicker,
                  child: Text(t.common.e2eeSocialAddProxy),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              t.main.e2eeSocialProxyNeeded(count: _totalShards),
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: AppColors.iosGray,
              ),
            ),
            const SizedBox(height: AppSpacing.regular),
            if (_selectedProxies.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xxLarge,
                  ),
                  child: Text(t.common.e2eeSocialAddProxyHint),
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
        proxy['nickname'] as Object? ??
        t.main.e2eeSocialProxyDefaultName(uid: proxy['uid'] as Object);
    final uid = proxy['uid'];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.iosPurple,
          child: Text(
            (nickname as String).substring(0, 1).toUpperCase(),
            style: const TextStyle(color: AppColors.onPrimary),
          ),
        ),
        title: Text(nickname),
        subtitle: Text('UID: $uid'),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle),
          color: AppColors.iosRed,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
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
                      ? t.common.e2eeSocialCreateNeedMore(count: _totalShards)
                      : t.chat.e2eeSocialCreateBtn,
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

        if (kDebugMode) {}
        final sentCount = await E2EESocialService.sendShardsToProxies(
          shards.cast<Map<String, dynamic>>(),
        );

        if (kDebugMode) {}

        if (!mounted) return;
        showCupertinoDialog<void>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text(t.common.e2eeSocialCreateSuccessTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.common.e2eeSocialTotalShardsInfo(
                      count: result['total_shards'] as int,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    t.main.e2eeSocialShardSentViaWs,
                    style: TextStyle(
                      fontSize: FontSizeType.small.size,
                      color: AppColors.iosGray,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    t.common.e2eeSocialThresholdInfo(
                      count: result['threshold'] as int,
                    ),
                    style: TextStyle(
                      fontSize: FontSizeType.footnote.size,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    t.main.e2eeSocialSentCount(
                      sent: sentCount,
                      total: shards.length,
                    ),
                    style: TextStyle(
                      fontSize: FontSizeType.small.size,
                      color: AppColors.iosGray,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    t.common.e2eeSocialZeroTrustNote,
                    style: TextStyle(
                      fontSize: FontSizeType.tiny.size,
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
      }
    } on Exception {
      if (mounted) {
        setState(() => _isLoading = false);
        showCupertinoDialog<void>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text(t.chat.e2eeSocialCreateFailTitle),
              content: Text(t.chat.e2eeSocialCreateFailBody),
              actions: [
                CupertinoDialogAction(
                  child: Text(t.common.buttonOk),
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
