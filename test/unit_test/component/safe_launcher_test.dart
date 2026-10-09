import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/safe_launcher.dart';
import 'package:imboy/component/web_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _Launcher extends UrlLauncherPlatform {
  final calls = <String>[];
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> canLaunch(String url) async {
    calls.add('can:$url');
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls.add('launch:$url');
    return true;
  }
}

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  late UrlLauncherPlatform previous;
  late _Launcher launcher;
  setUp(() {
    previous = UrlLauncherPlatform.instance;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
  });
  tearDown(() => UrlLauncherPlatform.instance = previous);

  testWidgets('网页点击立即发起内嵌导航，忽略外部模式且不传入凭据', (tester) async {
    final routes = _Routes();
    BuildContext? host;
    Future<bool>? result;
    await tester.pumpWidget(
      CupertinoApp(
        navigatorObservers: [routes],
        home: Builder(
          builder: (context) {
            host = context;
            return CupertinoButton(
              onPressed: () {
                result = SafeLauncher.safeLaunchUrlString(
                  'https://example.test/page',
                  context: context,
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    expect(
      await SafeLauncher.safeLaunchUrlString(
        'https:/missing-host',
        context: host,
      ),
      isFalse,
    );
    expect(routes.pushed, hasLength(1));
    await tester.tap(find.text('open'));
    expect(await result, isTrue);
    expect(routes.pushed, hasLength(2));
    final route = routes.pushed.last as CupertinoPageRoute<void>;
    final page = route.builder(host!) as WebViewPage;
    expect(page.url, 'https://example.test/page');
    expect(page.title, 'example.test');
    expect(page.allowOaDevicePermissions, isFalse);
    expect(launcher.calls, isEmpty);
    expect(
      await SafeLauncher.safeLaunchUrl(
        Uri.parse('https://imboy.pub/test_oa.html'),
        context: host,
        allowOaDevicePermissions: true,
      ),
      isTrue,
    );
    final oaRoute = routes.pushed.last as CupertinoPageRoute<void>;
    final oaPage = oaRoute.builder(host!) as WebViewPage;
    expect(oaPage.allowOaDevicePermissions, isTrue);
    expect(launcher.calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('网页没有上下文、缺 host 或危险 scheme 都不会外部打开', () async {
    for (final url in [
      'https://example.test',
      'https:/missing-host',
      'javascript:alert(1)',
      'file:///private/test',
      'data:text/html,test',
      'intent://example',
    ]) {
      expect(await SafeLauncher.safeLaunchUrlString(url), isFalse);
    }
    expect(launcher.calls, isEmpty);
  });

  testWidgets('已卸载页面不能导航或回退到外部浏览器', (tester) async {
    late BuildContext oldContext;
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) {
            oldContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      await SafeLauncher.safeLaunchUrl(
        Uri.parse('http://example.test'),
        context: oldContext,
      ),
      isFalse,
    );
    expect(launcher.calls, isEmpty);
  });

  test('电话、邮件、短信仍使用系统协议', () async {
    for (final url in ['tel:123', 'mailto:test@example.test', 'sms:123']) {
      expect(await SafeLauncher.safeLaunchUrlString(url), isTrue);
    }
    expect(
      launcher.calls.where((call) => call.startsWith('launch:')),
      hasLength(3),
    );
  });
}
// Tests replace the already resolved url_launcher platform implementation.
// ignore_for_file: depend_on_referenced_packages
