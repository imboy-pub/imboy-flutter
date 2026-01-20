import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/i18n/strings.g.dart';

class ScannerResultPage extends StatelessWidget {
  final String scanResult;

  const ScannerResultPage({super.key, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(automaticallyImplyLeading: true, title: t.scanResult),
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
                  tooltip: t.buttonBack,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.keyboard_arrow_left),
                ),
                // copy
                FloatingActionButton(
                  heroTag: 'copy',
                  tooltip: t.buttonCopy,
                  onPressed: () {
                    // 已复制
                    Clipboard.setData(ClipboardData(text: scanResult));
                    EasyLoading.showToast(t.copied);
                  },
                  child: const Icon(Icons.copy_all),
                ),
                // open in browser
                FloatingActionButton(
                  heroTag: "open_in_browser",
                  tooltip: t.openInBrowser,
                  backgroundColor: isUrl(scanResult) ? null : Colors.grey,
                  onPressed: () {
                    if (isUrl(scanResult)) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebViewPage(
                            scanResult,
                            '',
                            errorCallback: (String url) {
                              _showResult(
                                context,
                                "${t.cannotOpenWebpage}: $url",
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
        color: Colors.white,
        child: Center(
          child: Text(
            scanResult,
            textAlign: TextAlign.left,
            style: const TextStyle(color: Colors.black, fontSize: 24),
          ),
        ),
      ),
    );
  }

  Future<void> _showResult(BuildContext context, String txt) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
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
          color: Colors.white,
          child: Center(
            child: Text(
              txt,
              textAlign: TextAlign.left,
              style: const TextStyle(color: Colors.black, fontSize: 24),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      enableDrag: false,
    );
  }
}
