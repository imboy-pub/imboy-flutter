import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/service/e2ee/crypto_audit_log.dart';
import 'package:imboy/service/e2ee_server_backup_service.dart';
import 'package:imboy/service/e2ee_backup_url_download_service.dart';
import 'package:imboy/service/e2ee_health_check_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/message_events.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// E2EE 备份导入页面
///
/// 功能：
/// - 选择备份文件
/// - 验证文件格式
/// - 输入密码解密
/// - 恢复私钥到安全存储
class E2EEBackupImportPage extends StatefulWidget {
  final String? initialFilePath;
  final Future<E2EEBackupInfo> Function()? cloudBackupProbe;

  /// 文件校验实现；默认使用真实本地文件校验。
  final Future<Map<String, dynamic>> Function(String path)? backupFileVerifier;

  /// 文件解密实现；默认使用真实本地备份服务。
  final Future<Map<String, dynamic>> Function(
    String path,
    String password,
    String? expectedAccountId,
  )?
  backupFileImporter;

  /// 云端解密实现；默认使用真实云端备份服务。
  final Future<Map<String, dynamic>> Function(
    String password,
    String? accountId,
  )?
  cloudBackupRestorer;

  /// 恢复成功后回写服务端设备公钥的实现（测试注入用；null 走真实 [E2EEApi]）。
  final Future<bool> Function(Map<String, dynamic> restored)? deviceKeyReporter;
  final Future<bool> Function(int sessionCount)? historicalKeyGrantConfirmer;
  final Future<void> Function(MegolmBackupSection section)?
  historicalKeyGrantAuditor;

  const E2EEBackupImportPage({
    super.key,
    this.initialFilePath,
    this.cloudBackupProbe,
    this.backupFileVerifier,
    this.backupFileImporter,
    this.cloudBackupRestorer,
    this.deviceKeyReporter,
    this.historicalKeyGrantConfirmer,
    this.historicalKeyGrantAuditor,
  });

  @override
  // ignore: library_private_types_in_public_api
  _E2EEBackupImportPageState createState() => _E2EEBackupImportPageState();
}

class _E2EEBackupImportPageState extends State<E2EEBackupImportPage> {
  final _passwordController = TextEditingController();
  final _cloudPasswordController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isImporting = false;
  bool _isCloudRestoring = false;
  bool _isDownloading = false;
  File? _selectedFile;
  Map<String, dynamic>? _backupInfo;
  int _fileVerificationGeneration = 0;
  int _fileSelectionGeneration = 0;
  E2EEBackupInfo? _cloudInfo;

  /// 云端备份探测失败标记（如网络抖动）：true 时在云端恢复入口位置渲染重试按钮，
  /// 防止用户误以为无云端备份而走"生成新密钥"危险路径。
  bool _cloudProbeFailed = false;

  /// 当前选中文件的来源：'picker' / 'url' / null。
  /// 'url' 来源的文件是本页下载到临时目录的，dispose 时需删除；
  /// 'picker' 来源由系统管理，不归本页清理。
  String? _selectedFileSource;

