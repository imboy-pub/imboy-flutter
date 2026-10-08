import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';

import 'personal_attachment_repository.dart';

class PersonalAttachmentsPage extends StatefulWidget {
  const PersonalAttachmentsPage({super.key, this.repository});
  final PersonalAttachmentRepository? repository;
  @override
  State<PersonalAttachmentsPage> createState() =>
      _PersonalAttachmentsPageState();
}

class _PersonalAttachmentsPageState extends State<PersonalAttachmentsPage> {
  final _search = TextEditingController();
  final List<PersonalAttachment> _items = [];
  late final String _account = UserRepoLocal.to.currentUid;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int _offset = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    final keyword = _search.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await (widget.repository ?? PersonalAttachmentRepository())
          .page(offset: refresh ? 0 : _offset, keyword: keyword);
      if (!mounted ||
          _account != UserRepoLocal.to.currentUid ||
          keyword != _search.text.trim()) {
        return;
      }
      setState(() {
        if (refresh) {
          _items.clear();
          _offset = 0;
        }
        _offset += rows.length;
        _hasMore = rows.length == 40;
        _items.addAll(
          rows
              .map((row) => PersonalAttachment.fromMessage(row.message))
              .whereType<PersonalAttachment>(),
        );
      });
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (keyword != _search.text.trim() &&
            _account == UserRepoLocal.to.currentUid) {
          unawaited(_load(refresh: true));
        }
      }
    }
  }

  Future<void> _open(PersonalAttachment item) async {
    if (_account != UserRepoLocal.to.currentUid) return;
    final message = item.message;
    final parts = message.conversationUk3.split('_');
    if (parts.length != 3 || parts[1] != _account) {
      AppLoading.showToast(context.t.attachmentManager.unavailableSource);
      return;
    }
    final conversation = await _sourceConversation(parts[0], parts[2]);
    if (!mounted || _account != UserRepoLocal.to.currentUid) return;
    if (conversation == null) {
      AppLoading.showToast(context.t.attachmentManager.unavailableSource);
      return;
    }
    context.push(
      '/chat/${conversation.peerId}',
      extra: {
        'type': conversation.type,
        'title': conversation.displayTitle,
        'avatar': conversation.avatar,
        'msg_id': message.id,
      },
    );
  }

  Future<ConversationModel?> _sourceConversation(
    String type,
    String peer,
  ) async {
    try {
      return await ConversationRepo().findByPeerId(type, peer);
    } on Exception {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.attachmentManager;
    if (_account != UserRepoLocal.to.currentUid) return const SizedBox.shrink();
    final keyword = _search.text.trim().toLowerCase();
    final visible = _items
        .where((item) => item.name.toLowerCase().contains(keyword))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(t.personalTitle)),
      body: Column(
        children: [
          Padding(padding: AppSpacing.allRegular, child: Text(t.personalHint)),
          Padding(
            padding: AppSpacing.allRegular,
            child: CupertinoSearchTextField(
              controller: _search,
              placeholder: t.searchHint,
              onChanged: (_) {
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _load(refresh: true),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView(
                children: [
                  if (_error != null)
                    TextButton(
                      onPressed: () => _load(refresh: true),
                      child: Text(t.moreFailed),
                    ),
                  if (!_loading && visible.isEmpty)
                    Padding(
                      padding: AppSpacing.allRegular,
                      child: Text(
                        keyword.isEmpty ? t.emptyLocal : t.emptySearch,
                      ),
                    ),
                  for (final item in visible)
                    _LocalAttachmentTile(item: item, onTap: () => _open(item)),
                  if (_loading)
                    const Center(child: CupertinoActivityIndicator()),
                  if (_hasMore && !_loading)
                    TextButton(onPressed: _load, child: Text(t.loadMore)),
                  Padding(
                    padding: AppSpacing.allRegular,
                    child: Text(
                      t.personalBoundary,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalAttachmentTile extends StatelessWidget {
  const _LocalAttachmentTile({required this.item, required this.onTap});
  final PersonalAttachment item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CupertinoListTile(
    padding: AppSpacing.allRegular,
    leading: const Icon(CupertinoIcons.doc, size: AppSizes.iconSizeMedium),
    title: Text(
      item.name.isEmpty ? context.t.chat.file : item.name,
      maxLines: 2,
    ),
    subtitle: Text(
      '${DateFormat('MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(item.message.createdAt))} · ${context.t.attachmentManager.openSource}',
    ),
    trailing: const CupertinoListTileChevron(),
    onTap: onTap,
  );
}
