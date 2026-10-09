import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:imboy/component/helper/safe_launcher.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/ui/app_loading.dart';

/// Display-only compatibility for explicit ports rejected by GFM autolinks.
class ChatWebLinks {
  ChatWebLinks._();

  static final _tokens = RegExp(
    r'```(?:[\s\S]*?```|[\s\S]*$)|~~~(?:[\s\S]*?~~~|[\s\S]*$)|'
    r'`+[^`]*`+|!?\[[^\]]*\]\([^)]*\)|<[^>\n]*>|https?://[^\s<>，。！？；：]+',
    caseSensitive: false,
  );

  static String projectText(String text) => text.replaceAllMapped(_tokens, (m) {
    final token = m[0]!;
    if (!token.toLowerCase().startsWith('http')) return token;
    if (m.start > 0 && RegExp(r'[\w@.+/\-\[(]').hasMatch(text[m.start - 1])) {
      return token;
    }
    final url = _trimEnd(token);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535) {
      return token;
    }
    return '<$url>${token.substring(url.length)}';
  });

  static String _trimEnd(String token) {
    var url = token;
    while (url.isNotEmpty) {
      final last = url[url.length - 1];
      final punctuation = '?!.,:*_~。，！？；：'.contains(last);
      final unbalanced =
          last == ')' &&
          ')'.allMatches(url).length > '('.allMatches(url).length;
      if (!punctuation && !unbalanced) break;
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static TextMessage project(TextMessage message) {
    final text = projectText(message.text);
    return text == message.text ? message : message.copyWith(text: text);
  }

  static StreamState projectStream(StreamState state) =>
      state is StreamStateCompleted
      ? StreamStateCompleted(projectText(state.finalText))
      : state;

  static void Function(String, String) onTap(BuildContext context) =>
      (url, title) async {
        final opened = await SafeLauncher.safeLaunchUrlString(
          url,
          context: context,
        );
        if (!opened && context.mounted) {
          AppLoading.showToast(t.common.cannotOpenWebpage);
        }
      };
}