  @override
  void initState() {
    super.initState();
    unawaited(_probeCloudBackup());
    if (widget.initialFilePath != null) {
      _selectedFile = File(widget.initialFilePath!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _verifyFile();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _cloudPasswordController.dispose();
    _urlController.dispose();
    // 清理本页通过 URL 下载产生的临时文件；文件选择器产生的文件不归本页管。
    if (_selectedFileSource == 'url' && _selectedFile != null) {
      unawaited(
        E2EEBackupUrlDownloadService.cleanupTempFile(_selectedFile!.path),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IosPageTemplate(
      title: t.common.e2eeBackupImportTitle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          children: [
            _buildWarningCard(),
            if (_cloudInfo?.hasBackup == true) ...[
              const SizedBox(height: AppSpacing.regular),
              _buildCloudRestoreCard(),
            ] else if (_cloudInfo == null && _cloudProbeFailed) ...[
              const SizedBox(height: AppSpacing.regular),
              _buildCloudProbeRetry(),
            ],
            const SizedBox(height: AppSpacing.xLarge),
            _buildFileSelector(),
            const SizedBox(height: AppSpacing.regular),
            _buildUrlInputCard(),
            if (_backupInfo != null) ...[
              const SizedBox(height: AppSpacing.regular),
              _buildBackupInfoCard(),
            ],
            const SizedBox(height: AppSpacing.xLarge),
            _buildPasswordSection(),
            const SizedBox(height: AppSpacing.xLarge),
            _buildImportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: AppColors.iosOrange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.info, color: AppColors.iosOrange),
                const SizedBox(width: AppSpacing.small),
                Text(
                  t.common.e2eeBackupImportGuide,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.iosOrange,
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupImportReplaceKey,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosOrange,
              ),
            ),
            AppSpacing.verticalTiny,
            Text(
              t.common.e2eeBackupImportTrustedSource,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudRestoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.cloud_download,
                  color: AppColors.iosBlue,
                ),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Text(
                    t.common.e2eeBackupCloudRestoreTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.iosBlue,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupCloudRestoreHint(
                version: _cloudInfo?.backupVersion ?? 0,
              ),
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.getTextSecondary(Theme.of(context).brightness),
              ),
            ),
            AppSpacing.verticalMedium,
            OutlinedButton.icon(
              onPressed: (_isCloudRestoring || _isImporting)
                  ? null
                  : _promptCloudRestore,
              icon: _isCloudRestoring
                  ? const SizedBox(
                      height: AppSpacing.large,
                      width: AppSpacing.large,
                      child: CupertinoActivityIndicator(),
                    )
                  : const Icon(CupertinoIcons.cloud_download),
              label: Text(t.common.e2eeBackupCloudRestoreBtn),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.common.e2eeBackupSelectFile,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            AppSpacing.verticalMedium,
            GestureDetector(
              onTap: _selectFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.regular),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.iosGray4),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.cloud_upload,
                      color: _selectedFile != null
                          ? AppColors.iosGreen
                          : AppColors.iosGray,
                      size: 48,
                    ),
                    AppSpacing.verticalSmall,
                    Text(
                      _selectedFile != null
                          ? (_selectedFile!.path.split('/').last)
                          : t.common.e2eeBackupSelectFileHint,
                      style: context.textStyle(
                        FontSizeType.small,
                        color: _selectedFile != null
                            ? AppColors.iosGreen
                            : AppColors.iosGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupInfoCard() {
    if (_backupInfo == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.info, color: AppColors.iosBlue),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Text(
                    t.common.e2eeBackupInfoTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.iosBlue,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: AppColors.iosGreen,
                  size: 20,
                ),
              ],
            ),
            AppSpacing.verticalMedium,
            _buildInfoRow(
              t.common.e2eeBackupVersionLabel,
              _backupInfo!['version'].toString(),
            ),
            _buildInfoRow(
              t.common.e2eeBackupAlgorithmLabel,
              _backupInfo!['algorithm'].toString(),
            ),
            _buildInfoRow(
              t.common.e2eeBackupFileSizeLabel,
              t.common.e2eeBackupFileBytes(
                bytes: _backupInfo!['file_size'].toString(),
              ),
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupFileValid,
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.iosGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: context.textStyle(FontSizeType.footnote)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return TextField(
      enableSuggestions: false,
      autocorrect: false,
      controller: _passwordController,
      obscureText: true,
      // isEnabled 依赖 controller.text；缺 onChanged 时输入不触发 setState，
      // 「导入密钥」按钮停留在禁用态（BUG#132 同源，见导出页同款修复）。
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: t.common.e2eeBackupPwdLabel,
        hintText: t.common.e2eeBackupImportPwdHint,
        prefixIcon: const Icon(CupertinoIcons.lock_fill),
        border: const OutlineInputBorder(),
        suffixIcon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CupertinoActivityIndicator(),
              )
            : null,
      ),
      enabled: _backupInfo != null,
    );
  }

  Widget _buildImportButton() {
    final isEnabled =
        _passwordController.text.isNotEmpty &&
        _backupInfo != null &&
        !_isImporting &&
        !_isCloudRestoring;

    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.zero,
        onPressed: isEnabled ? _handleImport : null,
        child: _isImporting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CupertinoActivityIndicator(),
              )
            : Text(t.common.e2eeBackupImportBtn),
      ),
    );
  }

  Future<void> _selectFile() async {
    if (!mounted) return;
    final generation = ++_fileSelectionGeneration;
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['enc'],
      );
      if (!_isCurrentFileSelection(generation)) return;

      if (result != null && result.path != null) {
        // 切换到文件选择器来源前，清理之前 URL 下载产生的临时文件
        if (_selectedFileSource == 'url' && _selectedFile != null) {
          await E2EEBackupUrlDownloadService.cleanupTempFile(
            _selectedFile!.path,
          );
          if (!_isCurrentFileSelection(generation)) return;
        }
        setState(() {
          _selectedFile = File(result.path!);
          _selectedFileSource = 'picker';
          _backupInfo = null;
        });
        await _verifyFile();
      }
    } on Exception catch (e) {
      if (!_isCurrentFileSelection(generation)) return;
      iPrint('[E2EEBackupImport] 选择备份文件失败: $e');
      _showError(t.common.e2eeBackupErrSelectFile);
    }
  }

  bool _isCurrentFileSelection(int generation) =>
      mounted && _fileSelectionGeneration == generation;

  /// 通过 URL 下载备份文件到临时目录，然后走与文件选择相同的校验链路。
  /// 下载前先清理之前选中文件产生的临时副本（URL 来源）。
  Future<void> _handleUrlDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _isDownloading) return;

    // 切换到 URL 来源前，清理之前 URL 下载产生的临时文件
    if (_selectedFileSource == 'url' && _selectedFile != null) {
      await E2EEBackupUrlDownloadService.cleanupTempFile(_selectedFile!.path);
    }

    setState(() {
      _isDownloading = true;
      _backupInfo = null;
      _selectedFile = null;
      _selectedFileSource = null;
    });

    try {
      final tempPath = await E2EEBackupUrlDownloadService.downloadToTemp(url);
      if (!mounted) {
        // 页面已不在树上，刚下载的临时文件立即清理
        await E2EEBackupUrlDownloadService.cleanupTempFile(tempPath);
        return;
      }
      setState(() {
        _selectedFile = File(tempPath);
        _selectedFileSource = 'url';
      });
      await _verifyFile();
    } on E2EEBackupUrlDownloadException catch (e) {
      iPrint('[E2EEBackupImport] URL 下载失败: ${e.code} $e');
      if (mounted) _showError(_mapUrlDownloadError(e.code));
    } on Object catch (e) {
      // _verifyFile 内部已捕获校验失败（on Object）并自行 _showError，不会 rethrow。
      // 走到这里只可能是 downloadToTemp 之后、_verifyFile 之前的意外异常
      // （如 mounted 检查与 File 构造之间的极小窗口），用通用下载失败文案兜底。
      iPrint('[E2EEBackupImport] URL 下载未知异常: $e');
      if (mounted) _showError(t.common.e2eeBackupErrUrlDownload);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  String _mapUrlDownloadError(E2EEBackupUrlDownloadErrorCode code) {
    switch (code) {
      case E2EEBackupUrlDownloadErrorCode.invalidUrl:
        return t.common.e2eeBackupErrUrlInvalid;
      case E2EEBackupUrlDownloadErrorCode.networkError:
      case E2EEBackupUrlDownloadErrorCode.ioError:
      case E2EEBackupUrlDownloadErrorCode.unknown:
        return t.common.e2eeBackupErrUrlDownload;
      case E2EEBackupUrlDownloadErrorCode.timeout:
        return t.common.e2eeBackupErrUrlTimeout;
      case E2EEBackupUrlDownloadErrorCode.tlsError:
        return t.common.e2eeBackupErrUrlTls;
      case E2EEBackupUrlDownloadErrorCode.httpError:
        return t.common.e2eeBackupErrUrlHttp;
      case E2EEBackupUrlDownloadErrorCode.emptyResponse:
        return t.common.e2eeBackupErrUrlEmpty;
      case E2EEBackupUrlDownloadErrorCode.tooLarge:
        return t.common.e2eeBackupErrUrlTooLarge;
    }
  }

  Widget _buildUrlInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.link, color: AppColors.iosBlue),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Text(
                    t.common.e2eeBackupUrlImportTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.iosBlue,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupUrlImportHint,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.getTextSecondary(Theme.of(context).brightness),
              ),
            ),
            AppSpacing.verticalMedium,
            TextField(
              enableSuggestions: false,
              autocorrect: false,
              controller: _urlController,
              enabled: !_isDownloading,
              keyboardType: TextInputType.url,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                labelText: t.common.e2eeBackupUrlFieldLabel,
                hintText: t.common.e2eeBackupUrlFieldHint,
                prefixIcon: const Icon(CupertinoIcons.link),
                border: const OutlineInputBorder(),
                suffixIcon: _isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CupertinoActivityIndicator(),
                      )
                    : (_urlController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(CupertinoIcons.clear_thick),
                              tooltip: t.common.clear,
                              onPressed: _isDownloading
                                  ? null
                                  : () {
                                      _urlController.clear();
                                      setState(() {});
                                    },
                            )
                          : null),
              ),
              onChanged: (_) => setState(() {}),
            ),
            AppSpacing.verticalMedium,
            OutlinedButton.icon(
              onPressed: (_isDownloading || _urlController.text.trim().isEmpty)
                  ? null
                  : _handleUrlDownload,
              icon: _isDownloading
                  ? const SizedBox(
                      height: AppSpacing.large,
                      width: AppSpacing.large,
                      child: CupertinoActivityIndicator(),
                    )
                  : const Icon(CupertinoIcons.cloud_download),
              label: Text(
                _isDownloading
                    ? t.common.e2eeBackupUrlDownloading
                    : t.common.e2eeBackupUrlImportBtn,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyFile() async {
    if (!mounted || _selectedFile == null) return;
    final file = _selectedFile!;
    final generation = ++_fileVerificationGeneration;

    try {
      final verify =
          widget.backupFileVerifier ?? E2EELocalBackupService.verifyBackupFile;
      final info = await verify(file.path);
      if (!_isCurrentFileVerification(file, generation)) return;
      setState(() => _backupInfo = info);
    } on Object catch (e) {
      if (!_isCurrentFileVerification(file, generation)) return;
      // verifyBackupFile 的格式错误均为 ArgumentError——当前 Dart SDK 中
      // ArgumentError 仅 implements Error（不 implements Exception），
      // 用 on Exception 会捕获不到而静默冒泡（用户无任何提示）。
      // 校验失败一律清空元信息并提示。
      iPrint('[E2EEBackupImport] 校验备份文件失败: $e');
      setState(() {
        _backupInfo = null;
      });
      _showError(t.common.e2eeBackupErrValidateFailed);
    }
  }

  bool _isCurrentFileVerification(File file, int generation) =>
      mounted &&
      _selectedFile == file &&
      _fileVerificationGeneration == generation;

  /// 当前登录账号 uid（跨账号恢复校验用）。
  /// 登出态/读取异常 → null（无法判定则不强校验，与缓存口令的 uid
  /// 保险逻辑同一取舍）。
  String? get _currentAccountId {
    try {
      final uid = UserRepoLocal.to.currentUid;
      return uid.isEmpty ? null : uid;
    } on Object {
      return null;
    }
  }

  /// 把恢复链路的 StateError 映射为精确文案（区别于笼统的导入失败）：
  /// - backup_account_mismatch：备份属于其他账号
  /// - stale_backup_rejected：旧版本备份重放
  String _stateErrorMessage(StateError e) {
    switch (e.message) {
      case 'backup_account_mismatch':
        return t.common.e2eeBackupErrAccountMismatch;
      case 'stale_backup_rejected':
        return t.common.e2eeBackupErrStaleBackup;
      default:
        return t.common.e2eeBackupErrImportFailed;
    }
  }

  Future<void> _handleImport() async {
    if (!mounted ||
        _isImporting ||
        _isCloudRestoring ||
        _selectedFile == null ||
        _backupInfo == null) {
      return;
    }
    final password = _passwordController.text;

    try {
      setState(() => _isImporting = true);

      final result =
          await (widget.backupFileImporter?.call(
                _selectedFile!.path,
                password,
                _currentAccountId,
              ) ??
              E2EELocalBackupService.importBackup(
                filePath: _selectedFile!.path,
                password: password,
                expectedAccountId: _currentAccountId,
              ));

      if (!mounted) return;
      await _applyRestoredKeys(result);
    } on StateError catch (e) {
      iPrint('[E2EEBackupImport] 导入被拒绝: ${e.message}');
      if (mounted) _showError(_stateErrorMessage(e));
    } on Object catch (e) {
      // importBackup 的口令错误/格式无效/校验和不匹配均为 ArgumentError，
      // 只 implements Error 不 implements Exception，on Exception 捕不到
      // （同 _verifyFile 的处理原因）。
      iPrint('[E2EEBackupImport] 导入备份失败: errType=${e.runtimeType}');
      if (mounted) {
        _showError(
          e is ArgumentError
              ? t.common.e2eeBackupErrCloudPwd
              : t.common.e2eeBackupErrImportFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// 云端备份存在性探测（决定是否显示"从云端恢复"入口）
  Future<void> _probeCloudBackup() async {
    try {
      final probe = widget.cloudBackupProbe;
      final info = await (probe?.call() ?? E2EEBackupApi().info());
      if (!mounted) return;
      setState(() {
        _cloudInfo = info;
        _cloudProbeFailed = false;
      });
    } on Object catch (e) {
      // 探测失败（如网络抖动）若按无云端备份处理，用户会误走"生成新密钥"
      // 危险路径——置失败标记，由 build 在云端恢复入口位置渲染重试按钮。
      iPrint('[E2EEBackupImport] 云端备份探测失败: errType=${e.runtimeType}');
      if (mounted) setState(() => _cloudProbeFailed = true);
    }
  }

  /// 云端备份探测失败时的重试入口（高度对齐文件内既有行样式 48）。
  Widget _buildCloudProbeRetry() {
    return CupertinoButton(
      minimumSize: const Size(double.infinity, 48),
      padding: EdgeInsets.zero,
      onPressed: _isCloudRestoring ? null : _probeCloudBackup,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.refresh,
            size: 20,
            color: AppColors.iosBlue,
          ),
          AppSpacing.horizontalSmall,
          Text(
            t.common.buttonRetry,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosBlue,
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出口令输入确认框（恢复会覆盖本地密钥，需显式确认）
  Future<void> _promptCloudRestore() async {
    if (!mounted || _isImporting || _isCloudRestoring) return;
    _cloudPasswordController.clear();
    final password = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.e2eeBackupCloudRestoreTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(t.common.e2eeBackupCloudRestoreConfirmNote),
            AppSpacing.verticalSmall,
            CupertinoTextField(
              enableSuggestions: false,
              autocorrect: false,
              controller: _cloudPasswordController,
              obscureText: true,
              autofocus: true,
              placeholder: t.common.e2eeBackupCloudPwdHint,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(context).pop(_cloudPasswordController.text),
            child: Text(t.common.e2eeBackupCloudRestoreBtn),
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty || !mounted) return;
    await _handleCloudRestore(password);
  }

  Future<void> _handleCloudRestore(String password) async {
    if (!mounted || _isImporting || _isCloudRestoring) return;
    try {
      setState(() => _isCloudRestoring = true);

      final result =
          await (widget.cloudBackupRestorer?.call(
                password,
                _currentAccountId,
              ) ??
              E2EEServerBackupService.restore(
                password: password,
                expectedAccountId: _currentAccountId,
              ));

      if (!mounted) return;
      await _applyRestoredKeys(result);
    } on StateError catch (e) {
      if (!mounted) return;
      if (e.message == '无云端备份') {
        _showError(t.common.e2eeBackupErrNoCloudBackup);
      } else {
        _showError(_stateErrorMessage(e));
      }
    } on ArgumentError {
      if (mounted) _showError(t.common.e2eeBackupErrCloudPwd);
    } on Exception catch (e) {
      iPrint('[E2EEBackupImport] 云端恢复失败: ${e.runtimeType}');
      if (mounted) _showError(t.common.e2eeBackupErrCloudRestoreFailed);
    } finally {
      if (mounted) setState(() => _isCloudRestoring = false);
    }
  }

  /// 恢复成功后的统一后处理：保存密钥四元组到安全存储 + 成功弹窗。
  /// 文件导入与云端恢复两条路径共用。
  Future<void> _applyRestoredKeys(Map<String, dynamic> result) async {
    // 抗回滚：比本机最近一次成功恢复更旧且换钥的备份（旧密钥重放）
    // 在写任何存储前拒绝（stale_backup_rejected 由调用方映射文案）。
    await _ensureNotStaleRestore(result);

    await StorageSecureService.to.savePrivateKey(
      result['private_key'] as String,
    );
    await StorageSecureService.to.savePublicKey(result['public_key'] as String);
    // E2EE-016 req3：备份内的 device_id 仅作归档元数据展示（见成功弹窗），
    // 不得覆盖当前物理设备 DID——否则本机会冒充备份来源设备，
    // 破坏 E2EE-013「加密写入绑定已认证设备」的授权边界。故此处不再 setDeviceId。
    // 同理，恢复材料不含 Olm account/session（活跃 ratchet），本机 C2C
    // 会话与新 DID 独立建立——恢复的是「身份密钥 + 群历史解密材料」，
    // 不是克隆原设备。
    await StorageSecureService.to.setKeyId(result['key_id'] as String);

    final section = E2EELocalBackupService.megolmBackupSection(result);
    var restored = 0;
    // durable progress：第 N 条写入失败时异常携带精确进度；密钥本体此刻
    // 已恢复，不能虚报「导入失败」，也不能谎称群历史全部就绪。
    MegolmRestoreException? partialFailure;
    if (!section.isEmpty &&
        await _confirmHistoricalKeyGrant(section.sessions.length)) {
      try {
        restored = await E2EELocalBackupService.restoreMegolmSessions(
          result,
          historicalGrantConfirmed: true,
          auditBeforeRestore: _auditHistoricalKeyGrant,
        );
      } on MegolmRestoreException catch (e) {
        partialFailure = e;
        iPrint(
          '[RESTORE] Megolm 恢复部分完成: '
          '${e.writtenEntries}/${e.totalEntries} failedKey=${e.failedKey}',
        );
      }
      GroupSessionService.to.clearMemory();
    }

    if (restored > 0) {
      iPrint('[RESTORE] Megolm 会话回填 $restored');
    }

    // 恢复得到的私钥必须与服务端登记的该设备公钥一致：登录时本地无密钥会先
    // 生成并上报一套「新」公钥（passport_notifier._reportE2EEPublicKey），此处
    // 不回写，服务端就持久持有一把本机没有私钥的公钥——legacy v1/v2 路径的对端
    // 仍按它加密（本机解不开），密钥盘点与 e2ee_device_key_changed 广播链同样
    // 建立在错误状态上。立即回写消除该窗口（Olm v3 信封按每设备 Olm 身份键
    // 加密，不在本修复的直接症状路径内）。
    final synced = await _syncRestoredPublicKeyToServer(result);
    if (synced) {
      // 密钥已恢复，清除会话页「恢复待办」横幅标记并通知撤下——
      // 否则横幅常驻（唯一清除入口此前只有横幅 ×）
      await StorageService.to.setBool(kE2eeRecoveryNeededKey, false);
      AppEventBus.fire(const E2EERecoveryCompletedEvent());
    } else {
      // 保留「恢复待办」标记：设备身份未同步即视为恢复未完成，让横幅继续提示。
      // 下次登录 _reportE2EEPublicKey 在本地已有密钥时会用本地（已恢复）公钥
      // 重报，届时自愈。
      iPrint('[RESTORE] 设备公钥回写未完成，保留恢复待办标记');
    }

    // 抗回滚水位：密钥本体已应用即记录 created_at/key_id（Megolm 部分完成
    // 也记录——水位锚定的是密钥版本，群历史可幂等重试补完）。
    await _writeRestoreMarker(result);

    // 路径4：自动重试解密失败消息。Megolm session 已回填，群聊历史的
    // 「[加密消息]」占位此刻即可翻明文——若等用户去恢复中心手动点
    // 「重试解密」，等于没人点。逐条修复自带 events/messages 回填，
    // 打开着的会话页会原地刷新。
    int recovered = 0;
    try {
      recovered = await E2EEHealthCheckService.to.retryFailedMessages();
    } on Object catch (e) {
      // 重试失败不阻断恢复成功态：用户可在恢复中心手动重试兜底
      iPrint('[RESTORE] 自动重试解密中断: ${e.runtimeType}');
    }

    if (!mounted) return;
    if (partialFailure != null) {
      // 部分完成：密钥已恢复 + Megolm 写入 X/Y——精确陈述，不虚报完整成功，
      // 也不把已完成部分说成全失败；重试同一备份按幂等键续写收敛。
      _showPartialRestoreDialog(
        partialFailure,
        deviceKeySynced: synced,
        recovered: recovered,
      );
      return;
    }
    _showSuccessDialog(
      result,
      deviceKeySynced: synced,
      recovered: recovered,
      restored: restored,
      omitted:
          section.omittedSessionCount +
          (restored == 0 ? section.sessions.length : 0),
    );
  }

  /// 抗回滚前置校验：读取本机恢复水位并调用纯校验函数。
  /// 水位读取失败（平台通道异常等）按「无水位」放行——水位只是回滚防线，
  /// 不能因元数据通道故障阻断合法恢复。
  Future<void> _ensureNotStaleRestore(Map<String, dynamic> result) async {
    final raw = _readRestoreMarkerRaw();
    Map<dynamic, dynamic>? marker;
    try {
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      if (decoded is Map) marker = decoded;
    } on FormatException {
      marker = null;
    }
    E2EELocalBackupService.ensureNotStaleRestore(
      backupCreatedAt: result['created_at']?.toString(),
      backupKeyId: result['key_id']?.toString(),
      markerCreatedAt: marker?['created_at']?.toString(),
      markerKeyId: marker?['key_id']?.toString(),
    );
  }

  String _readRestoreMarkerRaw() {
    try {
      return StorageService.to.getString(
        E2EELocalBackupService.kLastRestoreMarkerKey,
      );
    } on Object catch (e) {
      iPrint('[RESTORE] 水位标记读取失败(按无水位放行): ${e.runtimeType}');
      return '';
    }
  }

  Future<void> _writeRestoreMarker(Map<String, dynamic> result) async {
    try {
      await StorageService.to.setString(
        E2EELocalBackupService.kLastRestoreMarkerKey,
        jsonEncode({
          'created_at': result['created_at']?.toString() ?? '',
          'key_id': result['key_id']?.toString() ?? '',
        }),
      );
    } on Object catch (e) {
      // 水位写入失败不阻断恢复成功态：只是少一道回滚防线
      iPrint('[RESTORE] 水位标记写入失败: ${e.runtimeType}');
    }
  }

  Future<bool> _confirmHistoricalKeyGrant(int sessionCount) async {
    final confirmer = widget.historicalKeyGrantConfirmer;
    if (confirmer != null) return confirmer(sessionCount);
    if (!mounted) return false;
    return await showCupertinoDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => CupertinoAlertDialog(
            title: Text(t.common.e2eeBackupHistoryGrantTitle),
            content: Text(
              t.common.e2eeBackupHistoryGrantBody(count: sessionCount),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(t.common.buttonCancel),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(t.common.buttonConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _auditHistoricalKeyGrant(MegolmBackupSection section) async {
    final auditor = widget.historicalKeyGrantAuditor;
    if (auditor != null) return auditor(section);
    final db = await SqliteService.to.db;
    if (db == null) throw StateError('crypto_audit_store_unavailable');
    final log = CryptoAuditLog(db);
    await log.ensureSchema();
    for (final session in section.sessions) {
      final sessionHash = crypto.sha256
          .convert(utf8.encode(session.sessionId))
          .toString()
          .substring(0, 16);
      await log.append(
        AuditEventType.historicalRoomKeyGranted,
        peerUid: session.scope,
        peerDeviceId: sessionHash,
        detail: jsonEncode({
          'gid': session.scope,
          'generation_no': session.grant.generationNo,
          'start_seq': session.grant.startSeq,
          'end_seq': session.grant.endSeq,
          'source': 'backup_restore',
        }),
      );
    }
  }

  /// 用恢复得到的公钥回写服务端该设备的登记公钥。
  ///
  /// device_id 取值顺序镜像 passport_notifier._reportE2EEPublicKey：
  /// 先读 secure storage，空了才取当前设备 DID 并回存——后端按
  /// (uid, device_id) upsert，两处取值不一致会把公钥写到另一行，
  /// 真实设备的行仍残留登录时误报的新公钥。
  /// 不用备份内的 device_id：那是归档元数据，用它上报会让本机冒充
  /// 备份来源设备（E2EE-013 / E2EE-016 req3）。
  Future<bool> _syncRestoredPublicKeyToServer(
    Map<String, dynamic> result,
  ) async {
    final reporter = widget.deviceKeyReporter;
    if (reporter != null) return reporter(result);
    try {
      final storage = StorageSecureService.to;
      var deviceId = await storage.getDeviceId() ?? '';
      final detail = await DeviceExt.to.detail;
      if (deviceId.isEmpty) {
        deviceId = detail?['did']?.toString() ?? '';
        if (deviceId.isNotEmpty) {
          await storage.setDeviceId(deviceId);
        }
      }
      if (deviceId.isEmpty) return false;
      final res = await E2EEApi().reportDeviceKey(
        deviceId: deviceId,
        deviceType: detail?['cos']?.toString() ?? 'unknown',
        deviceName: detail?['deviceName']?.toString(),
        publicKey: result['public_key'] as String,
        keyId: result['key_id'] as String,
      );
      return res.ok;
    } on Object catch (e) {
      iPrint('[RESTORE] 设备公钥回写异常: ${e.runtimeType}');
      return false;
    }
  }

  /// 部分完成弹窗（durable progress 精确文案）：
  /// 密钥本体已恢复；群密钥写入 X/Y 条中断，重试同一备份即可幂等补完。
  void _showPartialRestoreDialog(
    MegolmRestoreException failure, {
    required bool deviceKeySynced,
    int recovered = 0,
  }) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.e2eeBackupRestorePartialTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupRestorePartialBody(
                written: failure.writtenEntries,
                total: failure.totalEntries,
              ),
            ),
            AppSpacing.verticalSmall,
            // 信任根变化可见：恢复即更换本机身份密钥，Safety Number 随之变化
            Text(
              t.common.e2eeBackupSafetyNumberChangedNote,
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.getTextSecondary(Theme.of(context).brightness),
              ),
            ),
            if (!deviceKeySynced) ...[
              AppSpacing.verticalSmall,
              Text(
                t.common.e2eeBackupDeviceKeySyncPending,
                style: context.textStyle(
                  FontSizeType.small,
                  color: AppColors.getTextSecondary(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ],
            if (recovered > 0) ...[
              AppSpacing.verticalSmall,
              Text(
                t.common.e2eeRetryFailedDone(count: recovered),
                style: context.textStyle(
                  FontSizeType.small,
                  color: AppColors.getTextSecondary(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(t.common.buttonAccomplish),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(
    Map<String, dynamic> result, {
    required bool deviceKeySynced,
    int recovered = 0,
    int restored = 0,
    int omitted = 0,
  }) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.e2eeBackupImportSuccessTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(t.common.e2eeBackupImportSuccessBody),
            AppSpacing.verticalMedium,
            Text(
              'Device ID: ${_maskId(result['device_id']?.toString() ?? '')}',
            ),
            Text('Key ID: ${_maskId(result['key_id']?.toString() ?? '')}'),
            Text('${t.common.e2eeBackupCreatedAtRow}: ${result['created_at']}'),
            AppSpacing.verticalMedium,
            Text(
              t.common.e2eeBackupImportSuccessNote,
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.getTextSecondary(Theme.of(context).brightness),
              ),
            ),
            // 信任根变化可见：恢复即更换本机身份密钥，与联系人的
            // Safety Number 随之变化——此前已验证的比对结果不再适用，
            // 需重新带外核验（见 safety_number.dart 的多设备聚合语义）。
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupSafetyNumberChangedNote,
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.iosOrange,
              ),
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupHistoryRestoreResult(
                restored: restored,
                omitted: omitted,
              ),
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.getTextSecondary(Theme.of(context).brightness),
              ),
            ),
            // 设备身份未同步时横幅会保留「恢复待办」提示；若弹窗不说清这层，
            // 用户刚被告知成功、转头又见横幅，会当成恢复失败来回折腾。
            if (!deviceKeySynced) ...[
              AppSpacing.verticalSmall,
              Text(
                t.common.e2eeBackupDeviceKeySyncPending,
                style: context.textStyle(
                  FontSizeType.small,
                  color: AppColors.getTextSecondary(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ],
            // 自动重试的成果：群聊历史占位已翻明文的条数（复用恢复中心
            // 手动重试的既有文案，不新增 key）
            if (recovered > 0) ...[
              AppSpacing.verticalSmall,
              Text(
                t.common.e2eeRetryFailedDone(count: recovered),
                style: context.textStyle(
                  FontSizeType.small,
                  color: AppColors.getTextSecondary(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(t.common.buttonAccomplish),
          ),
        ],
      ),
    );
  }

  /// 脱敏 ID 显示（只显示前4位和后4位）
  String _maskId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  void _showError(String message) {
    AppLoading.showToast(message);
  }
}
