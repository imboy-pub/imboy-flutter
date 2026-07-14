import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';

// Markdown 页面的状态提供者
final markdownContentProvider = Provider.family<String, String>((ref, url) {
  // 这个提供者只是返回 URL，实际内容需要在组件中异步加载
  return url;
});

class MarkdownPage extends ConsumerStatefulWidget {
  const MarkdownPage({
    super.key,
    required this.title,
    required this.url,
    this.leading,
    this.rightDMActions,
    this.selectable = false,
  });

  final String title;
  final String url;
  final bool selectable;
  final Widget? leading;
  final List<Widget>? rightDMActions;

  @override
  ConsumerState<MarkdownPage> createState() => _MarkdownPageState();
}

class _MarkdownPageState extends ConsumerState<MarkdownPage> {
  String _content = "";
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // asset:// 前缀走离线打包文档（设置页更新日志/FAQ/隐私政策——外部
      // gitee raw 匿名访问 404，不可作为运行时依赖）。
      final String content;
      if (widget.url.startsWith('asset://')) {
        content = await rootBundle.loadString(widget.url.substring(8));
      } else {
        File tmpF = await IMBoyCacheManager().getSingleFile(
          widget.url,
          validateImageData: false, // Markdown 文件不验证图片格式
        );
        content = await tmpF.readAsString();
      }
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        leading: widget.leading,
        automaticallyImplyLeading: true,
        title: widget.title,
        rightDMActions: widget.rightDMActions,
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: AsyncStateView(
          isLoading: _isLoading,
          isEmpty: false,
          error: _error,
          errorText: t.common.loadError,
          onRetry: initData,
          child: Markdown(data: _content, selectable: widget.selectable),
        ),
      ),
    );
  }
}
