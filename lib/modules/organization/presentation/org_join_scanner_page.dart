/// 企业加入专用扫码页（GZAPP-J11 扫码侧）：
/// 识别 `imboy://org/join?c=<CODE>` 邀请二维码（或裸 8 位明码），
/// pop(code) 返回给加入对话框做「确认加入 XX 企业」。
///
/// 不复用通用 [ScannerPage]：那页扫码结果默认推进 ScannerResultPage
/// （扫码登录语义），与企业加入的确认流不同构；但 BUG#141 的启动模式
/// （autoStart:false + 先自行请求相机权限再 start + start 后复查
/// value.error）必须原样继承——mobile_scanner 7.x 会把权限异常吞进
/// controller.value.error，不主动检查就只剩库默认英文文案。
library;

import 'dart:async';

import 'package:imboy/app_core/routing/organization_invite_link.dart';

import 'package:flutter/cupertino.dart' show CupertinoButton, CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart'
    show
        Permission,
        PermissionActions,
        PermissionStatusGetters,
        openAppSettings;

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

class OrgJoinScannerPage extends StatefulWidget {
  const OrgJoinScannerPage({super.key});

  @override
  State<OrgJoinScannerPage> createState() => _OrgJoinScannerPageState();
}

class _OrgJoinScannerPageState extends State<OrgJoinScannerPage> {
  late final MobileScannerController _controller;
  bool _started = false;
  bool _startFailed = false;
  bool _permissionDenied = false;

  /// 已识别有效码后的防抖闸：相机帧流在 pop 前还会进 onDetect。
  bool _done = false;
  Timer? _invalidTipTimer;
  String? _invalidTip;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      autoStart: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  Future<void> _start() async {
    if (_started || !mounted) return;
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _startFailed = true;
          _permissionDenied = true;
        });
      }
      return;
    }
    try {
      await _controller.start();
      final startError = _controller.value.error;
      if (startError != null) {
        if (mounted) {
          setState(() {
            _startFailed = true;
            _permissionDenied =
                startError.errorCode == MobileScannerErrorCode.permissionDenied;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _started = true;
        });
      }
    } on MobileScannerException catch (e) {
      if (kDebugMode) {
        debugPrint('org join scanner start failed: ${e.errorCode}');
      }
      if (mounted) {
        setState(() {
          _startFailed = true;
          _permissionDenied =
              e.errorCode == MobileScannerErrorCode.permissionDenied;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _startFailed = true;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = parseOrgJoinCode(barcode.rawValue);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    _showInvalidTip();
  }

  /// 非企业邀请码：轻提示后继续扫（不打断，用户可能对准了别的码）。
  void _showInvalidTip() {
    if (_invalidTip != null) return;
    if (!mounted) return;
    setState(() {
      _invalidTip = context.t.organization.picker.joinQrInvalid;
    });
    _invalidTipTimer?.cancel();
    _invalidTipTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _invalidTip = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _invalidTipTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.organization.picker.joinScanQr)),
      backgroundColor: AppColors.darkBackground, // 相机取景区黑底（与通用扫码页同 Token）
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _buildStartErrorView(context),
          ),
          if (_startFailed) _buildStartErrorView(context),
          if (_invalidTip != null)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _invalidTip!,
                    key: const ValueKey('org-join-scan-invalid'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  t.organization.picker.joinQrHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartErrorView(BuildContext context) {
    final t = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 44,
              color: AppColors.onPrimary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              _permissionDenied
                  ? t.common.noPermission
                  : t.common.permissionAcquisitionFailed,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onPrimary),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(8),
              onPressed: _permissionDenied ? () => openAppSettings() : _start,
              // 实底按钮文字必须显式 onPrimary（同 apply_friend_page）
              child: Text(
                _permissionDenied ? t.main.setting : t.common.buttonRetry,
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 解析企业邀请 deep link（支持本站 HTTPS 邀请链接及 `imboy://org/join?c=CODE`，
/// 容忍 `code=` 键名或带额外参数的 payload 变体；裸明码不算 deep link）。
/// 通用扫一扫（ScannerPage）用它分发加入企业流程——通用场景里任意
/// 8 位文本可能是订单号/序列号，不能当邀请码。
String? parseOrgJoinDeepLink(String? raw) => organizationInviteCode(raw);

/// Accept a supported invitation URL or a manually entered code.
String? parseOrgJoinCode(String? raw) =>
    organizationInviteCode(raw) ?? normalizeOrganizationInviteCode(raw ?? '');
