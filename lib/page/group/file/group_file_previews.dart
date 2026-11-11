part of 'group_file_page.dart';

/// Media presentation and external fallback; authorization stays with the page.
extension _GroupFilePreviews on _GroupFilePageState {
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
    // 使用 CupertinoPageRoute 全屏预览替代 Material showModalBottomSheet
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (ctx) => Scaffold(
          backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
          appBar: CupertinoNavigationBar(
            middle: Text(
              fileName.isEmpty ? t.chat.groupFileImagePreview : fileName,
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(ctx).pop(),
              child: Icon(
                semanticLabel: ctx.t.common.buttonClose,
                CupertinoIcons.xmark,
                size: 22,
              ),
            ),
          ),
          body: SafeArea(
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
                      const Icon(CupertinoIcons.photo_fill, size: 36),
                      AppSpacing.verticalSmall,
                      Text(ctx.t.common.groupFileImageLoadFailed),
                    ],
                  ),
                ),
              ),
            ),
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
    return SafeLauncher.safeLaunchUrl(uri, context: context);
  }
}
