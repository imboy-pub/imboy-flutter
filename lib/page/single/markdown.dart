import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/common_bar.dart';

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

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    try {
      File tmpF = await IMBoyCacheManager().getSingleFile(widget.url);
      String content = await tmpF.readAsString();
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Markdown(data: _content, selectable: widget.selectable),
      ),
    );
  }
}
