import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 头像编辑页面
class AvatarEditorPage extends StatefulWidget {
  final String? currentAvatar;
  final Function(String)? onAvatarChanged;

  const AvatarEditorPage({super.key, this.currentAvatar, this.onAvatarChanged});

  @override
  State<AvatarEditorPage> createState() => _AvatarEditorPageState();
}

class _AvatarEditorPageState extends State<AvatarEditorPage> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: t.avatarEditAvatar,
        rightDMActions: [
          if (_selectedImage != null)
            TextButton(
              onPressed: _isUploading ? null : _uploadAvatar,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.buttonSave),
            ),
        ],
      ),
      body: Column(
        children: [
          // 头像预览区域
          Expanded(
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: ClipOval(
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : widget.currentAvatar?.isNotEmpty == true
                      ? Image(
                          image: cachedImageProvider(
                            widget.currentAvatar!,
                            w: 200,
                          ),
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.person, size: 80, color: Colors.grey[400]),
                ),
              ),
            ),
          ),

          // 操作按钮区域
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 选择照片按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.photo_camera),
                    label: Text(t.avatarSelectPhoto),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 删除头像按钮
                if (widget.currentAvatar?.isNotEmpty == true)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _removeAvatar,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(t.avatarDeleteAvatar),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 显示图片来源选择对话框
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(t.avatarTakePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(t.avatarSelectFromAlbum),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: Text(t.buttonCancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.selectImageFailedWithError}: $e')),
        );
      }
    }
  }

  /// 上传头像
  Future<void> _uploadAvatar() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 这里应该调用实际的上传接口
      // 暂时模拟上传过程
      await Future.delayed(const Duration(seconds: 2));

      // 模拟返回的头像URL
      String avatarUrl =
          'https://example.com/avatar/${DateTime.now().millisecondsSinceEpoch}.jpg';

      widget.onAvatarChanged?.call(avatarUrl);
      if (mounted) {
        Navigator.pop(context, avatarUrl);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.saveSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.uploadAvatarFailedWithError}: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  /// 删除头像
  void _removeAvatar() {
    widget.onAvatarChanged?.call('');
    if (mounted) {
      Navigator.pop(context, '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.saveSuccess)));
    }
  }
}
