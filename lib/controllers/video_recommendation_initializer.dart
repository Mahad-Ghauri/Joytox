import 'package:get/get.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/controllers/video_recommendation_controller.dart';
import 'package:trace/controllers/reels_controller.dart';

/// Responsável por inicializar e configurar o sistema de recomendação de vídeos
class VideoRecommendationInitializer {
  /// Registra o controlador de recomendação para um usuário específico
  static void initializeForUser(UserModel user) {
    // Verificar se já existe um controlador registrado
    if (Get.isRegistered<VideoRecommendationController>()) {
      // Verificar se o usuário é o mesmo
      final controller = Get.find<VideoRecommendationController>();
      if (controller.currentUser.objectId == user.objectId) {
        // Se o usuário é o mesmo, não precisa reinicializar
        return;
      } else {
        // Se o usuário é diferente, remove o controlador existente
        Get.delete<VideoRecommendationController>();
      }
    }

    // Registrar o controlador para o usuário atual
    Get.put(VideoRecommendationController(currentUser: user));

    print(
        'Sistema de recomendação de vídeos inicializado para o usuário: ${user.objectId}');
  }

  /// Monitora um controlador de Reels para coletar interações de vídeo
  static void monitorReelsController(ReelsController reelsController) {
    if (!Get.isRegistered<VideoRecommendationController>()) {
      print(
          'O sistema de recomendação não está inicializado. Não é possível monitorar as interações.');
      return;
    }

    // Adicionar um listener para o currentVideoIndex
    ever(reelsController.currentVideoIndex, (int index) {
      // Verificar se há vídeos disponíveis e se o índice é válido
      if (reelsController.videos.isEmpty ||
          index >= reelsController.videos.length ||
          index < 0) {
        return;
      }

      // Obter o vídeo atual
      final currentVideo = reelsController.videos[index];
      print('Monitorando interações para o vídeo: ${currentVideo.objectId}');

      // Se houver um controlador de vídeo, configurar observadores
      reelsController.getControllerForIndex(index).then((videoController) {
        if (videoController != null && videoController.value.isInitialized) {
          // Configurar um timer para registrar o progresso a cada 5 segundos
          Future.delayed(Duration(seconds: 5), () {
            _recordVideoProgress(reelsController, index, videoController);
          });
        }
      });
    });
  }

  /// Registra o progresso de visualização de um vídeo
  static void _recordVideoProgress(ReelsController reelsController,
      int videoIndex, dynamic videoController) {
    // Verificar se o vídeo ainda é o mesmo
    if (reelsController.currentVideoIndex.value != videoIndex ||
        !Get.isRegistered<VideoRecommendationController>()) {
      return;
    }

    // Verificar se o controlador de vídeo está inicializado
    if (videoController == null || !videoController.value.isInitialized) {
      return;
    }

    final recommendationController = Get.find<VideoRecommendationController>();
    final currentVideo = reelsController.videos[videoIndex];

    // Calcular o percentual assistido
    final duration = videoController.value.duration.inSeconds;
    final position = videoController.value.position.inSeconds;

    if (duration > 0) {
      final watchPercentage = position / duration;

      // Registrar a interação
      recommendationController.recordInteraction(
        video: currentVideo,
        user: recommendationController.currentUser,
        watchPercentage: watchPercentage,
        watchTimeSeconds: position,
      );

      // Se o vídeo ainda está sendo reproduzido, continuar monitorando
      if (videoController.value.isPlaying) {
        Future.delayed(Duration(seconds: 5), () {
          _recordVideoProgress(reelsController, videoIndex, videoController);
        });
      }
    }
  }

  /// Registra uma interação de curtida com o vídeo atual
  static void recordLikeInteraction(int videoIndex, bool liked) {
    if (!Get.isRegistered<VideoRecommendationController>() ||
        !Get.isRegistered<ReelsController>()) {
      return;
    }

    final reelsController = Get.find<ReelsController>();

    // Verificar se o índice é válido
    if (reelsController.videos.isEmpty ||
        videoIndex >= reelsController.videos.length ||
        videoIndex < 0) {
      return;
    }

    final recommendationController = Get.find<VideoRecommendationController>();
    final video = reelsController.videos[videoIndex];

    // Registrar a interação de curtida
    recommendationController.recordInteraction(
      video: video,
      user: recommendationController.currentUser,
      watchPercentage: 0,
      watchTimeSeconds: 0,
      liked: liked,
    );
  }

