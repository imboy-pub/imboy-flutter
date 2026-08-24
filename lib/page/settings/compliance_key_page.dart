/// 合规审计密钥信息页
///
/// compliance_e2ee 模式下，合规公钥由服务端下发并用于消息双包裹。本页展示
/// 服务端下发的公钥材料与本地 TOFU 固定（pin）状态，供用户/管理员核验
/// "服务端是否换过合规密钥"（审计 P1-1）。
library;

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/compliance_key_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 合规审计密钥信息页
class ComplianceKeyPage extends StatefulWidget {
  const ComplianceKeyPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ComplianceKeyPageState createState() => _ComplianceKeyPageState();
}

class _ComplianceKeyPageState extends State<ComplianceKeyPage> {
  bool _isLoading = true;
  ComplianceKeyInfo? _key;
  Map<String, dynamic>? _pin;
  bool _pinMismatch = false;
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
      final key = await ComplianceKeyService.instance.getComplianceKey(
        forceRefresh: true,
      );
      final pin = await ComplianceKeyService.instance.pinned();
      if (!mounted) return;
      setState(() {
        _key = key;
        _pin = pin;
        _pinMismatch = false;
      });
    } on ComplianceKeyChangedException {
      if (!mounted) return;
      setState(() {
        _pinMismatch = true;
        _error = t.main.complianceKeyInfoChangedWarning;
      });
      // 展示"将要固定"的新值
      final pending = ComplianceKeyService.instance.pendingObserved;
      if (pending != null) _key = pending;
    } catch (e) {
      iPrint('[ComplianceKeyPage] 加载失败: $e');
      if (!mounted) return;
      setState(() {
        _error = t.main.complianceKeyInfoRefreshFailed;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtFingerprint(String fp) {
    final buf = StringBuffer();
    for (var i = 0; i < fp.length; i++) {
      if (i > 0 && i % 8 == 0) buf.write(' ');
      buf.write(fp[i]);
    }
    return buf.toString();
  }

  String _fmtTime(DateTime? dt) =>
      dt == null ? '-' : dt.toLocal().toIso8601String();

  @override
  Widget build(BuildContext context) {
    final key = _key;
    final pin = _pin;
    return IosPageTemplate(
      title: t.main.complianceKeyInfoTitle,
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
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: _pinMismatch
                            ? AppColors.iosOrange
                            : AppColors.iosRed,
                        fontSize: FontSizeType.normal.size,
                      ),
                    ),
                  ),
                if (key == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('当前部署未配置合规审计密钥')),
                  ),
                if (key != null) ...[
                  ImBoySettingsSection(
                    header: Text(t.main.complianceKeyInfoServerKey),
                    children: [
                      _infoTile(t.main.complianceKeyInfoKeyId, key.keyId),
                      _infoTile(
                        t.main.complianceKeyInfoAlgorithm,
                        key.algorithm ?? 'RSA-OAEP-256',
                      ),
                      _infoTile(
                        t.main.complianceKeyInfoFetchedAt,
                        _fmtTime(key.fetchedAt),
                      ),
                      _infoTile(
                        t.main.complianceKeyInfoFingerprint,
                        _fmtFingerprint(key.fingerprint),
                      ),
                    ],
                  ),
                  ImBoySettingsSection(
                    header: Text(t.main.complianceKeyInfoLocalPin),
                    children: [
                      _infoTile(
                        t.main.complianceKeyInfoKeyId,
                        pin?['key_id'] as String? ?? '-',
                      ),
                      _infoTile(
                        t.main.complianceKeyInfoPinnedAt,
                        pin?['pinned_at'] as String? ?? '-',
                      ),
                      _infoTile(
                        t.main.complianceKeyInfoFingerprint,
                        pin == null
                            ? t.main.complianceKeyInfoPinnedNone
                            : _fmtFingerprint(
                                pin['fingerprint'] as String? ?? '-',
                              ),
                      ),
                    ],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t.main.complianceKeyInfoHint,
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

  Widget _infoTile(String title, String value) {
    return ImBoySettingsTile(
      title: Text(title),
      subtitle: Text(
        value,
        style: TextStyle(
          color: AppColors.alipaySimTextGrey,
          fontSize: FontSizeType.small.size,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
