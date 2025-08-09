import 'package:flutter/material.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/UserModel.dart';

class VideoInteractionsWidget extends StatelessWidget {
  final PostsModel video;
  final UserModel? currentUser;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onDownload;
  final VoidCallback onStats;

  const VideoInteractionsWidget({
    Key? key,
    required this.video,
    required this.currentUser,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onDownload,
    required this.onStats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInteractionButton(
          icon: Icons.favorite,
          label: video.getLikes.length.toString(),
          onTap: onLike,
          isActive: video.isLiked(currentUser?.objectId),
          activeColor: Colors.red,
        ),
        const SizedBox(height: 20),
        _buildInteractionButton(
          icon: Icons.comment,
          label: video.getComments.length.toString(),
          onTap: onComment,
        ),
        const SizedBox(height: 20),
        _buildInteractionButton(
          icon: Icons.bookmark,
          label: video.getSaves.length.toString(),
          onTap: onSave,
          isActive: video.isSaved(currentUser?.objectId),
        ),
        const SizedBox(height: 20),
        _buildInteractionButton(
          icon: Icons.download,
          label: video.getDownloads.toString(),
          onTap: onDownload,
        ),
        const SizedBox(height: 20),
        _buildInteractionButton(
          icon: Icons.bar_chart,
          label: video.getViews.toString(),
          onTap: onStats,
        ),
      ],
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color activeColor = Colors.white,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: isActive ? activeColor : Colors.white,
            size: 30,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
