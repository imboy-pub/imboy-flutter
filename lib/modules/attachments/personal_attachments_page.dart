import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'personal_attachment_repository.dart';
import 'personal_attachments_view.dart';

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
    return IosPageTemplate(
      title: t.personalTitle,
      body: SafeArea(
        top: false,
        child: PersonalAttachmentsView(
          search: _search,
          items: visible,
          loading: _loading,
          hasMore: _hasMore,
          hasError: _error != null,
          onSearchChanged: _searchChanged,
          onRefresh: () => _load(refresh: true),
          onMore: _load,
          onOpen: _open,
        ),
      ),
    );
  }

  void _searchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(refresh: true),
    );
  }
}
