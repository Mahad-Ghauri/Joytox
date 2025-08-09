// ignore_for_file: unused_field, unused_element, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/widgets/feed_post_widget.dart';

class OptimizedFeedPost extends StatefulWidget {
  final PostsModel post;
  final UserModel currentUser;
  final Function(PostsModel) onPostTap;
  final Function(UserModel, PostsModel) onOptionsPressed;
  final Function(PostsModel) onCommentsTap;

  const OptimizedFeedPost({
    Key? key,
    required this.post,
    required this.currentUser,
    required this.onPostTap,
    required this.onOptionsPressed,
    required this.onCommentsTap,
  }) : super(key: key);

  @override
  State<OptimizedFeedPost> createState() => _OptimizedFeedPostState();
}

class _OptimizedFeedPostState extends State<OptimizedFeedPost>
    with AutomaticKeepAliveClientMixin {
  bool _isLoaded = false;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  void _loadPost() {
    setState(() {
      _isLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildPostContent();
  }

  Widget _buildPostContent() {
    try {
      if (!_isLoaded) {
        return _buildLoadingPlaceholder();
      }

      if (widget.post.getAuthor == null) {
        return _buildLoadingPlaceholder();
      }

      return FeedPostWidget(
        post: widget.post,
        currentUser: widget.currentUser,
        onPostTap: widget.onPostTap,
        onOptionsPressed: widget.onOptionsPressed,
        onCommentsTap: widget.onCommentsTap,
      );
    } catch (e) {
      print("Erro ao renderizar post ${widget.post.objectId}: $e");
      return _buildLoadingPlaceholder();
    }
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 300,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: 100,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Erro ao carregar este post"),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  _errorMessage,
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
