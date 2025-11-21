// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/utils/colors.dart';

import '../../models/UserModel.dart';
import '../../views/reels_interactions.dart';

class GlobalVideoPlayer extends StatefulWidget {
  final PostsModel video;
  final UserModel? currentUser;
  final CachedVideoPlayerPlusController? externalController;
  final bool autoPlay;
  final bool showControls;
  final bool looping;

  const GlobalVideoPlayer({
    required this.video,
    this.currentUser,
    this.externalController,
    this.autoPlay = true,
    this.showControls = true,
    this.looping = true,
    Key? key,
  }) : super(key: key);

  @override
  State<GlobalVideoPlayer> createState() => _GlobalVideoPlayerState();
}

class _GlobalVideoPlayerState extends State<GlobalVideoPlayer> {
  CachedVideoPlayerPlusController? _controller;
  VoidCallback? _controllerListener;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool get _usesExternalController => widget.externalController != null;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (_usesExternalController) {
        _attachExternalController(widget.externalController!);
        return;
      }

      final videoUrl = widget.video.getVideo?.url;
      if (videoUrl == null) {
        throw "URL do vídeo não encontrada";
      }

      _controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(videoUrl),
        invalidateCacheIfOlderThan: const Duration(days: 2),
      );

      await _controller!.initialize();
      await _controller!.setLooping(widget.looping);

      if (widget.autoPlay) {
        await _controller!.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _handleError(e);
    }
  }

  void _attachExternalController(
      CachedVideoPlayerPlusController externalController) {
    _controller = externalController;
    _isInitialized = externalController.value.isInitialized;
    _controllerListener = () {
      if (!mounted) return;
      final initialized = externalController.value.isInitialized;
      if (_isInitialized != initialized) {
        setState(() {
          _isInitialized = initialized;
        });
      } else {
        setState(() {});
      }
    };
    externalController.addListener(_controllerListener!);
  }

  void _handleError(Object e) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = "Error loading video: $e";
      });
    }
    debugPrint("GlobalVideoPlayer error: $e");
  }

  @override
  void didUpdateWidget(GlobalVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldUsesExternal = oldWidget.externalController != null;
    final newUsesExternal = _usesExternalController;
    final videoChanged = oldWidget.video.objectId != widget.video.objectId;
    final controllerChanged =
        oldWidget.externalController != widget.externalController;

    if (videoChanged ||
        oldUsesExternal != newUsesExternal ||
        controllerChanged) {
      _disposeCurrentController();
      _initializePlayer();
    }
  }

  void _disposeCurrentController() {
    if (_controller == null) return;

    if (_usesExternalController) {
      if (_controllerListener != null && widget.externalController != null) {
        widget.externalController!.removeListener(_controllerListener!);
      }
    } else {
      try {
        _controller!.pause();
      } catch (_) {}
      _controller!.dispose();
    }

    _controllerListener = null;
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeCurrentController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              _errorMessage ?? "Error playing video",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return _buildThumbnailPlaceholder();
    }

    final videoSize = _controller!.value.size;

    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        // Player de vídeo com render confiável em tela cheia
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: videoSize.width > 0 ? videoSize.width : 9,
              height: videoSize.height > 0 ? videoSize.height : 16,
              child: CachedVideoPlayerPlus(_controller!),
            ),
          ),
        ),

        if (widget.showControls)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: kPrimaryColor,
                  bufferedColor: Colors.grey.shade600,
                  backgroundColor: Colors.grey.shade800,
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),

        ReelsInteractions(
          postModel: widget.video,
          currentUser: widget.currentUser,
        ),
      ],
    );
  }

  Widget _buildThumbnailPlaceholder() {
    final thumbnailUrl = widget.video.getVideoThumbnail?.url;
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        SizedBox.expand(
          child: thumbnailUrl != null
              ? Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                )
              : Container(color: Colors.black),
        ),
        CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      ],
    );
  }
}

extension GlobalVideoPlayerExtensions on GlobalVideoPlayer {
  static Future<void> pauseAllPlayers(
      List<CachedVideoPlayerPlusController> controllers) async {
    for (final controller in controllers) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          await controller.pause();
        }
      } catch (e) {
        debugPrint('Error pause/play: $e');
      }
    }
  }
}
