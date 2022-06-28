import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:imboy/component/voice_record/voice_animation.dart';

///方向
enum BubbleDirection { left, right }

class AudioMessageBuilder extends StatefulWidget {
  const AudioMessageBuilder({
    Key? key,
    required this.user,
    required this.message,
  }) : super(key: key);

  final types.User user;

  /// [types.CustomMessage]
  final types.CustomMessage message;

  @override
  _AudioMessageBuilderState createState() => _AudioMessageBuilderState();
}

class _AudioMessageBuilderState extends State<AudioMessageBuilder> {
  final _audioPlayer = FlutterSoundPlayer();

  bool _playing = false;
  bool _audioPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  @override
  Future<void> dispose() async {
    // await _audioPlayer.closeAudioSession();
    await _audioPlayer.closePlayer();
    super.dispose();
  }

  Future<void> _initAudioPlayer() async {
    // await _audioPlayer.openAudioSession();
    await _audioPlayer.openPlayer();
    setState(() {
      _audioPlayerReady = true;
    });
  }

  Future<void> _togglePlaying() async {
    if (!_audioPlayerReady) {
      return;
    }
    if (_playing) {
      await _audioPlayer.pausePlayer();
      setState(() {
        _playing = false;
      });
    } else if (_audioPlayer.isPaused) {
      await _audioPlayer.resumePlayer();
      setState(() {
        _playing = true;
      });
    } else {
      await _audioPlayer.setSubscriptionDuration(
        const Duration(milliseconds: 10),
      );
      await _audioPlayer.startPlayer(
          fromURI: widget.message.metadata!['uri'],
          whenFinished: () {
            setState(() {
              _playing = false;
            });
          });
      setState(() {
        _playing = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = widget.user.id == widget.message.author.id;

    double duration_s = widget.message.metadata!["duration_ms"] / 1000;
    return InkWell(
      onTap: () {
        _togglePlaying();
      },
      onDoubleTap: () {
        // _togglePlaying();
      },
      child: Container(
        height: 44,
        width: 120,
        child: userIsAuthor
            ? Row(
                // sneder
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    duration_s.toString() + "''",
                    style: const TextStyle(fontSize: 16),
                  ),
                  RotatedBox(
                    quarterTurns: 2, // 0 revicer 2 sneder;
                    child: VoiceAnimation(
                      width: 40,
                      height: 32,
                      isStop: _playing,
                      userIsAuthor: userIsAuthor,
                    ),
                  ),
                ],
              )
            : Row(
                // revicer
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  VoiceAnimation(
                    width: 40,
                    height: 32,
                    isStop: _playing,
                    userIsAuthor: userIsAuthor,
                  ),
                  Text(
                    duration_s.toString() + "''",
                    style: const TextStyle(fontSize: 16),
                  ),
                  Badge(
                    showBadge: true,
                    shape: BadgeShape.circle,
                    borderRadius: BorderRadius.circular(8),
                    // position: BadgePosition.topStart(top: -4, start: 20),
                    padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
                  ),
                ],
              ),
      ),
    );
  }
}
