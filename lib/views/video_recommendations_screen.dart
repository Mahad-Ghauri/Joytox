// ignore_for_file: unused_element, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/controllers/video_recommendation_controller.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/widgets/category_filter_widget.dart';
import 'package:trace/helpers/quick_help.dart';

class VideoRecommendationsScreen extends StatefulWidget {
  final UserModel currentUser;

  const VideoRecommendationsScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  _VideoRecommendationsScreenState createState() =>
      _VideoRecommendationsScreenState();
}

class _VideoRecommendationsScreenState
    extends State<VideoRecommendationsScreen> {
  late VideoRecommendationController controller;
  final RxBool _showFilterDialog = false.obs;

  @override
  void initState() {
    super.initState();

    // Inicializar o controlador de recomendações
    VideoRecommendationController.initializeIfNeeded(widget.currentUser);
    controller = Get.find<VideoRecommendationController>();

    // Carregar recomendações iniciais
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadRecommendedVideos(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Para Você'),
        actions: [
          Obx(() => Badge(
                isLabelVisible: controller.filtersEnabled.value,
                child: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterDialog.value = true,
                  tooltip: 'Filtrar por categoria',
                ),
              )),
        ],
      ),
      body: Column(
        children: [
          // Barra de categorias horizontal
          CategoryFilterWidget(
            controller: controller,
            height: 60,
            onFiltersChanged: () {
              // Opcional: fazer algo quando os filtros mudam
              setState(() {});
            },
          ),

          // Lista de vídeos recomendados
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.recommendedVideos.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (controller.recommendedVideos.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () => controller.loadRecommendedVideos(reset: true),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: ListView.builder(
                    itemCount: controller.recommendedVideos.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final video = controller.recommendedVideos[index];
                      return _buildVideoCard(context, video);
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),

      // Dialog para filtros em tela cheia
      bottomSheet: Obx(() {
        if (!_showFilterDialog.value) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            minHeight: MediaQuery.of(context).size.height * 0.3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Filtrar Vídeos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _showFilterDialog.value = false,
                    ),
                  ],
                ),
              ),

              // Conteúdo principal
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: CategoryGridWidget(
                    controller: controller,
                    onFiltersChanged: () {
                      // Após um filtro ser aplicado, esperar um pouco e depois fechar o diálogo
                      Future.delayed(const Duration(milliseconds: 400), () {
                        _showFilterDialog.value = false;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // Detectar quando chegou ao final da lista para carregar mais
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      if (notification.metrics.pixels >=
          notification.metrics.maxScrollExtent - 400) {
        // Carregar próxima página quando chegar perto do final
        if (!controller.isLoading.value) {
          controller.loadRecommendedVideos(reset: false);
        }
      }
    }
    return false;
  }

  // Conteúdo quando não há vídeos
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              controller.filtersEnabled.value
                  ? 'Nenhum vídeo encontrado com os filtros selecionados'
                  : 'Nenhuma recomendação disponível',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              controller.filtersEnabled.value
                  ? 'Tente remover alguns filtros ou selecionar outras categorias'
                  : 'Assista mais vídeos para recebermos mais informações sobre seus interesses',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              onPressed: () {
                if (controller.filtersEnabled.value) {
                  controller.clearAllFilters();
                } else {
                  controller.loadRecommendedVideos(reset: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Card para exibir um vídeo
  Widget _buildVideoCard(BuildContext context, PostsModel video) {
    final double cardHeight = MediaQuery.of(context).size.width * 0.6;
    final String category = _getCategoryFromVideo(video);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Miniatura do vídeo
          Stack(
            children: [
              // Miniatura
              Container(
                height: cardHeight,
                width: double.infinity,
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
                    size: 64,
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
                    "1:30", // Valor fixo simplificado para duração
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              // Tag de categoria
              if (category.isNotEmpty)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // Informações do vídeo
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Text(
                  video.getText ?? "Sem título",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Autor e estatísticas
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(
                        video.getAuthor?.getAvatar?.url ?? '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        video.getAuthor?.getFullName ?? '',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Estatísticas
                    Row(
                      children: [
                        const Icon(Icons.visibility,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          QuickHelp.convertNumberToK(video.getViews),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.favorite,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          QuickHelp.convertNumberToK(video.getLikes.length),
                          style: TextStyle(
                            color: Colors.grey[700],
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
        ],
      ),
    );
  }

  // Formatar categoria para exibição
  String _formatCategoryName(String category) {
    if (category.isEmpty) return 'Geral';

    // Primeira letra maiúscula, resto minúsculo
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }

  // Formatar duração do vídeo
  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    final int minutes = duration.inMinutes;
    final int remainingSeconds = duration.inSeconds - (minutes * 60);

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Obter categoria do vídeo (método auxiliar)
  String _getCategoryFromVideo(PostsModel video) {
    String category = "general";

    // Uma lógica semelhante à do controlador para extrair a categoria
    String description = video.getText?.toLowerCase() ?? '';

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
}
