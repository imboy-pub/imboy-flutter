import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// 频道邀请中心页（私有频道）
///
/// 提供两类列表：
/// 1. 我收到的邀请：支持接受/拒绝
/// 2. 我发出的邀请：仅查看状态
class ChannelInvitationPage extends StatefulWidget {
  const ChannelInvitationPage({super.key});

  @override
  State<ChannelInvitationPage> createState() => _ChannelInvitationPageState();
}

class _ChannelInvitationPageState extends State<ChannelInvitationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _processingIds = <String>{};

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _myInvitations = const [];
  List<Map<String, dynamic>> _sentInvitations = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInvitations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitations({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        ChannelService.to.getMyInvitations(),
        ChannelService.to.getSentInvitations(),
      ]);
      if (!mounted) return;
      setState(() {
        _myInvitations = List<Map<String, dynamic>>.from(results[0]);
        _sentInvitations = List<Map<String, dynamic>>.from(results[1]);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '${e.runtimeType}';
      });
    }
  }

  Future<void> _handleInvitationAction({
    required Map<String, dynamic> invitation,
    required bool accept,
  }) async {
    final invitationId = parseModelString(
      invitation['id'] ?? invitation['invitation_id'],
    );
    if (invitationId.isEmpty) return;
    if (_processingIds.contains(invitationId)) return;

    setState(() {
      _processingIds.add(invitationId);
    });

    bool success = false;
    try {
      success = accept
          ? await ChannelService.to.acceptInvitation(invitationId)
          : await ChannelService.to.rejectInvitation(invitationId);
    } finally {
      // 无论成功、失败还是抛异常，都必须解锁按钮。旧实现无 try-finally，
      // ChannelService 方法若外层抛异常，invitationId 会永久滞留在
      // _processingIds 中，用户整个会话都无法再点该邀请。
      if (mounted) {
        setState(() {
          _processingIds.remove(invitationId);
        });
      }
    }

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? t.acceptInvitationFailed : t.rejectInvitationFailed,
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(accept ? t.invitationAccepted : t.invitationRejected),
      ),
    );
    await _loadInvitations(showLoading: false);
  }

  String _statusText(int status) {
    switch (status) {
      case 0:
        return t.invitationStatusPending;
      case 1:
        return t.invitationStatusAccepted;
      case 2:
        return t.invitationStatusRejected;
      case 3:
        return t.invitationStatusExpired;
      case 4:
        return t.invitationStatusCancelled;
      default:
        return t.invitationStatusUnknown;
    }
  }

  Color _statusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
      case 3:
      case 4:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInvitationList({
    required List<Map<String, dynamic>> invitations,
    required bool isMyInvitations,
  }) {
    if (invitations.isEmpty) {
      return NoDataView(
        icon: Icons.mark_email_unread_outlined,
        text: isMyInvitations ? t.noReceivedInvitations : t.noSentInvitations,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadInvitations(showLoading: false),
      child: ListView.separated(
        itemCount: invitations.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final invitation = invitations[index];
          final channelId = parseModelString(invitation['channel_id']);
          final channelName = parseModelString(
            invitation['channel_name'],
            defaultValue: 'Private Channel',
          );
          final status = parseModelInt(invitation['status']);
          final statusText = _statusText(status);
          final statusColor = _statusColor(status);
          final createdAt = parseModelDateTime(invitation['created_at']);
          final expiresAt = invitation['expires_at'] == null
              ? null
              : parseModelDateTime(invitation['expires_at']);
          final peerUid = isMyInvitations
              ? parseModelString(invitation['inviter_uid'])
              : parseModelString(invitation['invitee_uid']);

          return ListTile(
            leading: CircleAvatar(
              child: Icon(
                isMyInvitations ? Icons.mail_outline : Icons.outbox_outlined,
              ),
            ),
            title: Text(
              channelName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMyInvitations
                      ? t.inviterLabel(uid: peerUid.isEmpty ? "-" : peerUid)
                      : t.inviteeLabel(uid: peerUid.isEmpty ? "-" : peerUid),
                ),
                Text(
                  t.createdAtLabel(
                    time: DateFormat("yyyy-MM-dd HH:mm").format(createdAt),
                  ),
                ),
                if (expiresAt != null)
                  Text(
                    t.expiredAtLabel(
                      time: DateFormat("yyyy-MM-dd HH:mm").format(expiresAt),
                    ),
                  ),
                // Internal IDs removed from UI display
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (channelId.isNotEmpty)
                  IconButton(
                    onPressed: () => context.push('/channel/$channelId'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    tooltip: t.openChannel,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22),
                  ),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            isThreeLine: true,
            onTap: channelId.isEmpty
                ? null
                : () => context.push('/channel/$channelId'),
            titleAlignment: ListTileTitleAlignment.top,
            dense: false,
            subtitleTextStyle: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.35),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (_isLoading) {
      return Scaffold(
        appBar: GlassAppBar(title: t.channelInvitations),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: GlassAppBar(title: t.channelInvitations),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? ''),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadInvitations,
                child: Text(t.buttonRetry),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.channelInvitations,
        rightDMActions: [
          IconButton(
            onPressed: () => _loadInvitations(showLoading: false),
            icon: const Icon(Icons.refresh),
            tooltip: t.groupList.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: t.myReceivedTab),
                Tab(text: t.mySentTab),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyInvitationsView(),
                _buildInvitationList(
                  invitations: _sentInvitations,
                  isMyInvitations: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyInvitationsView() {
    if (_myInvitations.isEmpty) {
      return _buildInvitationList(
        invitations: _myInvitations,
        isMyInvitations: true,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadInvitations(showLoading: false),
      child: ListView.separated(
        itemCount: _myInvitations.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final invitation = _myInvitations[index];
          final invitationId = parseModelString(
            invitation['id'] ?? invitation['invitation_id'],
          );
          final channelId = parseModelString(invitation['channel_id']);
          final channelName = parseModelString(
            invitation['channel_name'],
            defaultValue: 'Private Channel',
          );
          final status = parseModelInt(invitation['status']);
          final statusText = _statusText(status);
          final statusColor = _statusColor(status);
          final createdAt = parseModelDateTime(invitation['created_at']);
          final inviterUid = parseModelString(invitation['inviter_uid']);
          final isPending = status == 0;
          final isProcessing =
              invitationId.isNotEmpty && _processingIds.contains(invitationId);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          channelName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.inviterLabel(uid: inviterUid.isEmpty ? "-" : inviterUid),
                  ),
                  Text(
                    t.createdAtLabel(
                      time: DateFormat("yyyy-MM-dd HH:mm").format(createdAt),
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isProcessing
                                ? null
                                : () => _handleInvitationAction(
                                    invitation: invitation,
                                    accept: false,
                                  ),
                            child: Text(
                              isProcessing ? t.processingDots : t.reject,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: isProcessing
                                ? null
                                : () => _handleInvitationAction(
                                    invitation: invitation,
                                    accept: true,
                                  ),
                            child: Text(
                              isProcessing ? t.processingDots : t.accept,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (channelId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => context.push('/channel/$channelId'),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(t.openChannel),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
