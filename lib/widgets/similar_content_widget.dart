// ignore_for_file: deprecated_member_use, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/controllers/video_recommendation_controller.dart';
import 'package:trace/helpers/quick_help.dart';

/// Widget que exibe uma lista horizontal de vídeos semelhantes
class SimilarContentWidget extends StatelessWidget {
  final VideoRecommendationController controller;
  final PostsModel currentVideo;
  final Function(PostsModel) onVideoTap;
  final double height;

  const SimilarContentWidget({
    Key? key,
    required this.controller,
    required this.currentVideo,
    required this.onVideoTap,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Buscar vídeos semelhantes quando o widget é construído
    if (!controller.showingSimilarContent.value ||
        controller.currentReferenceVideo?.objectId != currentVideo.objectId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.getSimilarVideos(currentVideo);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Vídeos semelhantes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  // ignore: deprecated_member_use
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const Spacer(),
              Obx(() {
                if (controller.isLoadingSimilar.value) {
                  return SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),

        // Lista de vídeos semelhantes
        SizedBox(
          height: height,
          child: Obx(() {
            if (controller.isLoadingSimilar.value &&
                controller.similarVideos.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (controller.similarVideos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nenhum vídeo semelhante encontrado',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.similarVideos.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final video = controller.similarVideos[index];
                return _buildVideoCard(context, video);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildVideoCard(BuildContext context, PostsModel video) {
    final double cardWidth = 160;
    final String category = _getCategoryFromVideo(video);

    return GestureDetector(
      onTap: () => onVideoTap(video),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: cardWidth,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      image: DecorationImage(
                        image: NetworkImage(video.getVideoThumbnail?.url ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white.withOpacity(0.7),
                        size: 40,
                      ),
                    ),
                  ),

                  // Duração
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "1:30",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Categoria
                  if (category.isNotEmpty)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatCategoryName(category),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Detalhes
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      video.getText ?? "Sem título",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Autor
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundImage: NetworkImage(
                            video.getAuthor?.getAvatar?.url ?? '',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            video.getAuthor?.getFullName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Estatísticas
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(
                          QuickHelp.convertNumberToK(video.getViews),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.favorite, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(
                          QuickHelp.convertNumberToK(video.getLikes.length),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Obter categoria do vídeo (método auxiliar)
  String _getCategoryFromVideo(PostsModel video) {
    String category = "general";

    // Uma lógica semelhante à do controlador para extrair a categoria
    String description = video.getDescription.toLowerCase();

    if (description.contains("música") || description.contains("music")) {
      category = "music";
    } else if (description.contains("comida") || description.contains("food")) {
      category = "food";
    } else if (description.contains("viagem") ||
        description.contains("travel")) {
      category = "travel";
    } else if (description.contains("fitness") ||
        description.contains("workout")) {
      category = "fitness";
    } else if (description.contains("comédia") ||
        description.contains("funny")) {
      category = "comedy";
    }

    return category;
  }

  // Formatar nome da categoria para exibição
  String _formatCategoryName(String category) {
    if (category.isEmpty) return 'Geral';

    // Primeira letra maiúscula, resto minúsculo
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }
}

// Widget para exibir vídeos semelhantes em tela cheia
class SimilarVideosScreen extends StatelessWidget {
  final VideoRecommendationController controller;
  final PostsModel referenceVideo;
  final Function(PostsModel) onVideoTap;

  const SimilarVideosScreen({
    Key? key,
    required this.controller,
    required this.referenceVideo,
    required this.onVideoTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Buscar vídeos semelhantes quando a tela é aberta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.getSimilarVideos(referenceVideo, limit: 20);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conteúdo Semelhante'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                controller.getSimilarVideos(referenceVideo, limit: 20),
            tooltip: 'Atualizar recomendações',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vídeo de referência
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Miniatura
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 60,
                    child: Image.network(
                      referenceVideo.getVideoThumbnail?.url ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Detalhes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vídeos semelhantes a:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        referenceVideo.getText ?? 'Vídeo',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rótulo do conteúdo semelhante
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text(
                  'Você também pode gostar:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Obx(() {
                  if (controller.isLoadingSimilar.value) {
                    return SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  }
                  return Text(
                    '${controller.similarVideos.length} encontrados',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Lista de vídeos semelhantes
          Expanded(
            child: Obx(() {
              if (controller.isLoadingSimilar.value &&
                  controller.similarVideos.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (controller.similarVideos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum vídeo semelhante encontrado',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tente outro vídeo ou atualize as recomendações',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: controller.similarVideos.length,
                itemBuilder: (context, index) {
                  final video = controller.similarVideos[index];
                  return _buildGridVideoCard(context, video);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGridVideoCard(BuildContext context, PostsModel video) {
    final String category = _getCategoryFromVideo(video);

    return GestureDetector(
      onTap: () => onVideoTap(video),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      image: DecorationImage(
                        image: NetworkImage(video.getVideoThumbnail?.url ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white.withOpacity(0.8),
                        size: 48,
                      ),
                    ),
                  ),
                ),

                // Duração
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "1:30",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // Categoria
                if (category.isNotEmpty)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatCategoryName(category),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Detalhes
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      video.getText ?? "Sem título",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Autor
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundImage: NetworkImage(
                            video.getAuthor?.getAvatar?.url ?? '',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            video.getAuthor?.getFullName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Estatísticas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.visibility,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              QuickHelp.convertNumberToK(video.getViews),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.favorite,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              QuickHelp.convertNumberToK(video.getLikes.length),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Obter categoria do vídeo (método auxiliar)
  String _getCategoryFromVideo(PostsModel video) {
    String category = "general";

    // Uma lógica semelhante à do controlador para extrair a categoria
    String description = video.getDescription.toLowerCase();

    if (description.contains("música") || description.contains("music")) {
      category = "music";
    } else if (description.contains("comida") || description.contains("food")) {
      category = "food";
    } else if (description.contains("viagem") ||
        description.contains("travel")) {
      category = "travel";
    } else if (description.contains("fitness") ||
        description.contains("workout")) {
      category = "fitness";
    } else if (description.contains("comédia") ||
        description.contains("funny")) {
      category = "comedy";
    }

    return category;
  }

  // Formatar nome da categoria para exibição
  String _formatCategoryName(String category) {
    if (category.isEmpty) return 'Geral';

    // Primeira letra maiúscula, resto minúsculo
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }
}
