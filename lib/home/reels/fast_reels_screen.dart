import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/services/posts_service.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FastReelsScreen extends StatefulWidget {
  @override
  _FastReelsScreenState createState() => _FastReelsScreenState();
}

class _FastReelsScreenState extends State<FastReelsScreen> {
  List<PostsModel> _videos = [];
  int _currentVideoIndex = 0;
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  String? _errorMessage;
  late PostsService _postsService;

  @override
  void initState() {
    super.initState();
    // Ensure PostsService is available
    if (!Get.isRegistered<PostsService>()) {
      Get.put(PostsService(), permanent: true);
    }
    _postsService = Get.find<PostsService>();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final videos = await _postsService.loadInitialVideos();
      if (videos.isNotEmpty) {
        setState(() {
          _videos = videos;
        });
        _loadVideo(_currentVideoIndex);
      } else {
        setState(() {
          _isLoading = false;
          _videos = [];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load reels';
      });
    }
  }

  void _loadVideo(int index) {
    if (_videoController != null) {
      _videoController!.dispose();
    }

    final videoUrl = _videos[index].getVideo?.url;
    if (videoUrl == null || videoUrl.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isLoading = false;
          _videoController!.play();
        });
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _onVideoChanged(int index) {
    setState(() {
      _currentVideoIndex = index;
      _isLoading = true;
      _loadVideo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : (_videos.isEmpty
              ? Center(
                  child: Text(_errorMessage ?? 'No reels available'),
                )
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  onPageChanged: _onVideoChanged,
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    final thumbnailUrl = video.getVideoThumbnail?.url;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isLoading)
                          CachedNetworkImage(
                            imageUrl: thumbnailUrl ?? '',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        if (!_isLoading &&
                            _videoController!.value.isInitialized)
                          AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                      ],
                    );
                  },
                )),
    );
  }
}
