import 'package:get/get.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/VideoInteractionModel.dart';
import '../extensions/parse_file_extensions.dart';
import 'dart:math' as math;
import 'dart:async';

class MLRecommendationController extends GetxController {
  static MLRecommendationController get to => Get.find();

  // Inicialização segura
  static void initializeIfNeeded(UserModel currentUser) {
    try {
      if (Get.isRegistered<MLRecommendationController>()) {
        final controller = Get.find<MLRecommendationController>();
        if (controller.currentUser.objectId == currentUser.objectId) {
          return;
        }
        Get.delete<MLRecommendationController>();
      }

      Get.put<MLRecommendationController>(
        MLRecommendationController(currentUser: currentUser),
        permanent: true,
      );
      print(
          'Sistema ML de recomendação inicializado para: ${currentUser.getFullName}');
    } catch (e) {
      print('Erro ao inicializar ML Recommendation: $e');
    }
  }

  final UserModel currentUser;

  // Estado observável
  final RxList<PostsModel> recommendedVideos = <PostsModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMoreRecommendations = true.obs;

  // Features para ML
  final RxMap<String, double> userFeatures = <String, double>{}.obs;
  final RxMap<String, double> videoFeatures = <String, double>{}.obs;

  // Cache de embeddings
  final Map<String, List<double>> _videoEmbeddings = {};
  final Map<String, List<double>> _userEmbeddings = {};

  // Configurações do modelo
  final int embeddingSize = 64;
  final double learningRate = 0.01;
  final int batchSize = 32;
  final int epochs = 10;

  // Histórico de treinamento
  final RxList<double> trainingLoss = <double>[].obs;
  final RxBool isTraining = false.obs;

  // Cache de recomendações
  final Map<String, List<PostsModel>> _recommendationCache = {};

  MLRecommendationController({required this.currentUser});

  @override
  void onInit() {
    super.onInit();
    _initializeFeatures();
    _loadUserEmbedding();
  }

  // Inicializar features do usuário
  Future<void> _initializeFeatures() async {
    try {
      // Carregar histórico de interações
      final interactions = await _loadUserInteractions();

      // Calcular features do usuário
      _calculateUserFeatures(interactions);

      // Treinar modelo se necessário
      if (interactions.length >= batchSize) {
        await _trainModel(interactions);
      }
    } catch (e) {
      print('Erro ao inicializar features: $e');
    }
  }

  // Carregar interações do usuário
  Future<List<VideoInteractionModel>> _loadUserInteractions() async {
    final query = QueryBuilder<VideoInteractionModel>(VideoInteractionModel())
      ..whereEqualTo(VideoInteractionModel.keyUserId, currentUser.objectId)
      ..orderByDescending(VideoInteractionModel.keyUpdatedAt)
      ..setLimit(1000);

    final response = await query.query();
    return response.results?.cast<VideoInteractionModel>() ?? [];
  }

  // Calcular features do usuário
  void _calculateUserFeatures(List<VideoInteractionModel> interactions) {
    // Features baseadas em comportamento
    double avgWatchTime = 0;
    double completionRate = 0;
    double engagementRate = 0;
    double skipRate = 0;

    int totalVideos = interactions.length;
    if (totalVideos > 0) {
      for (var interaction in interactions) {
        avgWatchTime += interaction.getWatchTimeSeconds;
        if (interaction.getWatchPercentage >= 0.7) completionRate++;
        if (interaction.getLiked || interaction.getSaved) engagementRate++;
        if (interaction.getSkipped) skipRate++;
      }

      avgWatchTime /= totalVideos;
      completionRate /= totalVideos;
      engagementRate /= totalVideos;
      skipRate /= totalVideos;
    }

    // Atualizar features do usuário
    userFeatures.value = {
      'avgWatchTime': avgWatchTime,
      'completionRate': completionRate,
      'engagementRate': engagementRate,
      'skipRate': skipRate,
      'totalInteractions': totalVideos.toDouble(),
    };
  }

  // Gerar embedding para um vídeo
  Future<List<double>> _generateVideoEmbedding(PostsModel video) async {
    if (_videoEmbeddings.containsKey(video.objectId)) {
      return _videoEmbeddings[video.objectId]!;
    }

    // Features do vídeo
    final features = [
      video.getLikes.length.toDouble(),
      video.getComments.length.toDouble(),
      video.getViews.toDouble(),
      video.getDescription.length.toDouble(),
      video.getVideo?.duration?.inSeconds.toDouble() ?? 0,
    ];

    // Normalizar features
    final normalizedFeatures = _normalizeFeatures(features);

    // Gerar embedding usando uma rede neural simples
    final embedding = List<double>.generate(embeddingSize, (i) {
      double sum = 0;
      for (int j = 0; j < features.length; j++) {
        sum += normalizedFeatures[j] * math.Random().nextDouble() * 2 - 1;
      }
      return sum;
    });

    _videoEmbeddings[video.objectId!] = embedding;
    return embedding;
  }

