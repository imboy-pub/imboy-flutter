import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/single/video_viewer.dart';
import 'package:imboy/service/group_file_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mime/mime.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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
              .whereType<Map>()
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

    final result = await FilePicker.platform.pickFiles(
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
      ).showSnackBar(const SnackBar(content: Text('文件读取失败，请重试')));
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
        SnackBar(content: Text(success ? '文件上传成功' : '文件上传失败，请稍后重试')),
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除群文件'),
        content: Text('确定删除文件「$fileName」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final success = await GroupFileService.to.deleteFile(fileId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(success ? '文件已删除' : '删除失败，请稍后重试')));
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
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => WebViewPage(url, title)));
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
                title: Text(fileName.isEmpty ? '图片预览' : fileName),
                trailing: IconButton(
                  tooltip: '关闭预览',
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
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, size: 36),
                          SizedBox(height: 8),
                          Text('图片加载失败'),
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
          ? (type == _MediaPreviewType.video ? '视频预览' : '音频预览')
          : fileName;

      if (type == _MediaPreviewType.video) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoViewerPage(url: url, thumb: url),
          ),
        );
        return true;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _GroupFileAudioPreviewPage(url: url, title: title),
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
      ).showSnackBar(const SnackBar(content: Text('文件地址缺失，无法打开')));
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('文件地址无效')));
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
          ).showSnackBar(const SnackBar(content: Text('无法打开文件链接')));
        }
      }
      return;
    }

    if (_shouldPreviewInWebView(file, url)) {
      final title = _resolveFileName(file);
      final opened = await _openWebPreview(url, title.isEmpty ? '文件预览' : title);
      if (!opened) {
        final openedExternal = await _openExternal(uri);
        if (!openedExternal && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法打开文件链接')));
        }
      }
      return;
    }

    if (!await _openExternal(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开文件链接')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: '群文件',
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: '上传文件',
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
          hintText: '搜索群文件',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty || _keyword.isNotEmpty)
                IconButton(
                  tooltip: '清空',
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                ),
              IconButton(
                tooltip: '搜索',
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
      _buildCategoryChip('', '全部'),
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
            NoDataView(text: _emptyText(), onTop: _refreshAll),
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
    final name = (file['file_name'] ?? file['name'])?.toString() ?? '未命名文件';
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
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteFile(file),
        ),
      ),
    );
  }

  String _emptyText() {
    if (_keyword.isNotEmpty) {
      return '未找到匹配文件';
    }
    if (_selectedCategory.isNotEmpty) {
      return '${_categoryLabel(_selectedCategory)}暂无文件';
    }
    return '暂无群文件';
  }

  String _categoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'document':
        return '文档';
      case 'image':
        return '图片';
      case 'video':
        return '视频';
      case 'audio':
        return '音频';
      case 'other':
        return '其他';
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

class _GroupFileAudioPreviewPage extends StatefulWidget {
  const _GroupFileAudioPreviewPage({required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<_GroupFileAudioPreviewPage> createState() =>
      _GroupFileAudioPreviewPageState();
}

class _GroupFileAudioPreviewPageState
    extends State<_GroupFileAudioPreviewPage> {
  late final AudioPlayer _player;
  bool _isPreparing = true;
  String? _errorText;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _bindPlayerListeners();
    _initPlayer();
  }

  void _bindPlayerListeners() {
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
    });

    _player.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() {
        _duration = duration;
      });
    });

    _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.url);
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _errorText = '音频加载失败';
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_isPreparing || _errorText != null) return;
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    await _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds;
    final positionMs = _position.inMilliseconds.clamp(0, maxMs);

    return Scaffold(
      appBar: GlassAppBar(title: widget.title, automaticallyImplyLeading: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.audiotrack, size: 56),
              const SizedBox(height: 16),
              if (_isPreparing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                const Text('音频加载中...'),
              ] else if (_errorText != null) ...[
                Text(_errorText!),
              ] else ...[
                Slider(
                  value: positionMs.toDouble(),
                  max: maxMs.toDouble(),
                  onChanged: (value) =>
                      _player.seek(Duration(milliseconds: value.toInt())),
                ),
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _togglePlay,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? '暂停' : '播放'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