  /// Registra uma interação de compartilhamento com o vídeo atual
  static void recordShareInteraction(int videoIndex) {
    if (!Get.isRegistered<VideoRecommendationController>() ||
        !Get.isRegistered<ReelsController>()) {
      return;
    }

    final reelsController = Get.find<ReelsController>();

    // Verificar se o índice é válido
    if (reelsController.videos.isEmpty ||
        videoIndex >= reelsController.videos.length ||
        videoIndex < 0) {
      return;
    }

    final recommendationController = Get.find<VideoRecommendationController>();
    final video = reelsController.videos[videoIndex];

    // Registrar a interação de compartilhamento
    recommendationController.recordInteraction(
      video: video,
      user: recommendationController.currentUser,
      watchPercentage: 0,
      watchTimeSeconds: 0,
      shared: true,
    );
  }

  /// Registra uma interação de comentário com o vídeo atual
  static void recordCommentInteraction(int videoIndex) {
    if (!Get.isRegistered<VideoRecommendationController>() ||
        !Get.isRegistered<ReelsController>()) {
      return;
    }

    final reelsController = Get.find<ReelsController>();

    // Verificar se o índice é válido
    if (reelsController.videos.isEmpty ||
        videoIndex >= reelsController.videos.length ||
        videoIndex < 0) {
      return;
    }

    final recommendationController = Get.find<VideoRecommendationController>();
    final video = reelsController.videos[videoIndex];

    // Registrar a interação de comentário
    recommendationController.recordInteraction(
      video: video,
      user: recommendationController.currentUser,
      watchPercentage: 0,
      watchTimeSeconds: 0,
      commented: true,
    );
  }

  /// Registra uma interação de salvar com o vídeo atual
  static void recordSaveInteraction(int videoIndex, bool saved) {
    if (!Get.isRegistered<VideoRecommendationController>() ||
        !Get.isRegistered<ReelsController>()) {
      return;
    }

    final reelsController = Get.find<ReelsController>();

    // Verificar se o índice é válido
    if (reelsController.videos.isEmpty ||
        videoIndex >= reelsController.videos.length ||
        videoIndex < 0) {
      return;
    }

    final recommendationController = Get.find<VideoRecommendationController>();
    final video = reelsController.videos[videoIndex];

    // Registrar a interação de salvar
    recommendationController.recordInteraction(
      video: video,
      user: recommendationController.currentUser,
      watchPercentage: 0,
      watchTimeSeconds: 0,
      saved: saved,
    );
  }

  /// Registra feedback negativo explícito para um vídeo específico
  static void recordNegativeFeedback(int videoIndex) {
    // Verificar se os controladores necessários estão disponíveis
    if (!Get.isRegistered<VideoRecommendationController>() ||
        !Get.isRegistered<ReelsController>()) {
      print(
          'VideoRecommendationInitializer: Controladores necessários não registrados');
      return;
    }

    final reelsController = Get.find<ReelsController>();

    // Verificar se o índice é válido
    if (reelsController.videos.isEmpty ||
        videoIndex >= reelsController.videos.length ||
        videoIndex < 0) {
      print('VideoRecommendationInitializer: Índice de vídeo inválido');
      return;
    }

    final recommendationController = Get.find<VideoRecommendationController>();
    final video = reelsController.videos[videoIndex];

    // Registrar feedback negativo
    recommendationController.recordInteraction(
      video: video,
      user: recommendationController.currentUser,
      watchPercentage: 0.0,
      watchTimeSeconds: 0,
    );

    // Registrar no sistema de recomendação
    recommendationController.recordNegativeFeedback(video);

    print(
        'VideoRecommendationInitializer: Feedback negativo registrado para o vídeo ${video.objectId}');
  }
}
