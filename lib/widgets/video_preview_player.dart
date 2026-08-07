import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewPlayer extends StatefulWidget {
  final String videoPath;
  final bool isAsset;
  final double height;
  final double width;

  const VideoPreviewPlayer({
    super.key,
    required this.videoPath,
    this.isAsset = true,
    this.height = 250,
    this.width = double.infinity,
  });

  @override
  State<VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<VideoPreviewPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final cleanPath = widget.videoPath.trim();
    if (cleanPath.isEmpty) {
      setState(() => _errorMessage = "Video path is empty");
      return;
    }

    try {
      if (cleanPath.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(cleanPath));
      } else if (cleanPath.startsWith('assets/') || widget.isAsset) {
        _controller = VideoPlayerController.asset(cleanPath);
      } else {
        _controller = VideoPlayerController.file(File(cleanPath));
      }

      _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _errorMessage = null;
          });
          _controller!.setLooping(true);
          _controller!.setVolume(0);
          _controller!.play();
        }
      }).catchError((error) {
        debugPrint("Video initialization failed: $error");
        if (mounted) {
          setState(() {
            _isInitialized = false;
            _errorMessage = error.toString();
          });
        }
      });
    } catch (e) {
      debugPrint("Error creating VideoPlayerController: $e");
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void didUpdateWidget(VideoPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _errorMessage = null;
      _initializeController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoPath.trim().isEmpty || _errorMessage != null) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _errorMessage != null ? Icons.error_outline : Icons.videocam_off_outlined,
              color: Colors.red[300],
              size: 40,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _errorMessage ?? "Video path is empty",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[300], fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_controller == null || !_isInitialized) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_collection_outlined, color: Colors.grey[400], size: 40),
            const SizedBox(height: 8),
            const Text(
              "Video loading...",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Icon(
                  _controller!.value.isPlaying ? null : Icons.play_arrow,
                  size: 50,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
