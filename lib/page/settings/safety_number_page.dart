/// 安全码（Safety Number）验证页（审计 P1-2 接线）
///
/// Signal 风格带外身份验证：双方各自在手机/电脑上看到同一串 60 位安全码，
/// 通过面对面/电话/视频比对。一致 → 无中间人；不一致 → 停止对话并核实。
///
/// 实现：
/// - 本端 identity：OlmSessionService.localCurve25519Identity（权威副本）；
/// - 对端 identity：OlmSessionService.peerCurve25519Identity（已验证路径，
///   Ed25519 自签核验 + TOFU pin）；
/// - "已验证"状态仅本地持久化（SecureStorage per-peer）。
///
/// TODO（阶段 B）：比对一致后上报 `POST /api/v1/e2ee/trust/record`
/// （method=manual_number，to_state=verified）。需要 actor_device_generation /
/// target_identity_version 字段的客户端数据通路 + wire 往返验证，见台账 IMB-2026-006。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/safety_number_service.dart';
import 'package:imboy/service/trust_record_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 安全码验证页
class SafetyNumberPage extends StatefulWidget {
  const SafetyNumberPage({super.key, required this.peerUid});

  /// 对端用户 id（TSID 字符串）
  final String peerUid;

  @override
  // ignore: library_private_types_in_public_api
  _SafetyNumberPageState createState() => _SafetyNumberPageState();
}

class _SafetyNumberPageState extends State<SafetyNumberPage> {
  static const String _verifiedPrefix = 'safety_number_verified_';

  bool _isLoading = true;
  SafetyNumberResult? _result;
  bool _verified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await SafetyNumberService.generateForPeer(
        peerUid: widget.peerUid,
      );
      final verifiedAt = await StorageSecureService.to.read(
        key: _verifiedPrefix + widget.peerUid,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _verified = verifiedAt != null && verifiedAt.isNotEmpty;
      });
    } on ArgumentError catch (e) {
      iPrint('[SafetyNumber] 无法生成: $e');
      if (!mounted) return;
      setState(() {
        _error = t.main.safetyNumberNoDevices;
      });
    } catch (e) {
      iPrint('[SafetyNumber] 生成失败: $e');
      if (!mounted) return;
      setState(() {
        _error = t.main.safetyNumberVerifyFailed;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markVerified() async {
    final result = _result;
    if (result == null) return;
    // 阶段 B：比对一致后，把「已验证」作为签名信任事件上报服务端
    // （POST /api/v1/e2ee/trust/record，ADR 16）。上报成功才标记本地，
    // 失败则不标记——本地标记必须与服务端审计一致，避免"自认为已验证"
    // 但服务端/对端无记录。
    AppLoading.show(status: t.main.safetyNumberReporting);
    final outcome = await TrustRecordService.recordVerified(
      peerUid: widget.peerUid,
      peerDeviceId: result.peerDeviceId,
    );
    AppLoading.dismiss();
    if (!mounted) return;
    switch (outcome) {
      case TrustRecordOutcome.recorded:
        await StorageSecureService.to.write(
          key: _verifiedPrefix + widget.peerUid,
          value: DateTime.now().toIso8601String(),
        );
        setState(() => _verified = true);
        AppLoading.showToast(t.main.safetyNumberMarkedVerified);
      case TrustRecordOutcome.rejected:
        AppLoading.showToast(t.main.safetyNumberReportRejected);
      case TrustRecordOutcome.unavailable:
        AppLoading.showToast(t.main.safetyNumberReportUnavailable);
    }
  }

  Future<void> _copy() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.number));
    AppLoading.showToast(t.main.safetyNumberCopied);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final groups = result == null
        ? const <String>[]
        : SafetyNumberFormat.formatGroups(result.number);
    return IosPageTemplate(
      title: t.main.safetyNumberTitle,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _load,
          child: Icon(
            CupertinoIcons.refresh,
            size: 22,
            semanticLabel: t.common.buttonRefresh,
          ),
        ),
      ],
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: AppColors.iosRed,
                        fontSize: FontSizeType.normal.size,
                      ),
                    ),
                  ),
                if (result != null) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.shield,
                        size: 48,
                        color: AppColors.iosGreen,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final row in _rows(groups))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              row,
                              style: TextStyle(
                                fontSize: FontSizeType.largeTitle.size,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        AppSpacing.verticalRegular,
                        _verified
                            ? Text(
                                '✓ 已验证',
                                style: TextStyle(
                                  color: AppColors.iosGreen,
                                  fontSize: FontSizeType.medium.size,
                                ),
                              )
                            : Text(
                                '未验证',
                                style: TextStyle(
                                  color: AppColors.alipaySimTextGrey,
                                  fontSize: FontSizeType.medium.size,
                                ),
                              ),
                        AppSpacing.verticalSmall,
                        Text(
                          '${t.main.safetyNumberPeerDevice}: ${result.peerDeviceId}',
                          style: TextStyle(
                            color: AppColors.alipaySimTextGrey,
                            fontSize: FontSizeType.small.size,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton(
                        onPressed: _copy,
                        child: Text(t.main.safetyNumberCopy),
                      ),
                      if (!_verified)
                        CupertinoButton(
                          onPressed: _markVerified,
                          child: Text(t.main.safetyNumberMarkVerified),
                        ),
                    ],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t.main.safetyNumberHint,
                    style: TextStyle(
                      color: AppColors.alipaySimTextGrey,
                      fontSize: FontSizeType.small.size,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 12 组 → 每行 3 组（4 行 × 3 组，Signal 桌面端同款布局）。
  List<String> _rows(List<String> groups) {
    final rows = <String>[];
    for (var i = 0; i < groups.length; i += 3) {
      rows.add(groups.sublist(i, (i + 3).clamp(0, groups.length)).join('  '));
    }
    return rows;
  }
}

/// 分组格式化（60 位 → 12 组 × 5 位）。
class SafetyNumberFormat {
  SafetyNumberFormat._();

  static List<String> formatGroups(String number) {
    if (number.length != 60) {
      throw ArgumentError.value(number, 'number', 'must be 60 digits');
    }
    return List.generate(12, (i) => number.substring(i * 5, i * 5 + 5));
  }
}
