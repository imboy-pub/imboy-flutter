import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

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
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: 64.0,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Space(width: 40),
                FloatingActionButton(
                  heroTag: "back",
                  tooltip: t.common.buttonBack,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.keyboard_arrow_left),
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
                  child: const Icon(Icons.copy_all),
                ),
                // open in browser
                FloatingActionButton(
                  heroTag: "open_in_browser",
                  tooltip: t.main.openInBrowser,
                  backgroundColor: isUrl(scanResult) ? null : AppColors.iosGray,
                  onPressed: () {
                    if (isUrl(scanResult)) {
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
                  },
                  child: const Icon(Icons.open_in_browser),
                ),
                const Space(width: 40),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(0.0),
        height: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Text(
            scanResult,
            textAlign: TextAlign.left,
            style: context.textStyle(
              FontSizeType.largeTitle,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showResult(BuildContext context, String txt) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      builder: (context) => InkWell(
        onTap: () {
          Navigator.pop(context);
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(0.0),
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Text(
              txt,
              textAlign: TextAlign.left,
              style: context.textStyle(
                FontSizeType.largeTitle,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      enableDrag: false,
    );
  }
}
