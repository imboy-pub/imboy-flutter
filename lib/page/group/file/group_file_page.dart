import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_role_rules.dart' show isGroupAdmin;
import 'package:imboy/page/group/widgets/group_dialogs.dart';
import 'package:imboy/page/single/video_viewer_page.dart';
import 'package:imboy/service/group_file_service.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:mime/mime.dart';

import 'group_file_audio_preview_page.dart';
import 'package:url_launcher/url_launcher.dart';

enum _MediaPreviewType { video, audio }

/// 群文件页面
class GroupFilePage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupFilePage({super.key, required this.groupId});

  @visibleForTesting
  static Future<void> Function(BuildContext context, String url, String title)?
  openWebPreviewForTest;

  @visibleForTesting
  static Future<void> Function(
    BuildContext context,
    String url,
    String title,
    String previewKind,
  )?
  openMediaPreviewForTest;

  @visibleForTesting
  static Future<bool> Function(BuildContext context, String url)?
  openExternalForTest;

  @override
  ConsumerState<GroupFilePage> createState() => _GroupFilePageState();
}

class _GroupFilePageState extends ConsumerState<GroupFilePage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _categoryStats = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _selectedCategory = '';
  String _keyword = '';

  /// 当前登录用户在本群的角色（0 = 未加载 / 不在群），安全默认无管理权限。
  int _currentUserRole = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    unawaited(_loadCurrentRole());
  }

  /// 异步加载当前用户在本群的角色（SR-4：删除他人文件需按角色收窄）。
  /// 失败时静默回退，保持 0（安全默认：无管理权限）。
  Future<void> _loadCurrentRole() async {
    try {
      final uid = UserRepoLocal.to.currentUid;
      final member = await GroupMemberRepo().findByUserId(widget.groupId, uid);
      if (mounted && member != null) {
        setState(() => _currentUserRole = member.role);
      }
    } catch (_) {
      // 静默失败：保持 _currentUserRole=0，UI 不显示管理操作
    }
  }

  /// SR-4：删除文件仅上传者本人 / 管理员 / 群主可见可点。
  bool _canDeleteFile(Map<String, dynamic> file) {
    if (isGroupAdmin(_currentUserRole)) return true;
    final uploaderId = file['uploader_id']?.toString().trim() ?? '';
    return uploaderId.isNotEmpty && uploaderId == UserRepoLocal.to.currentUid;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadCategoryStats(), _loadFiles(showLoading: false)]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategoryStats() async {
    final stats = await GroupFileService.to.getCategoryStats(
      groupId: widget.groupId,
    );
    if (mounted) {
      setState(() {
        _categoryStats = stats;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadCategoryStats(), _loadFiles(showLoading: false)]);
  }

  Future<void> _loadFiles({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    final payload = _keyword.isNotEmpty
        ? await GroupFileService.to.searchFiles(
            groupId: widget.groupId,
            keyword: _keyword,
          )
        : await GroupFileService.to.getFiles(
            groupId: widget.groupId,
            category: _selectedCategory.isEmpty ? null : _selectedCategory,
          );
    final list = payload['list'];
    final normalizedList = list is List
        ? list
              .whereType<Map<String, dynamic>>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final files = _selectedCategory.isEmpty
        ? normalizedList
        : normalizedList.where((item) {
            final category = (item['file_category'] ?? '')
                .toString()
                .toLowerCase();
            return category == _selectedCategory.toLowerCase();
          }).toList();
    if (mounted) {
      setState(() {
        _files = files;
        if (showLoading) {
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _applySearch() async {
    final keyword = _searchController.text.trim();
    if (keyword == _keyword) return;
    setState(() => _keyword = keyword);
    await _loadFiles();
  }

  Future<void> _clearSearch() async {
    if (_searchController.text.isEmpty && _keyword.isEmpty) return;
    _searchController.clear();
    setState(() => _keyword = '');
    await _loadFiles();
  }

  Future<void> _selectCategory(String category) async {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    await _loadFiles();
  }

  Future<void> _pickAndUploadFile() async {
    if (_isUploading) return;

    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final fileName = file.name.trim();
    final fileBytes = file.bytes;
    if (fileName.isEmpty || fileBytes == null || fileBytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.common.groupFileReadFailed)));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final created = await GroupFileService.to.uploadFile(
        groupId: widget.groupId,
        fileName: fileName,
        fileBytes: fileBytes,
        fileType: lookupMimeType(fileName),
      );
      if (!mounted) return;
      final success = created != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? t.common.groupFileUploadSuccess
                : t.common.groupFileUploadFailed,
          ),
        ),
      );
      if (success) {
        await _refreshAll();
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final fileId = (file['id'] ?? file['file_id'])?.toString() ?? '';
    if (fileId.isEmpty) return;
    final fileName = (file['file_name'] ?? file['name'])?.toString() ?? fileId;

    final confirm = await GroupDialogs.confirm(
      context,
      title: t.common.groupFileDeleteTitle,
      content: t.common.groupFileDeleteConfirm(name: fileName),
      destructive: true,
    );

    if (!confirm) return;
    final success = await GroupFileService.to.deleteFile(fileId);
    if (!mounted) return;
    AppLoading.showToast(
      success
          ? t.common.groupFileDeleteSuccess
          : t.common.groupFileDeleteFailed,
    );
    if (success) {
      await _refreshAll();
    }
  }

  String _resolveFileUrl(Map<String, dynamic> file) {
    final primary = file['file_url']?.toString().trim() ?? '';
    if (primary.isNotEmpty) return primary;
    final backup = file['url']?.toString().trim() ?? '';
    if (backup.isNotEmpty) return backup;
    final source = file['source']?.toString().trim() ?? '';
    if (source.isNotEmpty) return source;
    return '';
  }

  String _resolveFileName(Map<String, dynamic> file) {
    return (file['file_name'] ?? file['name'])?.toString().trim() ?? '';
  }

  bool _isImageFile(Map<String, dynamic> file, String url) {
    final category = (file['file_category'] ?? '').toString().toLowerCase();
    if (category == 'image') {
      return true;
    }
    final fileName = _resolveFileName(file);
    final mimeType = lookupMimeType(fileName.isNotEmpty ? fileName : url);
    return mimeType?.startsWith('image/') ?? false;
  }

  bool _shouldPreviewInWebView(Map<String, dynamic> file, String url) {
    final category = (file['file_category'] ?? '').toString().toLowerCase();
    if (category == 'document') {
      return true;
    }
    final fileName = _resolveFileName(file);
    final mimeType = lookupMimeType(fileName.isNotEmpty ? fileName : url) ?? '';
    if (mimeType.startsWith('text/')) return true;
    if (mimeType == 'application/pdf') return true;
    return false;
  }

  _MediaPreviewType? _resolveMediaPreviewType(
    Map<String, dynamic> file,
    String url,
  ) {
    final category = (file['file_category'] ?? '').toString().toLowerCase();
    if (category == 'video') return _MediaPreviewType.video;
    if (category == 'audio') return _MediaPreviewType.audio;

    final fileName = _resolveFileName(file);
    final mimeType = lookupMimeType(fileName.isNotEmpty ? fileName : url) ?? '';
    if (mimeType.startsWith('video/')) return _MediaPreviewType.video;
    if (mimeType.startsWith('audio/')) return _MediaPreviewType.audio;
    return null;
  }

  Future<bool> _openWebPreview(String url, String title) async {
    try {
      if (GroupFilePage.openWebPreviewForTest != null) {
        await GroupFilePage.openWebPreviewForTest!(context, url, title);
        return true;
      }
      if (!mounted) return false;
      await Navigator.of(context).push(
        CupertinoPageRoute<dynamic>(builder: (_) => WebViewPage(url, title)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showImagePreview(String url, String fileName) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  fileName.isEmpty ? t.chat.groupFileImagePreview : fileName,
                ),
                trailing: IconButton(
                  tooltip: t.common.groupFileClosePreview,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image(
                      image: cachedImageProvider(url),
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, _, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_outlined, size: 36),
                          AppSpacing.verticalSmall,
                          Text(ctx.t.common.groupFileImageLoadFailed),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _openMediaPreview(
    String url,
    String fileName,
    _MediaPreviewType type,
  ) async {
    try {
      if (GroupFilePage.openMediaPreviewForTest != null) {
        await GroupFilePage.openMediaPreviewForTest!(
          context,
          url,
          fileName,
          type.name,
        );
        return true;
      }

      if (!mounted) return false;
      final title = fileName.isEmpty
          ? (type == _MediaPreviewType.video
                ? t.chat.groupFileVideoPreview
                : t.chat.groupFileAudioPreview)
          : fileName;

      if (type == _MediaPreviewType.video) {
        await Navigator.of(context).push(
          CupertinoPageRoute<dynamic>(
            builder: (_) => VideoViewerPage(url: url, thumb: url),
          ),
        );
        return true;
      }

      await Navigator.of(context).push(
        CupertinoPageRoute<dynamic>(
          builder: (_) => GroupFileAudioPreviewPage(url: url, title: title),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _openExternal(Uri uri) async {
    if (GroupFilePage.openExternalForTest != null) {
      return GroupFilePage.openExternalForTest!(context, uri.toString());
    }
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return true;
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final url = _resolveFileUrl(file);
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.chat.groupFileUrlMissing)));
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.chat.groupFileUrlInvalid)));
      return;
    }

    if (_isImageFile(file, url)) {
      await _showImagePreview(url, _resolveFileName(file));
      return;
    }

    final mediaType = _resolveMediaPreviewType(file, url);
    if (mediaType != null) {
      final opened = await _openMediaPreview(
        url,
        _resolveFileName(file),
        mediaType,
      );
      if (!opened) {
        final openedExternal = await _openExternal(uri);
        if (!openedExternal && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.common.groupFileOpenFailed)));
        }
      }
      return;
    }

    if (_shouldPreviewInWebView(file, url)) {
      final title = _resolveFileName(file);
      final opened = await _openWebPreview(
        url,
        title.isEmpty ? t.chat.groupFilePreview : title,
      );
      if (!opened) {
        final openedExternal = await _openExternal(uri);
        if (!openedExternal && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.common.groupFileOpenFailed)));
        }
      }
      return;
    }

    if (!await _openExternal(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.common.groupFileOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: t.chat.groupFile,
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: t.common.groupFileUploadTooltip,
            onPressed: _isUploading ? null : _pickAndUploadFile,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_isUploading) const LinearProgressIndicator(minHeight: 2),
        _buildSearchBar(),
        _buildCategoryFilters(),
        Expanded(child: _buildFileList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _applySearch(),
        decoration: InputDecoration(
          hintText: t.common.groupFileSearch,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty || _keyword.isNotEmpty)
                IconButton(
                  tooltip: t.common.groupFileSearchClear,
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                ),
              IconButton(
                tooltip: t.common.groupFileSearchAction,
                icon: const Icon(Icons.arrow_forward),
                onPressed: _applySearch,
              ),
            ],
          ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final chips = <Widget>[
      _buildCategoryChip('', t.common.groupFileCategoryAll),
      ..._categoryStats.map((item) {
        final category = (item['category'] ?? '').toString();
        if (category.isEmpty) return const SizedBox.shrink();
        final count = _toInt(item['count']);
        final label = '${_categoryLabel(category)} ($count)';
        return _buildCategoryChip(category, label);
      }),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) => chips[index],
        separatorBuilder: (_, _) => AppSpacing.horizontalSmall,
        itemCount: chips.length,
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _selectCategory(category),
      showCheckmark: false,
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            NoDataView(text: _emptyText()),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          return _buildFileItem(file);
        },
      ),
    );
  }

  Widget _buildFileItem(Map<String, dynamic> file) {
    final name =
        (file['file_name'] ?? file['name'])?.toString() ??
        t.chat.groupFileUnnamed;
    final category = file['file_category']?.toString() ?? '';
    final size = _formatBytes(_toInt(file['file_size']));
    final createdAt = file['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text(name),
        onTap: () => _openFile(file),
        subtitle: Text(
          [
            if (category.isNotEmpty) category,
            size,
            if (createdAt.isNotEmpty) createdAt,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // SR-4：删除仅上传者本人 / 管理员 / 群主可见（隐藏而非报错）
        trailing: _canDeleteFile(file)
            ? IconButton(
                tooltip: t.common.groupFileDeleteTitle,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteFile(file),
              )
            : null,
      ),
    );
  }

  String _emptyText() {
    if (_keyword.isNotEmpty) {
      return t.common.groupFileSearchEmpty;
    }
    if (_selectedCategory.isNotEmpty) {
      return t.chat.groupFileCategoryEmpty(
        category: _categoryLabel(_selectedCategory),
      );
    }
    return t.chat.groupFileEmpty;
  }

  String _categoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'document':
        return t.chat.groupFileCategoryDoc;
      case 'image':
        return t.chat.groupFileCategoryImage;
      case 'video':
        return t.chat.groupFileCategoryVideo;
      case 'audio':
        return t.chat.groupFileCategoryAudio;
      case 'other':
        return t.chat.groupFileCategoryOther;
      default:
        return category;
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIdx = 0;
    while (size >= 1024 && unitIdx < units.length - 1) {
      size /= 1024;
      unitIdx++;
    }
    return '${size.toStringAsFixed(size < 10 && unitIdx > 0 ? 1 : 0)} ${units[unitIdx]}';
  }
}
