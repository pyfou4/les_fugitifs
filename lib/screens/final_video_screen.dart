import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FinalVideoScreen extends StatefulWidget {
  final String videoUrl;

  const FinalVideoScreen({
    super.key,
    required this.videoUrl,
  });

  @override
  State<FinalVideoScreen> createState() => _FinalVideoScreenState();
}

class _FinalVideoScreenState extends State<FinalVideoScreen> {
  late VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isReady = true;
        });

        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isReady
          ? GestureDetector(
        onTap: () {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
          setState(() {});
        },
        child: Center(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        ),
      )
          : const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}