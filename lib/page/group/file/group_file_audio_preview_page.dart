import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:just_audio/just_audio.dart';

class GroupFileAudioPreviewPage extends StatefulWidget {
  const GroupFileAudioPreviewPage({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<GroupFileAudioPreviewPage> createState() =>
      _GroupFileAudioPreviewPageState();
}

class _GroupFileAudioPreviewPageState extends State<GroupFileAudioPreviewPage> {
  late final AudioPlayer _player;
  bool _isPreparing = true;
  String? _errorText;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _bindPlayerListeners();
    _initPlayer();
  }

  void _bindPlayerListeners() {
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
    });

    _player.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() {
        _duration = duration;
      });
    });

    _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.url);
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _errorText = t.common.groupFileAudioLoadFailed;
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_isPreparing || _errorText != null) return;
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    await _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds;
    final positionMs = _position.inMilliseconds.clamp(0, maxMs);

    return Scaffold(
      appBar: GlassAppBar(title: widget.title, automaticallyImplyLeading: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.audiotrack, size: 56),
              const SizedBox(height: 16),
              if (_isPreparing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(t.common.groupFileAudioLoading),
              ] else if (_errorText != null) ...[
                Text(_errorText!),
              ] else ...[
                Slider(
                  value: positionMs.toDouble(),
                  max: maxMs.toDouble(),
                  onChanged: (value) =>
                      _player.seek(Duration(milliseconds: value.toInt())),
                ),
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _togglePlay,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    _isPlaying
                        ? t.chat.groupFileMediaPause
                        : t.chat.groupFileMediaPlay,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
