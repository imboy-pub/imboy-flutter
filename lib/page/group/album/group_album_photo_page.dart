import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_role_rules.dart' show isGroupAdmin;
import 'package:imboy/service/group_album_service.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 群相册图片列表页
class GroupAlbumPhotoPage extends ConsumerStatefulWidget {
  final String groupId;
  final String albumId;
  final String albumName;

  const GroupAlbumPhotoPage({
    super.key,
    required this.groupId,
    required this.albumId,
    this.albumName = '',
  });

  @override
  ConsumerState<GroupAlbumPhotoPage> createState() =>
      _GroupAlbumPhotoPageState();
}

class _GroupAlbumPhotoPageState extends ConsumerState<GroupAlbumPhotoPage> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _photos = [];
  Set<String> _selectedPhotoIds = <String>{};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSelectionMode = false;
  bool _isBatchDeleting = false;
  bool _hasMore = true;
  int _nextPage = 1;
  int _total = 0;
  static const int _pageSize = 30;

  /// 当前登录用户在本群的角色（0 = 未加载 / 不在群），安全默认无管理权限。
  int _currentUserRole = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPhotos(refresh: true);
    unawaited(_loadCurrentRole());
  }

  /// 异步加载当前用户在本群的角色（SR-4：删除他人照片需按角色收窄）。
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

  /// SR-4：删除照片仅上传者本人 / 管理员 / 群主可见可点。
  bool _canDeletePhoto(Map<String, dynamic> photo) {
    if (isGroupAdmin(_currentUserRole)) return true;
    final uploaderId = photo['uploader_id']?.toString().trim() ?? '';
    return uploaderId.isNotEmpty && uploaderId == UserRepoLocal.to.currentUid;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 240;
    if (_scrollController.position.pixels >= threshold) {
      _loadPhotos();
    }
  }

  Future<void> _loadPhotos({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _hasMore = true;
        _nextPage = 1;
      });
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    final page = _nextPage;
    final payload = await GroupAlbumService.to.getPhotos(
      albumId: widget.albumId,
      page: page,
      size: _pageSize,
    );
    final list = payload['list'];
    final total = _toInt(payload['total']);
    final normalized = list is List
        ? list
              .whereType<Map<String, dynamic>>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final nextPhotos = refresh ? normalized : [..._photos, ...normalized];
    final hasMore = nextPhotos.length < total && normalized.isNotEmpty;
    final nextPage = normalized.isEmpty ? page : page + 1;

    final validIds = nextPhotos
        .map(_resolveDeletePhotoId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final nextSelectedIds = _selectedPhotoIds.where(validIds.contains).toSet();

    if (mounted) {
      setState(() {
        _photos = nextPhotos;
        _total = total;
        _hasMore = hasMore;
        _nextPage = nextPage;
        _selectedPhotoIds = nextSelectedIds;
        _isSelectionMode = _isSelectionMode && nextSelectedIds.isNotEmpty;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _enterSelectionMode(Map<String, dynamic> photo) {
    final photoId = _resolveDeletePhotoId(photo);
    if (photoId.isEmpty || !_canDeletePhoto(photo)) return;
    setState(() {
      _isSelectionMode = true;
      _selectedPhotoIds = {photoId};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPhotoIds = <String>{};
    });
  }

  void _togglePhotoSelection(Map<String, dynamic> photo) {
    final photoId = _resolveDeletePhotoId(photo);
    if (photoId.isEmpty || !_canDeletePhoto(photo)) return;
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
      } else {
        _selectedPhotoIds.add(photoId);
      }
      if (_selectedPhotoIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _toggleSelectAll() {
    if (_isBatchDeleting) return;
    final allIds = _photos
        .where(_canDeletePhoto)
        .map(_resolveDeletePhotoId)
        .where((id) => id.isNotEmpty)
        .toSet();
    setState(() {
      if (allIds.isEmpty) return;
      if (_selectedPhotoIds.length == allIds.length) {
        _selectedPhotoIds.clear();
      } else {
        _selectedPhotoIds = allIds;
      }
      if (_selectedPhotoIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    final selectedCount = _selectedPhotoIds.length;
    if (selectedCount == 0 || _isBatchDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.groupAlbumPhotoBatchDeleteTitle),
        content: Text(
          t.common.groupAlbumPhotoBatchDeleteConfirm(count: selectedCount),
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
    if (confirm != true) return;

    setState(() => _isBatchDeleting = true);
    int successCount = 0;
    final targets = _selectedPhotoIds.toList();
    for (final photoId in targets) {
      final success = await GroupAlbumService.to.deletePhoto(photoId);
      if (success) {
        successCount++;
      }
    }
    if (!mounted) return;

    setState(() => _isBatchDeleting = false);
    if (successCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.common.groupAlbumPhotoDeleteFailed)),
      );
      return;
    }

    final failCount = selectedCount - successCount;
    final message = failCount == 0
        ? t.common.groupAlbumPhotoDeletedAll(count: successCount)
        : t.common.groupAlbumPhotoDeletedPartial(
            success: successCount,
            fail: failCount,
          );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    _exitSelectionMode();
    await _loadPhotos(refresh: true);
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final photoId = _resolveDeletePhotoId(photo);
    if (photoId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.groupAlbumPhotoDeleteTitle),
        content: Text(t.common.groupAlbumPhotoDeleteConfirm),
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
    if (confirm != true) return;

    final success = await GroupAlbumService.to.deletePhoto(photoId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? t.common.groupAlbumPhotoDeleted
              : t.common.groupAlbumPhotoDeleteFailed,
        ),
      ),
    );
    if (success) {
      await _loadPhotos(refresh: true);
    }
  }

  String _resolveDeletePhotoId(Map<String, dynamic> photo) {
    return (photo['photo_id'] ?? photo['id'])?.toString().trim() ?? '';
  }

  Future<void> _openPhotoDetail(Map<String, dynamic> photo, int index) async {
    final photoId = _resolveDeletePhotoId(photo);
    if (photoId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.group.groupAlbumPhotoIdMissing)));
      return;
    }

    final photoIds = _photos
        .map((item) => _resolveDeletePhotoId(item))
        .where((id) => id.isNotEmpty)
        .toList();

    final encodedPhotoId = Uri.encodeComponent(photoId);
    final encodedAlbumId = Uri.encodeComponent(widget.albumId);
    final encodedAlbumName = Uri.encodeQueryComponent(widget.albumName);
    final result = await context.push<bool>(
      '/group/${widget.groupId}/album/$encodedAlbumId/photo/$encodedPhotoId?album_name=$encodedAlbumName',
      extra: {'photo_ids': photoIds, 'index': index},
    );
    if (result == true && mounted) {
      await _loadPhotos(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.albumName.isEmpty
        ? t.group.groupAlbumPhotoListTitle
        : widget.albumName;
    final actionWidgets = _isSelectionMode
        ? <Widget>[
            IconButton(
              key: const Key('group_album_photo_select_all'),
              tooltip: t.common.selectAll,
              onPressed: _isBatchDeleting ? null : _toggleSelectAll,
              icon: Icon(
                _selectedPhotoIds.length == _photos.length && _photos.isNotEmpty
                    ? Icons.remove_done
                    : Icons.select_all,
              ),
            ),
            IconButton(
              key: const Key('group_album_photo_batch_delete'),
              tooltip: t.common.groupAlbumPhotoBatchDeleteTooltip,
              onPressed: _selectedPhotoIds.isEmpty || _isBatchDeleting
                  ? null
                  : _deleteSelectedPhotos,
              icon: _isBatchDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
            ),
          ]
        : null;

    return Scaffold(
      appBar: GlassAppBar(
        title: _isSelectionMode
            ? t.group.groupAlbumPhotoSelectedCount(
                count: _selectedPhotoIds.length,
              )
            : '$title${_total > 0 ? ' ($_total)' : ''}',
        automaticallyImplyLeading: !_isSelectionMode,
        leading: _isSelectionMode
            ? IconButton(
                tooltip: t.common.groupAlbumPhotoExitSelection,
                onPressed: _isBatchDeleting ? null : _exitSelectionMode,
                icon: const Icon(Icons.close),
              )
            : null,
        rightDMActions: actionWidgets,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_photos.isEmpty) {
      return NoDataView(
        text: t.group.groupAlbumPhotoEmpty,
        onTop: () => _loadPhotos(refresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPhotos(refresh: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.medium),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _photos.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _photos.length) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return _buildPhotoCell(_photos[index], index);
        },
      ),
    );
  }

  Widget _buildPhotoCell(Map<String, dynamic> photo, int index) {
    final photoId = _resolveDeletePhotoId(photo);
    final isSelected = _selectedPhotoIds.contains(photoId);
    final url = _resolvePhotoUrl(photo);
    return InkWell(
      key: Key('group_album_photo_cell_$index'),
      borderRadius: AppRadius.borderRadiusSmall,
      onTap: () {
        if (_isSelectionMode) {
          _togglePhotoSelection(photo);
          return;
        }
        _openPhotoDetail(photo, index);
      },
      onLongPress: () {
        if (_isSelectionMode) return;
        _enterSelectionMode(photo);
      },
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusSmall,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 缩略图加载前的中性占位底（图片网格衬底，保留中性灰语义）
            Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurfaceContainer,
            ),
            // 选中态压暗蒙层（叠在照片上，固定深色蒙层语义）
            if (isSelected)
              Container(
                color: AppColors.darkBackground.withValues(alpha: 0.102),
              ),
            if (url.isNotEmpty)
              Image(
                image: cachedImageProvider(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Center(child: Icon(Icons.broken_image_outlined)),
              )
            else
              const Center(child: Icon(Icons.image_not_supported_outlined)),
            if (_isSelectionMode)
              Positioned(
                left: 2,
                top: 2,
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? AppColors.iosSkyBlue
                      : AppColors.onPrimary.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
            // SR-4：删除仅上传者本人 / 管理员 / 群主可见（隐藏而非报错）
            if (!_isSelectionMode && _canDeletePhoto(photo))
              Positioned(
                right: 2,
                top: 2,
                child: Material(
                  // 删除按钮叠在照片上，固定深色半透明底以保证可读
                  color: AppColors.darkBackground.withValues(alpha: 0.54),
                  borderRadius: AppRadius.borderRadiusRegular,
                  child: InkWell(
                    key: Key('group_album_photo_delete_$index'),
                    borderRadius: AppRadius.borderRadiusRegular,
                    onTap: () => _deletePhoto(photo),
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.tiny),
                      child: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _resolvePhotoUrl(Map<String, dynamic> photo) {
    final thumbnail = photo['thumbnail_url']?.toString().trim() ?? '';
    if (thumbnail.isNotEmpty) return thumbnail;
    final photoUrl = photo['photo_url']?.toString().trim() ?? '';
    if (photoUrl.isNotEmpty) return photoUrl;
    final url = photo['url']?.toString().trim() ?? '';
    if (url.isNotEmpty) return url;
    return '';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
