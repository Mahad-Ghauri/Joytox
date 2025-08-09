// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ml_recommendation_controller.dart';
import '../models/PostsModel.dart';
import '../extensions/parse_file_extensions.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MLRecommendationsWidget extends StatelessWidget {
  final PostsModel currentVideo;
  final Function(PostsModel) onVideoTap;
  final double height;

  const MLRecommendationsWidget({
    Key? key,
    required this.currentVideo,
    required this.onVideoTap,
    this.height = 220,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MLRecommendationController>(
      builder: (controller) {
        if (controller.isLoading.value) {
          return SizedBox(
            height: height,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (controller.recommendedVideos.isEmpty) {
          return SizedBox(
            height: height,
            child: const Center(
              child: Text(
                'Carregando recomendações...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Recomendados para você',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: controller.recommendedVideos.length,
                  itemBuilder: (context, index) {
                    final video = controller.recommendedVideos[index];
                    return _buildVideoCard(video, onVideoTap);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoCard(PostsModel video, Function(PostsModel) onTap) {
    final thumbnailUrl = video.getVideo?.thumbnailUrl;
    final duration = video.getVideo?.duration?.inSeconds ?? 0;
    final views = video.getViews;
    final likes = video.getLikes.length;

    return GestureDetector(
      onTap: () => onTap(video),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  if (thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),

                  // Duração
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Informações
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    video.getDescription.isNotEmpty
                        ? video.getDescription
                        : 'Sem descrição',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Estatísticas
                  Row(
                    children: [
                      _buildStatItem(Icons.remove_red_eye, views),
                      const SizedBox(width: 12),
                      _buildStatItem(Icons.favorite, likes),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
