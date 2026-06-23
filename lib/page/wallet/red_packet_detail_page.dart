import 'package:flutter/material.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/store/model/red_packet_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

class RedPacketDetailPage extends ConsumerStatefulWidget {
  final String packetId;

  const RedPacketDetailPage({super.key, required this.packetId});

  @override
  ConsumerState<RedPacketDetailPage> createState() =>
      _RedPacketDetailPageState();
}

class _RedPacketDetailPageState extends ConsumerState<RedPacketDetailPage> {
  bool _isLoading = true;
  RedPacketModel? _packet;
  List<RedPacketReceiveModel> _receivers = [];
  int? _myGrabbedAmount;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final detail = await WalletApi().getRedPacketDetail(widget.packetId);
      if (detail != null) {
        final packetMap = Map<String, dynamic>.from(detail['packet'] as Map);
        final receiversList = List<dynamic>.from(detail['receivers'] as List);

        final packet = RedPacketModel.fromJson(packetMap);
        final receivers = receiversList
            .map(
              (r) => RedPacketReceiveModel.fromJson(
                Map<String, dynamic>.from(r as Map),
              ),
            )
            .toList();

        final currentUid = int.tryParse(UserRepoLocal.to.currentUid) ?? 0;
        int? myGrabbed;
        for (final r in receivers) {
          if (r.receiverUid == currentUid) {
            myGrabbed = r.amount;
            break;
          }
        }

        setState(() {
          _packet = packet;
          _receivers = receivers;
          _myGrabbedAmount = myGrabbed;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        EasyLoading.showError('获取红包详情失败');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      EasyLoading.showError('获取红包详情异常');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.iosRed, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_packet == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(t.common.redPacketDetail),
          backgroundColor: AppColors.iosRed,
        ),
        body: const Center(child: Text('红包不存在或已被删除')),
      );
    }

    // 寻找手气最佳 (仅拼手气类型 且 至少有 1 个领取记录时)
    int? bestLuckUid;
    if (_packet!.isRandom && _receivers.isNotEmpty) {
      int maxAmount = -1;
      for (final r in _receivers) {
        if (r.amount > maxAmount) {
          maxAmount = r.amount;
          bestLuckUid = r.receiverUid;
        }
      }
    }

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightSurfaceGrouped,
      body: CustomScrollView(
        slivers: [
          // 头部渐变区域
          SliverAppBar(
            pinned: true,
            expandedHeight: 280.0,
            backgroundColor: AppColors.iosRed,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.iosRed, Color(0xFFE55D5D)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 80.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 发件人信息 (Mock 名字，实际可以从 ContactRepo 查询)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade700,
                              borderRadius: AppRadius.borderRadiusTiny,
                            ),
                            child: Text(
                              '🈲 零信任端解密',
                              style: TextStyle(
                                fontSize: FontSizeType.tiny.size,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _packet!.greeting,
                        style: TextStyle(
                          color: AppColors.onPrimary.withValues(alpha: 0.7),
                          fontSize: FontSizeType.subheadline.size,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_myGrabbedAmount != null) ...[
                        Text(
                          (_myGrabbedAmount! / 100.0).toStringAsFixed(2),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: FontSizeType.extraLargeTitle.size,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '元',
                          style: TextStyle(
                            color: AppColors.onPrimary.withValues(alpha: 0.7),
                            fontSize: FontSizeType.normal.size,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '未领到该红包',
                          style: TextStyle(
                            color: AppColors.onPrimary.withValues(alpha: 0.7),
                            fontSize: FontSizeType.large.size,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 领取明细统计条
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? colorScheme.surface : Colors.white,
              child: Text(
                _packet!.isFinished
                    ? '共 ${_packet!.amountYuan.toStringAsFixed(2)} 元，${_packet!.count} 个红包已抢光'
                    : '已抢 ${_receivers.length}/${_packet!.count} 个，共 ${((_packet!.amount - _packet!.remainAmount) / 100.0).toStringAsFixed(2)}/${_packet!.amountYuan.toStringAsFixed(2)} 元',
                style: TextStyle(
                  fontSize: FontSizeType.normal.size,
                  color: AppColors.iosGray,
                ),
              ),
            ),
          ),

          // 领取记录列表
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final r = _receivers[index];
              final isBestLuck = r.receiverUid == bestLuckUid;

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.surface : Colors.white,
                  border: const Border(
                    bottom: BorderSide(color: Colors.black12, width: 0.5),
                  ),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Row(
                    children: [
                      Text('用户: ${r.receiverUid}'),
                      if (isBestLuck) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: AppRadius.borderRadiusTiny,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.orange.shade800,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '手气最佳',
                                style: TextStyle(
                                  fontSize: FontSizeType.tiny.size,
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${r.receivedAt.hour.toString().padLeft(2, '0')}:${r.receivedAt.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: Text(
                    '￥${r.amountYuan.toStringAsFixed(2)} 元',
                    style: TextStyle(
                      fontSize: FontSizeType.medium.size,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }, childCount: _receivers.length),
          ),
        ],
      ),
    );
  }
}
