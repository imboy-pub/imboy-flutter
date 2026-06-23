import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_album_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 群相册页面
class GroupAlbumPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupAlbumPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupAlbumPage> createState() => _GroupAlbumPageState();
}

class _GroupAlbumPageState extends ConsumerState<GroupAlbumPage> {
  List<Map<String, dynamic>> _albums = [];
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);
    final payload = await GroupAlbumService.to.getAlbums(
      groupId: widget.groupId,
    );
    final list = payload['list'];
    if (mounted) {
      setState(() {
        _albums = list is List
            ? list
                  .whereType<Map<String, dynamic>>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
        _isLoading = false;
      });
    }
  }

  Future<void> _createAlbum() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.chat.groupAlbumCreateTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.group.groupAlbumNameHint,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    final albumName = controller.text.trim();
    if (confirmed != true || albumName.isEmpty) {
      return;
    }

    final created = await GroupAlbumService.to.createAlbum(
      groupId: widget.groupId,
      albumName: albumName,
    );
    if (!mounted) return;

    final success = created != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? t.chat.groupAlbumCreated : t.common.groupAlbumCreateFailed,
        ),
      ),
    );
    if (success) {
      await _loadAlbums();
    }
  }

  Future<void> _deleteAlbum(Map<String, dynamic> album) async {
    final albumId = _resolveAlbumId(album);
    if (albumId.isEmpty) return;
    final albumName =
        (album['album_name'] ?? album['name'])?.toString() ?? albumId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.groupAlbumDeleteTitle),
        content: Text(t.common.groupAlbumDeleteConfirm(name: albumName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.getIosRed(
                Theme.of(context).brightness,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final success = await GroupAlbumService.to.deleteAlbum(albumId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? t.common.groupAlbumDeleted
              : t.common.groupAlbumDeleteFailed,
        ),
      ),
    );
    if (success) {
      await _loadAlbums();
    }
  }

  Future<void> _renameAlbum(Map<String, dynamic> album) async {
    final albumId = _resolveAlbumId(album);
    if (albumId.isEmpty) return;
    final currentName =
        (album['album_name'] ?? album['name'])?.toString().trim() ?? '';
    final controller = TextEditingController(text: currentName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.group.groupAlbumRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.group.groupAlbumNameHint,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    final nextName = controller.text.trim();
    if (confirmed != true || nextName.isEmpty || nextName == currentName) {
      return;
    }
    final success = await GroupAlbumService.to.renameAlbum(
      albumId: albumId,
      albumName: nextName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? t.group.groupAlbumRenamed : t.common.groupAlbumRenameFailed,
        ),
      ),
    );
    if (success) {
      await _loadAlbums();
    }
  }

  String _resolveAlbumId(Map<String, dynamic> album) {
    return (album['album_id'] ?? album['id'])?.toString().trim() ?? '';
  }

  Future<void> _pickAndUploadPhoto(Map<String, dynamic> album) async {
    if (_isUploadingPhoto) return;
    final albumId = _resolveAlbumId(album);
    if (albumId.isEmpty) return;

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final photoName = file.name.trim();
    final photoBytes = file.bytes;
    if (photoName.isEmpty || photoBytes == null || photoBytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.common.groupAlbumPhotoReadFailed)),
      );
      return;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      final uploaded = await GroupAlbumService.to.uploadPhoto(
        groupId: widget.groupId,
        albumId: albumId,
        photoName: photoName,
        photoBytes: photoBytes,
      );
      if (!mounted) return;
      final success = uploaded != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? t.common.groupAlbumPhotoUploaded
                : t.common.groupAlbumPhotoUploadFailed,
          ),
        ),
      );
      if (success) {
        await _loadAlbums();
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: t.group.groupAlbum,
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createAlbum,
            tooltip: t.common.groupAlbumCreateTooltip,
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
        if (_isUploadingPhoto) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _albums.isEmpty
              ? NoDataView(text: t.common.groupAlbumNoAlbum, onTop: _loadAlbums)
              : RefreshIndicator(
                  onRefresh: _loadAlbums,
                  child: ListView.builder(
                    itemCount: _albums.length,
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      return _buildAlbumItem(album);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAlbumItem(Map<String, dynamic> album) {
    final name =
        (album['album_name'] ?? album['name'])?.toString() ??
        t.group.groupAlbumUnnamed;
    final photoCount = _toInt(album['photo_count']);
    final createdAt = album['created_at']?.toString() ?? '';
    final albumId = _resolveAlbumId(album);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: ListTile(
        leading: const Icon(Icons.photo_album_outlined),
        title: Text(name),
        onTap: () async {
          if (albumId.isEmpty) return;
          final encodedAlbumId = Uri.encodeComponent(albumId);
          final encodedAlbumName = Uri.encodeQueryComponent(name);
          await context.push(
            '/group/${widget.groupId}/album/$encodedAlbumId/photos?album_name=$encodedAlbumName',
          );
          if (mounted) {
            _loadAlbums();
          }
        },
        subtitle: Text(
          [
            t.group.groupAlbumPhotoCount(count: photoCount),
            if (createdAt.isNotEmpty) createdAt,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 144,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: t.group.groupAlbumRenameTitle,
                onPressed: _isUploadingPhoto ? null : () => _renameAlbum(album),
              ),
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                tooltip: t.common.groupAlbumUploadTooltip,
                onPressed: _isUploadingPhoto
                    ? null
                    : () => _pickAndUploadPhoto(album),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: t.common.groupAlbumDeleteTooltip,
                onPressed: _isUploadingPhoto ? null : () => _deleteAlbum(album),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
