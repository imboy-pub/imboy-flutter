import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/i18n/strings.g.dart';

// ignore: must_be_immutable
class CropImageRoute extends StatefulWidget {
  CropImageRoute(
    this.image,
    this.prefix, {
    super.key,
    this.imageScale = 1.0,
    this.filename = "",
  });

  String prefix;
  String filename;
  File image;
  double imageScale = 1.0;

  @override
  // ignore: library_private_types_in_public_api
  _CropImageRouteState createState() => _CropImageRouteState();
}

class _CropImageRouteState extends State<CropImageRoute> {
  final _controller = CropController();
  Uint8List? _imageBytes;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.image.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: _imageBytes == null
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Crop(
                      image: _imageBytes!,
                      controller: _controller,
                      aspectRatio: 1.0,
                      onCropped: _onCropped,
                    ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    t.common.buttonCancel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                TextButton(
                  onPressed: (_imageBytes == null || _isCropping)
                      ? null
                      : _startCrop,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _isCropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            t.common.buttonAccomplish,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startCrop() {
    setState(() => _isCropping = true);
    _controller.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        final tmpFile = File(
          '${Directory.systemTemp.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tmpFile.writeAsBytes(croppedImage);
        await _upload(tmpFile);
        Future<void>.delayed(const Duration(milliseconds: 200)).then(
          (_) => tmpFile.delete().catchError((_) => tmpFile, test: (_) => true),
        );
      case CropFailure(:final cause):
        if (kDebugMode) debugPrint('> crop failed: $cause');
    }
    if (mounted) setState(() => _isCropping = false);
  }

  Future<void> _upload(File file) async {
    // 头像/封面类为公共资源（scope=public，走公开读桶），其余按 private。
    // 与 avatarImageProvider 公开直读链路对齐（resource-access-control.md §9）。
    final String scope = widget.prefix == 'avatar' ? 'public' : 'private';
    await AttachmentApi.uploadFileViaPresignCompat(
      widget.prefix,
      file,
      (Map<String, dynamic> resp, String uri) async {
        if (mounted) Navigator.pop(context, uri);
      },
      (Error error) {
        if (kDebugMode) debugPrint("> on upload ${error.runtimeType}");
      },
      name: widget.filename,
      scope: scope,
    );
  }
}
