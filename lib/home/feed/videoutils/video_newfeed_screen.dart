// ignore_for_file: must_be_immutable

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lottie/lottie.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:trace/home/feed/videoutils/screen_config.dart';
import 'package:trace/home/feed/videoutils/video.dart';
import 'package:trace/home/feed/videoutils/video_item.dart';
import 'package:trace/home/feed/videoutils/video_item_config.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/UserModel.dart';

import '../../../helpers/quick_help.dart';
import 'api.dart';

class VideoNewFeedScreen<V extends VideoInfo> extends StatefulWidget {
  /// Is case you want to keep the screen
  ///
  final bool keepPage;

  /// Screen config
  final ScreenConfig screenConfig;

  ///
  /// Video Item config
  final VideoItemConfig config;

  final VideoNewFeedApi<V> api;

  /// Video ended callback
  ///
  final void Function()? videoEnded;
  final Function(int page, UserModel user, PostsModel post)? pageChanged;

  //final void Function()? pageChanged;

  /// Video Info Customizable
  ///
  final Widget Function(BuildContext context, V v)? customVideoInfoWidget;

  VideoNewFeedScreen({
    this.keepPage = false,
    this.screenConfig = const ScreenConfig(
      backgroundColor: Colors.black,
      loadingWidget: CircularProgressIndicator(),
    ),

    /// video config
    this.config = const VideoItemConfig(
        loop: true,
        itemLoadingWidget: CircularProgressIndicator(),
        autoPlayNextVideo: true),
    this.customVideoInfoWidget,
    this.videoEnded,
    this.pageChanged,
    required this.api,
  });

  @override
  State<StatefulWidget> createState() => _VideoNewFeedScreenState<V>();
}

class _VideoNewFeedScreenState<V extends VideoInfo>
    extends State<VideoNewFeedScreen<V>> {
  /// PageController
  ///
  //late PageController _pageController;

  late PreloadPageController _pageController;

  /// Current page is on screen
  ///
  int _currentPage = 0;

  /// Page is on turning or off, use to check how much percent the next video will render and play
  ///
  bool _isOnPageTurning = false;

  final _listVideoStream = StreamController<List<V>>();

  /// Temp to update list video data
  ///
  List<V> temps = [];

  void setList(List<V> items) {
    if (!_listVideoStream.isClosed) {
      _listVideoStream.sink.add(items);
    }
  }

  void _notifyDataChanged() => setList(temps);

  /// Check to play next video when user scroll
  /// If the next video appear about 30% (0.7) the next video will play
  ///
  void _scrollListener() {
    if (_isOnPageTurning &&
        _pageController.page == _pageController.page!.roundToDouble()) {
      setState(() {
        _currentPage = _pageController.page!.toInt();
        _isOnPageTurning = false;
      });
    } else if (!_isOnPageTurning &&
        _currentPage.toDouble() != _pageController.page) {
      if ((_currentPage.toDouble() - _pageController.page!).abs() > 0.7) {
        setState(() {
          _isOnPageTurning = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PreloadPageController(keepPage: widget.keepPage);
    //_pageController = PageController(keepPage: widget.keepPage);
    _pageController.addListener(_scrollListener);

    _getListVideo();
  }

  void _getListVideo() {
    widget.api.getListVideo().then((value) {
      temps.addAll(value);
      _notifyDataChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.screenConfig.backgroundColor,
      body: _renderVideoPageView(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _listVideoStream.close();
    super.dispose();
  }

  /// Page View
  ///
  Widget _renderVideoPageView() {
    return StreamBuilder<List<VideoInfo>>(
        stream: _listVideoStream.stream,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: QuickHelp.showLoadingAnimation(),
              );
            default:
              if (snapshot.hasData) {
                if (snapshot.data!.isEmpty) {
                  return Center(
                    child: widget.screenConfig.emptyWidget ??
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset("assets/no_result.json"),
                            Text("No result.")
                          ],
                        ),
                  );
                } else {
                  /*return PageView.builder(
                    scrollDirection: Axis.vertical,
                    controller: _pageController,
                    itemCount: snapshot.data!.length,
                    onPageChanged: (page) {
                      UserModel? user = snapshot.data![page].currentUser;
                      PostsModel? post = snapshot.data![page].postModel;

                      if (widget.pageChanged != null && user != null) {
                        widget.pageChanged!(page, user, post!) as void
                            Function()?;
                      }
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return VideoItemWidget(
                        videoInfo: snapshot.data![index],
                        pageIndex: index,
                        currentPageIndex: _currentPage,
                        preferences: widget.preferences,
                        isPaused: _isOnPageTurning,
                        config: widget.config,
                        videoEnded: widget.videoEnded,
                        customVideoInfoWidget:
                            widget.customVideoInfoWidget != null
                                ? widget.customVideoInfoWidget!(
                                    context, temps[index])
                                : null,
                      );
                    },
                  );*/

                  return PreloadPageView.builder(
                    scrollDirection: Axis.vertical,
                    controller: _pageController,
                    itemCount: snapshot.data!.length,
                    preloadPagesCount: 5,
                    pageSnapping: true,
                    onPageChanged: (page) {
                      UserModel? user = snapshot.data![page].currentUser;
                      PostsModel? post = snapshot.data![page].postModel;

                      if (widget.pageChanged != null && user != null) {
                        widget.pageChanged!(page, user, post!) as void Function()?;
                      }
                    },
                    itemBuilder: (context, index) {
                      return VideoItemWidget(
                        videoInfo: snapshot.data![index],
                        pageIndex: index,
                        currentPageIndex: _currentPage,
                        isPaused: _isOnPageTurning,
                        config: widget.config,
                        videoEnded: widget.videoEnded,
                        customVideoInfoWidget: widget.customVideoInfoWidget != null
                            ? widget.customVideoInfoWidget!(context, temps[index])
                            : null,
                      );
                    },
                  );
                }
              } else {
                return Center(
                  child: widget.screenConfig.emptyWidget ??
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset("assets/no_result.json"),
                          Text("No result.")
                        ],
                      ),
                );
              }
          }
        });
  }
}
