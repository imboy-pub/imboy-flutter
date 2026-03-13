import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_album_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// 群相册图片详情页
class GroupAlbumPhotoDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final String albumId;
  final String photoId;
  final String albumName;
  final List<String> photoIds;
  final int initialIndex;

  const GroupAlbumPhotoDetailPage({
    super.key,
    required this.groupId,
    required this.albumId,
    required this.photoId,
    this.albumName = '',
    this.photoIds = const [],
    this.initialIndex = 0,
  });

  @override
  ConsumerState<GroupAlbumPhotoDetailPage> createState() =>
      _GroupAlbumPhotoDetailPageState();
}

class _GroupAlbumPhotoDetailPageState
    extends ConsumerState<GroupAlbumPhotoDetailPage> {
  Map<String, dynamic>? _photo;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isUpdatingCover = false;
  late final List<String> _photoIds;
  late int _currentIndex;
  late String _currentPhotoId;

  @override
  void initState() {
    super.initState();
    _photoIds = widget.photoIds.where((id) => id.trim().isNotEmpty).toList();
    if (_photoIds.isEmpty) {
      _photoIds.add(widget.photoId);
    }
    _currentIndex = widget.initialIndex.clamp(0, _photoIds.length - 1);
    _currentPhotoId = _photoIds[_currentIndex];
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final payload = await GroupAlbumService.to.getPhotoDetail(_currentPhotoId);
    if (mounted) {
      setState(() {
        _photo = payload == null ? null : Map<String, dynamic>.from(payload);
        _isLoading = false;
      });
    }
  }

  bool get _canGoPrev => _currentIndex > 0;
  bool get _canGoNext => _currentIndex < _photoIds.length - 1;

  Future<void> _goPrev() async {
    if (!_canGoPrev || _isLoading) return;
    setState(() {
      _currentIndex -= 1;
      _currentPhotoId = _photoIds[_currentIndex];
    });
    await _loadDetail();
  }

  Future<void> _goNext() async {
    if (!_canGoNext || _isLoading) return;
    setState(() {
      _currentIndex += 1;
      _currentPhotoId = _photoIds[_currentIndex];
    });
    await _loadDetail();
  }

  Future<void> _openExternal() async {
    final photo = _photo;
    if (photo == null) return;
    final url = _resolvePhotoUrl(photo);
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片地址缺失，无法打开')));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片地址无效')));
      return;
    }
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开图片链接')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deletePhoto() async {
    if (_isDeleting) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除图片'),
        content: const Text('确定删除当前图片吗？'),
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

    setState(() => _isDeleting = true);
    try {
      final ok = await GroupAlbumService.to.deletePhoto(_currentPhotoId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ok ? '图片已删除' : '删除失败，请稍后重试')));
      if (ok) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _setAsAlbumCover() async {
    if (_isUpdatingCover) return;
    setState(() => _isUpdatingCover = true);
    try {
      final ok = await GroupAlbumService.to.updateAlbumCover(
        albumId: widget.albumId,
        photoId: _currentPhotoId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ok ? '已设为相册封面' : '设置封面失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingCover = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.albumName.isEmpty ? '图片详情' : widget.albumName;
    final counter = _photoIds.isNotEmpty
        ? ' ${_currentIndex + 1}/${_photoIds.length}'
        : '';
    return Scaffold(
      appBar: GlassAppBar(
        title: '$title$counter',
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            tooltip: '上一张',
            icon: const Icon(Icons.chevron_left),
            onPressed: _canGoPrev ? _goPrev : null,
          ),
          IconButton(
            tooltip: '下一张',
            icon: const Icon(Icons.chevron_right),
            onPressed: _canGoNext ? _goNext : null,
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

    final photo = _photo;
    if (photo == null) {
      return NoDataView(text: '图片不存在或已删除', onTop: _loadDetail);
    }

    final name =
        (photo['photo_name'] ?? photo['name'] ?? photo['photo_id'])
            ?.toString()
            .trim() ??
        '';
    final createdAt = photo['created_at']?.toString() ?? '';
    final size = _toInt(photo['photo_size'] ?? photo['size']);
    final width = _toInt(photo['width']);
    final height = _toInt(photo['height']);
    final uploaderId = photo['uploader_id']?.toString() ?? '-';
    final likeCount = _toInt(photo['like_count']);
    final commentCount = _toInt(photo['comment_count']);
    final isLiked = _toBool(photo['is_liked']);
    final url = _resolvePhotoUrl(photo);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey.shade100,
              child: url.isNotEmpty
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (name.isNotEmpty)
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        if (createdAt.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(createdAt, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('外部打开'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdatingCover ? null : _setAsAlbumCover,
                icon: _isUpdatingCover
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_size_select_large_outlined),
                label: const Text('设为封面'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isDeleting ? null : _deletePhoto,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除图片'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildInfoTile(
          '分辨率',
          width > 0 && height > 0 ? '$width × $height' : '-',
        ),
        _buildInfoTile('文件大小', _formatBytes(size)),
        _buildInfoTile('上传者', uploaderId),
        _buildInfoTile('点赞数', likeCount.toString()),
        _buildInfoTile('评论数', commentCount.toString()),
        _buildInfoTile('我的点赞', isLiked ? '是' : '否'),
        _buildInfoTile('图片ID', _currentPhotoId),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  String _resolvePhotoUrl(Map<String, dynamic> photo) {
    final photoUrl = photo['photo_url']?.toString().trim() ?? '';
    if (photoUrl.isNotEmpty) return photoUrl;
    final thumbnail = photo['thumbnail_url']?.toString().trim() ?? '';
    if (thumbnail.isNotEmpty) return thumbnail;
    final url = photo['url']?.toString().trim() ?? '';
    if (url.isNotEmpty) return url;
    return '';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }
    return false;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '-';
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