  // Normalizar features
  List<double> _normalizeFeatures(List<double> features) {
    if (features.isEmpty) return [];

    double max = features.reduce(math.max);
    double min = features.reduce(math.min);

    if (max == min) return List.filled(features.length, 0.5);

    return features.map((f) => (f - min) / (max - min)).toList();
  }

  // Treinar o modelo
  Future<void> _trainModel(List<VideoInteractionModel> interactions) async {
    if (isTraining.value) return;

    isTraining.value = true;
    trainingLoss.clear();

    try {
      // Preparar dados de treinamento
      final List<List<double>> X = [];
      final List<double> y = [];

      for (var interaction in interactions) {
        final video = interaction.getVideo;
        if (video == null) continue;

        final videoEmbedding = await _generateVideoEmbedding(video);
        X.add(videoEmbedding);
        y.add(interaction.getWatchPercentage);
      }

      // Treinar modelo usando gradiente descendente
      for (int epoch = 0; epoch < epochs; epoch++) {
        double epochLoss = 0;

        // Processar em batches
        for (int i = 0; i < X.length; i += batchSize) {
          final end = math.min(i + batchSize, X.length);
          final batchX = X.sublist(i, end);
          final batchY = y.sublist(i, end);

          // Calcular gradiente e atualizar pesos
          for (int j = 0; j < batchX.length; j++) {
            final prediction = _predict(batchX[j]);
            final error = batchY[j] - prediction;

            // Atualizar pesos usando gradiente descendente
            for (int k = 0; k < embeddingSize; k++) {
              _userEmbeddings[currentUser.objectId!]![k] +=
                  learningRate * error * batchX[j][k];
            }

            epochLoss += error * error;
          }
        }

        epochLoss /= X.length;
        trainingLoss.add(epochLoss);
      }

      print('Treinamento concluído. Loss final: ${trainingLoss.last}');
    } catch (e) {
      print('Erro durante o treinamento: $e');
    } finally {
      isTraining.value = false;
    }
  }

  // Fazer previsão para um vídeo
  double _predict(List<double> videoEmbedding) {
    if (!_userEmbeddings.containsKey(currentUser.objectId)) {
      return 0.5; // Valor padrão se não houver embedding do usuário
    }

    final userEmbedding = _userEmbeddings[currentUser.objectId]!;
    double dotProduct = 0;

    for (int i = 0; i < embeddingSize; i++) {
      dotProduct += userEmbedding[i] * videoEmbedding[i];
    }

    return 1 /
        (1 + math.exp(-dotProduct)); // Sigmoid para normalizar entre 0 e 1
  }

  // Carregar embedding do usuário
  Future<void> _loadUserEmbedding() async {
    if (!_userEmbeddings.containsKey(currentUser.objectId)) {
      // Inicializar embedding aleatório se não existir
      _userEmbeddings[currentUser.objectId!] = List.generate(
        embeddingSize,
        (i) => math.Random().nextDouble() * 2 - 1,
      );
    }
  }

  // Obter recomendações
  Future<void> getRecommendations({bool reset = false}) async {
    if (isLoading.value) return;

    if (reset) {
      recommendedVideos.clear();
      hasMoreRecommendations.value = true;
    }

    if (!hasMoreRecommendations.value) return;

    try {
      isLoading.value = true;

      // Query para vídeos
      final query = QueryBuilder<PostsModel>(PostsModel())
        ..whereValueExists(PostsModel.postTypeVideo, true)
        ..includeObject([PostsModel.keyAuthor])
        ..orderByDescending(PostsModel.keyCreatedAt)
        ..setLimit(20);

      final response = await query.query();

      if (response.success && response.results != null) {
        final videos = response.results!.cast<PostsModel>();

        // Calcular scores para cada vídeo
        final List<Map<String, dynamic>> scoredVideos = [];

        for (var video in videos) {
          final embedding = await _generateVideoEmbedding(video);
          final score = _predict(embedding);

          scoredVideos.add({
            'video': video,
            'score': score,
          });
        }

        // Ordenar por score
        scoredVideos.sort((a, b) => b['score'].compareTo(a['score']));

        // Adicionar vídeos recomendados
        recommendedVideos.addAll(
          scoredVideos.map((item) => item['video'] as PostsModel),
        );

        hasMoreRecommendations.value = videos.length >= 20;
      }
    } catch (e) {
      print('Erro ao obter recomendações: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Registrar nova interação
  Future<void> recordInteraction(
      PostsModel video, double watchPercentage) async {
    try {
      // Atualizar features do usuário
      final interactions = await _loadUserInteractions();
      _calculateUserFeatures(interactions);

      // Treinar modelo com nova interação
      if (interactions.length >= batchSize) {
        await _trainModel(interactions);
      }

      // Invalidar cache
      _recommendationCache.clear();
    } catch (e) {
      print('Erro ao registrar interação: $e');
    }
  }
}
