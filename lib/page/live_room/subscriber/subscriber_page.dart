import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/live_room/subscriber/subscriber_provider.dart'
    show subscriberProvider;

/// WHIP Subscribe 示例页面
class SubscriberPage extends ConsumerStatefulWidget {
  const SubscriberPage({super.key});

  @override
  ConsumerState<SubscriberPage> createState() => _SubscriberPageState();
}

class _SubscriberPageState extends ConsumerState<SubscriberPage> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TextEditingController _serverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriberProvider);

    // 更新控制器文本
    if (_serverController.text != state.serverUrl) {
      _serverController.text = state.serverUrl;
    }

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: const Text('WHIP Subscribe Sample'),
        rightDMActions: const [],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Column(
            children: <Widget>[
              Column(
                children: <Widget>[
                  FittedBox(
                    child: Text(state.stateStr, textAlign: TextAlign.left),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
