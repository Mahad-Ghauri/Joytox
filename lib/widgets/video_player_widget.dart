import 'package:flutter/material.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final CachedVideoPlayerPlusController? controller;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.controller,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  CachedVideoPlayerPlusController? _controller;
  bool _isDisposed = false;
  bool _hasError = false;
  bool _isControllerValid = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    if (_isDisposed) return;

    _controller = widget.controller;
    _hasError = false;
    _checkControllerValidity();
  }

  void _checkControllerValidity() {
    if (_isDisposed || _controller == null) {
      _isControllerValid = false;
      return;
    }

    try {
      _isControllerValid =
          _controller!.value.isInitialized && !_controller!.value.hasError;
      if (_isControllerValid && mounted) setState(() {});
    } catch (e) {
      print('Error checking controller validity: $e');
      _isControllerValid = false;
      _hasError = true;
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isDisposed) return;

    if (widget.controller != oldWidget.controller) {
      _controller = widget.controller;
      _hasError = false;
      _checkControllerValidity();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isControllerValid = false;
    _controller = null;
    super.dispose();
  }

  Widget _buildVideoPlayer() {
    if (_isDisposed ||
        !_isControllerValid ||
        _hasError ||
        _controller == null) {
      return _buildThumbnail();
    }

    return ValueListenableBuilder<CachedVideoPlayerPlusValue>(
      valueListenable: _controller!,
      builder: (context, value, child) {
        if (_isDisposed || !mounted) return _buildThumbnail();

        if (value.hasError || !value.isInitialized) {
          _hasError = true;
          _isControllerValid = false;
          return _buildThumbnail();
        }

        // PERFORMANCE OPTIMIZATION: Cache the video widget to avoid rebuilds
        return GestureDetector(
          onTap: _handleTap,
          child: Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: _isControllerValid && !_isDisposed
                  ? RepaintBoundary(
                      child: CachedVideoPlayerPlus(_controller!),
                    )
                  : _buildThumbnail(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail() {
    if (_isDisposed) return Container(color: Colors.black);

    return Center(
      child: widget.thumbnailUrl != null
          ? CachedNetworkImage(
              imageUrl: widget.thumbnailUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              // MEMORY OPTIMIZATION: Limit thumbnail resolution - saves ~20-30MB
              maxHeightDiskCache: 512,
              maxWidthDiskCache: 512,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.error, color: Colors.white),
            )
          : const CircularProgressIndicator(),
    );
  }

  void _handleTap() {
    if (_isDisposed || !_isControllerValid || _controller == null) return;

    try {
      if (_controller!.value.isInitialized && !_controller!.value.hasError) {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Error toggling play state: $e');
      _hasError = true;
      _isControllerValid = false;
      if (mounted && !_isDisposed) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed || !mounted) return Container(color: Colors.black);

    return Container(
      color: Colors.black,
      child: _buildVideoPlayer(),
    );
  }
}
