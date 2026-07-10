import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_role_rules.dart' show isGroupAdmin;
import 'package:imboy/service/group_album_service.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/page/group/widgets/group_dialogs.dart';

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

  /// 当前登录用户在本群的角色（0 = 未加载 / 不在群），安全默认无管理权限。
  int _currentUserRole = 0;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    unawaited(_loadCurrentRole());
  }

  /// 异步加载当前用户在本群的角色（SR-4：删除他人相册需按角色收窄）。
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

  /// SR-4：删除相册仅创建者本人 / 管理员 / 群主可见可点。
  bool _canDeleteAlbum(Map<String, dynamic> album) {
    if (isGroupAdmin(_currentUserRole)) return true;
    final creatorId = album['creator_id']?.toString().trim() ?? '';
    return creatorId.isNotEmpty && creatorId == UserRepoLocal.to.currentUid;
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.chat.groupAlbumCreateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.small),
            CupertinoTextField(
              controller: controller,
              autofocus: true,
              placeholder: t.group.groupAlbumNameHint,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
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
    AppLoading.showToast(
      success ? t.chat.groupAlbumCreated : t.common.groupAlbumCreateFailed,
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

    final confirm = await GroupDialogs.confirm(
      context,
      title: t.common.groupAlbumDeleteTitle,
      content: t.common.groupAlbumDeleteConfirm(name: albumName),
      destructive: true,
    );

    if (!confirm) return;
    final success = await GroupAlbumService.to.deleteAlbum(albumId);
    if (!mounted) return;
    AppLoading.showToast(
      success ? t.common.groupAlbumDeleted : t.common.groupAlbumDeleteFailed,
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.group.groupAlbumRenameTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.small),
            CupertinoTextField(
              controller: controller,
              autofocus: true,
              placeholder: t.group.groupAlbumNameHint,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
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
    AppLoading.showToast(
      success ? t.group.groupAlbumRenamed : t.common.groupAlbumRenameFailed,
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
              // SR-4：删除仅创建者本人 / 管理员 / 群主可见（隐藏而非报错）
              if (_canDeleteAlbum(album))
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: t.common.groupAlbumDeleteTooltip,
                  onPressed: _isUploadingPhoto
                      ? null
                      : () => _deleteAlbum(album),
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
