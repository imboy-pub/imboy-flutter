import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class ScannerResultPage extends StatelessWidget {
  final String scanResult;

  const ScannerResultPage({super.key, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.discovery.scanResult,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: AppSpacing.allRegular,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: "back",
                tooltip: t.common.buttonBack,
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Icon(CupertinoIcons.chevron_left),
              ),
              // copy
              FloatingActionButton(
                heroTag: 'copy',
                tooltip: t.common.buttonCopy,
                onPressed: () {
                  // 已复制
                  Clipboard.setData(ClipboardData(text: scanResult));
                  AppLoading.showToast(t.main.copied);
                },
                child: const Icon(CupertinoIcons.doc_on_doc),
              ),
              // open in browser
              FloatingActionButton(
                heroTag: "open_in_browser",
                tooltip: t.main.openInBrowser,
                backgroundColor: isUrl(scanResult) ? null : AppColors.iosGray,
                onPressed: isUrl(scanResult)
                    ? () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute<dynamic>(
                            builder: (context) => WebViewPage(
                              scanResult,
                              '',
                              errorCallback: (String url) {
                                _showResult(
                                  context,
                                  "${t.common.cannotOpenWebpage}: $url",
                                );
                              },
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Icon(CupertinoIcons.arrow_up_right),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.allRegular,
          child: SelectableText(
            scanResult,
            style: context.textStyle(
              FontSizeType.body,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showResult(BuildContext context, String txt) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(txt),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.common.buttonClose),
          ),
        ],
      ),
    );
  }
}
