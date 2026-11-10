import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/account_local_files.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';

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
  late final AuthSessionScope _session;
  late final AccountLocalTaskOwner _owner;

  bool get _isCurrent =>
      mounted &&
      authSessionReader.isCurrent(_session) &&
      AccountLocalTaskOwner.capture() == _owner;

  @override
  void initState() {
    super.initState();
    _session = authSessionReader.current;
    _owner = AccountLocalTaskOwner.capture(uid: _session.uid);
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.image.readAsBytes();
      if (_isCurrent) setState(() => _imageBytes = bytes);
    } on IOException catch (error) {
      if (kDebugMode) debugPrint('> image read failed: ${error.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CupertinoPageScaffold(
      child: Container(
        height: size.height,
        width: size.width,
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: _imageBytes == null
                  ? const Center(
                      child: CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      ),
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
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    t.common.buttonCancel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                CupertinoButton(
                  onPressed: (_imageBytes == null || _isCropping)
                      ? null
                      : _startCrop,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _isCropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CupertinoActivityIndicator(
                              color: CupertinoColors.white,
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
    if (!_isCurrent || _isCropping) return;
    setState(() => _isCropping = true);
    _controller.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    if (!_isCurrent) return;
    try {
      switch (result) {
        case CropSuccess(:final croppedImage):
          await AccountLocalTaskRegistry.instance.run<void>(
            _owner,
            operation: (task) async {
              final directory = await AccountLocalFiles.directory(task);
              task.throwIfCancelled();
              if (!_isCurrent) return;
              final tmpFile = File(
                '${directory.path}/cropped_${DateTime.now().microsecondsSinceEpoch}.jpg',
              );
              try {
                await tmpFile.writeAsBytes(croppedImage, flush: true);
                task.throwIfCancelled();
                if (_isCurrent) await _upload(tmpFile);
              } finally {
                if (await tmpFile.exists()) await tmpFile.delete();
              }
            },
          );
        case CropFailure(:final cause):
          if (kDebugMode) debugPrint('> crop failed: $cause');
      }
    } on Object catch (error) {
      if (kDebugMode) debugPrint('> crop upload ended: ${error.runtimeType}');
    } finally {
      if (_isCurrent) setState(() => _isCropping = false);
    }
  }

  Future<void> _upload(File file) async {
    // 头像/封面类为公共资源（scope=public，走公开读桶），其余按 private。
    // 与 avatarImageProvider 公开直读链路对齐（resource-access-control.md §9）。
    final String scope = widget.prefix == 'avatar' ? 'public' : 'private';
    await AttachmentApi.uploadFileViaPresignCompat(
      widget.prefix,
      file,
      (Map<String, dynamic> resp, String uri) async {
        if (_isCurrent) Navigator.pop(context, uri);
      },
      (Error error) {
        if (kDebugMode) debugPrint("> on upload ${error.runtimeType}");
      },
      name: widget.filename,
      scope: scope,
    );
  }
}
