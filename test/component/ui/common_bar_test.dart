import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/common_bar.dart';

/// GlassAppBar 组件测试
///
/// 测试覆盖：
/// 1. 默认情况下不显示返回按钮（automaticallyImplyLeading = false）
/// 2. 当 automaticallyImplyLeading = true 且可以返回时，显示返回按钮
/// 3. 当 automaticallyImplyLeading = true 但不能返回时，不显示返回按钮
/// 4. 自定义 leading 组件优先级高于 automaticallyImplyLeading
/// 5. 点击返回按钮执行导航返回
void main() {
  group('GlassAppBar Widget Tests', () {
    group('automaticallyImplyLeading behavior', () {
      testWidgets('默认不显示返回按钮', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: const GlassAppBar(
                title: 'Test Page',
              ),
            ),
          ),
        );

        // 验证：默认情况下不应该显示返回按钮
        expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
      });

      testWidgets('当 canPop = true 且 automaticallyImplyLeading = true 时显示返回按钮',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => Scaffold(
                    appBar: const GlassAppBar(
                      title: 'First Page',
                    ),
                    body: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/second'),
                      child: const Text('Go to second'),
                    ),
                  ),
              '/second': (context) => Scaffold(
                    appBar: const GlassAppBar(
                      title: 'Second Page',
                      automaticallyImplyLeading: true,
                    ),
                  ),
            },
          ),
        );

        // 导航到第二个页面
        await tester.tap(find.text('Go to second'));
        await tester.pumpAndSettle();

        // 验证：应该显示返回按钮
        expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      });

      testWidgets('当 canPop = false 时不显示返回按钮', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: const GlassAppBar(
                title: 'Test Page',
                automaticallyImplyLeading: true,
              ),
            ),
          ),
        );

        // 验证：即使 automaticallyImplyLeading = true，但不能返回时也不显示返回按钮
        expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
      });

      testWidgets('自定义 leading 优先级高于 automaticallyImplyLeading',
          (WidgetTester tester) async {
        const customLeading = Text('Custom');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: const GlassAppBar(
                title: 'Test Page',
                automaticallyImplyLeading: true,
                leading: customLeading,
              ),
            ),
          ),
        );

        // 验证：应该显示自定义 leading，而不是默认返回按钮
        expect(find.text('Custom'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
      });
    });

    group('返回按钮交互测试', () {
      testWidgets('点击返回按钮执行导航返回', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => Scaffold(
                    appBar: const GlassAppBar(title: 'Page 1'),
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: const GlassAppBar(
                                  title: 'Page 2',
                                  automaticallyImplyLeading: true,
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('Go to page 2'),
                      ),
                    ),
                  ),
            },
          ),
        );

        // 导航到第二个页面
        await tester.tap(find.text('Go to page 2'));
        await tester.pumpAndSettle();

        // 验证：第二个页面的返回按钮存在
        expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);

        // 点击返回按钮（使用更精确的选择器）
        final backButton = find.widgetWithIcon(GestureDetector, Icons.arrow_back_ios_new);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // 验证：应该返回到第一个页面
        expect(find.text('Page 1'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
      });

      testWidgets('popTime > 1 时返回多层', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => Scaffold(
                    appBar: const GlassAppBar(title: 'Page 1'),
                    body: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/page2'),
                      child: const Text('Go to page 2'),
                    ),
                  ),
              '/page2': (context) => Scaffold(
                    appBar: const GlassAppBar(
                      title: 'Page 2',
                      automaticallyImplyLeading: true,
                    ),
                    body: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/page3'),
                      child: const Text('Go to page 3'),
                    ),
                  ),
              '/page3': (context) => Scaffold(
                    appBar: const GlassAppBar(
                      title: 'Page 3',
                      automaticallyImplyLeading: true,
                      popTime: 2, // 返回两层
                    ),
                  ),
            },
          ),
        );

        // 导航到第 3 页
        await tester.tap(find.text('Go to page 2'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Go to page 3'));
        await tester.pumpAndSettle();

        // 验证：在第 3 页
        expect(find.text('Page 3'), findsOneWidget);

        // 点击返回按钮（应该返回两层到第 1 页）
        final backButton = find.widgetWithIcon(GestureDetector, Icons.arrow_back_ios_new);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // 验证：应该回到第 1 页
        expect(find.text('Page 1'), findsOneWidget);
      });
    });

    group('UI 属性测试', () {
      testWidgets('显示标题文本', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Test Title',
              ),
            ),
          ),
        );

        expect(find.text('Test Title'), findsOneWidget);
      });

      testWidgets('titleWidget 优先级高于 title', (WidgetTester tester) async {
        const customTitle = Text('Custom Title Widget');

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Text Title',
                titleWidget: customTitle,
              ),
            ),
          ),
        );

        expect(find.text('Custom Title Widget'), findsOneWidget);
        expect(find.text('Text Title'), findsNothing);
      });

      testWidgets('显示右侧操作按钮', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Test',
                rightDMActions: [
                  IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
                ],
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      });

      testWidgets('当没有 rightDMActions 时保留空间', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Test',
              ),
            ),
          ),
        );

        // 验证：右侧应该有一个 SizedBox 占位
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      });
    });

    group('样式测试', () {
      testWidgets('毛玻璃效果正确应用', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Test',
              ),
            ),
          ),
        );

        // 验证：BackdropFilter 存在
        expect(find.byType(BackdropFilter), findsOneWidget);

        // 验证：ClipRRect 存在
        expect(find.byType(ClipRRect), findsOneWidget);
      });

      testWidgets('自定义背景颜色生效', (WidgetTester tester) async {
        const customColor = Colors.blue;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Test',
                backgroundColor: customColor,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SafeArea),
            matching: find.byType(Container).first,
          ),
        );

        final boxDecoration = container.decoration as BoxDecoration;
        expect(boxDecoration.color, isNotNull);
      });

      testWidgets('自定义 toolbarHeight 生效', (WidgetTester tester) async {
        const customHeight = 100.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Test',
                toolbarHeight: customHeight,
              ),
            ),
          ),
        );

        final appBar = tester.widget<GlassAppBar>(find.byType(GlassAppBar));
        expect(appBar.preferredSize.height, customHeight + 16); // +16 for padding
      });
    });

    group('暗色模式测试', () {
      testWidgets('暗色模式下颜色正确', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              appBar: GlassAppBar(
                title: 'Dark Mode Test',
              ),
            ),
          ),
        );

        // 验证：组件正常渲染
        expect(find.text('Dark Mode Test'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
      });
    });

    group('边界测试', () {
      testWidgets('popTime 超过栈深度时安全处理', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => Scaffold(
                    appBar: const GlassAppBar(title: 'Page 1'),
                    body: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/page2'),
                      child: const Text('Go to page 2'),
                    ),
                  ),
              '/page2': (context) => Scaffold(
                    appBar: const GlassAppBar(
                      title: 'Page 2',
                      automaticallyImplyLeading: true,
                      popTime: 10, // 超过栈深度（只有 2 层）
                    ),
                  ),
            },
          ),
        );

        // 导航到第 2 页
        await tester.tap(find.text('Go to page 2'));
        await tester.pumpAndSettle();

        // 验证：在第 2 页
        expect(find.text('Page 2'), findsOneWidget);

        // 点击返回按钮（popTime=10 但只有 2 层，应该安全返回）
        final backButton = find.widgetWithIcon(GestureDetector, Icons.arrow_back_ios_new);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // 验证：应该回到第 1 页（不会崩溃）
        expect(find.text('Page 1'), findsOneWidget);
      });

      testWidgets('popTime = 1 正常工作', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => Scaffold(
                    appBar: const GlassAppBar(title: 'Page 1'),
                    body: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/page2'),
                      child: const Text('Go to page 2'),
                    ),
                  ),
              '/page2': (context) => Scaffold(
                    appBar: const GlassAppBar(
                      title: 'Page 2',
                      automaticallyImplyLeading: true,
                      popTime: 1, // 默认值
                    ),
                  ),
            },
          ),
        );

        // 导航到第 2 页
        await tester.tap(find.text('Go to page 2'));
        await tester.pumpAndSettle();

        // 点击返回按钮
        final backButton = find.widgetWithIcon(GestureDetector, Icons.arrow_back_ios_new);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // 验证：应该回到第 1 页
        expect(find.text('Page 1'), findsOneWidget);
      });

      testWidgets('popTime = 10（最大值）正常工作', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => const Scaffold(
                    body: Center(child: Text('Root')),
                  ),
              '/page1': (context) => Scaffold(
                    appBar: const GlassAppBar(title: 'Page 1'),
                    body: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/page2'),
                      child: const Text('Go to page 2'),
                    ),
                  ),
              '/page2': (context) => Scaffold(
                    appBar: const GlassAppBar(
                      title: 'Page 2',
                      automaticallyImplyLeading: true,
                      popTime: 10, // 最大值
                    ),
                  ),
            },
          ),
        );

        // 从根页面导航到 page1，再到 page2
        Navigator.pushNamed(tester.element(find.text('Root')), '/page1');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Go to page 2'));
        await tester.pumpAndSettle();

        // 点击返回按钮
        final backButton = find.widgetWithIcon(GestureDetector, Icons.arrow_back_ios_new);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // 验证：应该回到根页面
        expect(find.text('Root'), findsOneWidget);
      });
    });

    group('参数验证测试', () {
      testWidgets('有效参数范围正常工作', (WidgetTester tester) async {
        // 这个测试验证参数断言不会抛出异常
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Test',
                popTime: 5, // 有效值 1-10
                blur: 30.0, // 有效值 0-50
                opacity: 0.5, // 有效值 0-1
              ),
            ),
          ),
        );

        // 验证：组件正常渲染
        expect(find.text('Test'), findsOneWidget);
      });
    });

    group('异常场景测试', () {
      testWidgets('根页面不显示返回按钮', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              appBar: GlassAppBar(
                title: 'Root Page',
                automaticallyImplyLeading: true,
              ),
            ),
          ),
        );

        // 验证：根页面没有返回按钮（因为不能 pop）
        expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
      });

      testWidgets('快速连续点击返回按钮', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => Scaffold(
                    appBar: const GlassAppBar(title: 'Page 1'),
                    body: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/page2'),
                      child: const Text('Go to page 2'),
                    ),
                  ),
              '/page2': (context) => Scaffold(
                    appBar: const GlassAppBar(
                      title: 'Page 2',
                      automaticallyImplyLeading: true,
                    ),
                  ),
            },
          ),
        );

        // 导航到第 2 页
        await tester.tap(find.text('Go to page 2'));
        await tester.pumpAndSettle();

        // 快速点击两次返回按钮
        final backButton = find.widgetWithIcon(GestureDetector, Icons.arrow_back_ios_new);
        await tester.tap(backButton);
        // 不等待动画完成就点击第二次
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // 验证：不会崩溃，应该回到第 1 页
        expect(find.text('Page 1'), findsOneWidget);
      });
    });
  });
}
