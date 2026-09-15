/// 企业会话页（amendment §2.3）
///
/// - 消息列表：after_id 增量拉取（本地游标 = 已加载最大消息 id）；
/// - 发送：POST 消息端点，服务端 accepted 形状落本地缓存；
/// - delivery ACK：加载/发送后对未标记消息逐条调用 ack（delivery-only，
///   本地只置标记、不删除真源——plan EB-D05）；
/// - 附件：仅经企业 content 鉴权代理查看（EB-D06），不展示/不存储
///   presigned URL；
/// - suspend 降级：API 403/409 时展示只读提示并禁用发送。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';

class EnterpriseConversationPage extends StatefulWidget {
  final EntityId orgId;
  final EntityId conversationId;
  final String contactName;

  const EnterpriseConversationPage({
    super.key,
    required this.orgId,
    required this.conversationId,
    this.contactName = '',
  });

  @override
  State<EnterpriseConversationPage> createState() =>
      _EnterpriseConversationPageState();
}

class _EnterpriseConversationPageState
    extends State<EnterpriseConversationPage> {
  final EnterpriseApi _api = EnterpriseApi();
  final EnterpriseStore _store = EnterpriseStoreHolder.instance;
  final TextEditingController _input = TextEditingController();

  List<EnterpriseMessage> _messages = const [];

  /// after_id 游标：已加载的最大消息 id（空串 = 全量首拉）。
  String _cursor = '';
  bool _readOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIncremental();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadIncremental() async {
    try {
      final fresh = await _api.messages(
        widget.orgId,
        widget.conversationId,
        afterId: _cursor,
      );
      for (final m in fresh) {
        await _store.saveMessage(m);
      }
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, ...fresh];
        if (fresh.isNotEmpty) {
          _cursor = fresh.last.id;
        }
      });
      await _ackInbound(fresh);
    } on EnterpriseApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${e.message} (code=${e.code})';
        _readOnly = _readOnly || e.isForbidden || e.isOffboardingRequired;
      });
    }
  }

  /// delivery ACK：只确认投递，不删除本地消息真源（delivery-only）。
  Future<void> _ackInbound(List<EnterpriseMessage> fresh) async {
    final undelivered = fresh
        .where((m) => !m.delivered)
        .map((m) => m.id)
        .toList();
    if (undelivered.isEmpty) return;
    for (final mid in undelivered) {
      await _api.ackDelivered(widget.orgId, widget.conversationId, mid);
    }
    await _store.markDelivered(
      widget.orgId,
      widget.conversationId,
      undelivered,
    );
    if (!mounted) return;
    setState(() {
      _messages = _messages
          .map((m) => undelivered.contains(m.id) ? m.withDelivered() : m)
          .toList();
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _readOnly) return;
    try {
      final sent = await _api.sendMessage(
        widget.orgId,
        widget.conversationId,
        content: text,
      );
      await _store.saveMessage(sent);
      _input.clear();
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _cursor = sent.id;
        _error = null;
      });
    } on EnterpriseApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${e.message} (code=${e.code})';
        _readOnly = _readOnly || e.isForbidden || e.isOffboardingRequired;
      });
    }
  }

  /// 附件查看：仅经企业 content 鉴权代理（每次请求重新鉴权）。
  Future<void> _viewAsset(EnterpriseMessage message) async {
    try {
      final preview = await _api.fetchAssetContentText(
        widget.orgId,
        message.assetId,
      );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('附件预览'),
          content: SingleChildScrollView(child: Text(preview)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } on EnterpriseApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${e.message} (code=${e.code})';
        _readOnly = _readOnly || e.isForbidden || e.isOffboardingRequired;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contactName.isEmpty
              ? '企业会话 ${widget.conversationId}'
              : widget.contactName,
        ),
      ),
      body: Column(
        children: [
          if (_readOnly)
            const Material(
              color: AppColors.warning,
              child: ListTile(
                dense: true,
                leading: Icon(CupertinoIcons.lock),
                title: Text('企业访问已降级只读'),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkError
                      : AppColors.lightError,
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadIncremental,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  final isOutbound =
                      m.senderType == EnterpriseSenderType.businessIdentity;
                  return Align(
                    alignment: isOutbound
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.medium,
                        vertical: AppSpacing.tiny,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      constraints: const BoxConstraints(
                        maxWidth: AppSizes.messageBubbleMaxWidth,
                      ),
                      decoration: BoxDecoration(
                        color: isOutbound
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        borderRadius: AppRadius.borderRadiusMedium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.content),
                          // sender 展示为业务身份名（不是自然人好友，EB-D03/D05）
                          Text(
                            m.senderBusinessIdentityName.isEmpty
                                ? m.senderType.wireName
                                : m.senderBusinessIdentityName,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (m.assetId.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _viewAsset(m),
                              icon: const Icon(
                                CupertinoIcons.paperclip,
                                size: AppSizes.iconSizeXSmall,
                              ),
                              label: const Text('查看附件'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                    ),
                    child: TextField(
                      controller: _input,
                      enabled: !_readOnly,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: '输入企业消息'),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _readOnly ? null : _send,
                  tooltip: '发送',
                  icon: const Icon(CupertinoIcons.paperplane_fill),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
