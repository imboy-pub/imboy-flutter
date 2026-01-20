import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/live_room/publisher/publisher_provider.dart'
    show publisherProvider;

/// WHIP Publisher 示例页面
class PublisherPage extends ConsumerStatefulWidget {
  const PublisherPage({super.key});

  @override
  ConsumerState<PublisherPage> createState() => _PublisherPageState();
}

class _PublisherPageState extends ConsumerState<PublisherPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final TextEditingController _serverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  @override
  void dispose() {
    _serverController.dispose();
    if (_localRenderer.textureId != null) {
      _localRenderer.srcObject = null;
      _localRenderer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publisherProvider);

    // 更新控制器文本
    if (_serverController.text != state.serverUrl) {
      _serverController.text = state.serverUrl;
    }

    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: const Text('WHIP Publisher Sample'),
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
