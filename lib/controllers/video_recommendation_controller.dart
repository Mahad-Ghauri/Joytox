// ignore_for_file: unused_element_parameter

import 'package:get/get.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/VideoInteractionModel.dart';
import 'dart:math' as math;
import 'dart:collection';
import 'dart:async';

class VideoRecommendationController extends GetxController {
  static VideoRecommendationController get to => Get.find();

  // Função de inicialização segura que pode ser chamada em qualquer lugar
  static void initializeIfNeeded(UserModel currentUser) {
    try {
      if (Get.isRegistered<VideoRecommendationController>()) {
        final controller = Get.find<VideoRecommendationController>();
        if (controller.currentUser.objectId == currentUser.objectId) {
          // Já inicializado para este usuário
          return;
        }
        // Usuário diferente, remove a instância anterior
        Get.delete<VideoRecommendationController>();
      }

      // Criar nova instância
      Get.put<VideoRecommendationController>(
          VideoRecommendationController(currentUser: currentUser),
          permanent: true);
      print(
          'Sistema de recomendação inicializado para o usuário: ${currentUser.getFullName}');
    } catch (e) {
      print('Erro ao inicializar o sistema de recomendação: $e');
    }
  }

  // Usuário atual
  final UserModel currentUser;

  // Estado observável
  final RxList<PostsModel> recommendedVideos = <PostsModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMoreRecommendations = true.obs;

  // Sistema de filtros de categoria
  final RxList<String> activeFilters = <String>[].obs;
  final RxBool filtersEnabled = false.obs;
  final RxMap<String, int> availableCategories = <String, int>{}.obs;

  // Sistema de conteúdo semelhante
  final RxList<PostsModel> similarVideos = <PostsModel>[].obs;
  final RxBool isLoadingSimilar = false.obs;
  final RxBool showingSimilarContent = false.obs;
  PostsModel? currentReferenceVideo;

  // Histórico e preferências
  final RxMap<String, List<String>> userPreferences =
      <String, List<String>>{}.obs;
  final RxList<String> favoriteCategories = <String>[].obs;
  final RxList<String> dislikedCategories = <String>[].obs;

  // Configurações do sistema de recomendação
  final int initialRecommendationCount = 10;
  final int paginationLimit = 5;
  final double minWatchPercentageThreshold =
      0.1; // 10% para considerar como visto
  final double preferredWatchPercentageThreshold =
      0.7; // 70% para considerar como preferido

  // Configurações do processamento em lote
  final Duration _batchProcessingInterval = Duration(seconds: 30);
  final List<_PendingInteraction> _pendingInteractions = [];
  Timer? _batchProcessingTimer;
  final int _maxBatchSize = 20;
  final RxBool _processingBatch = false.obs;

  // Limites de pagamento e distribuição
  final double paidVideoPercentage = 0.3; // 30% de vídeos pagos

  int _currentPage = 0;
  bool _isLoadingMore = false;

  // Cache de recomendações
  final Map<String, List<PostsModel>> _recommendationCache =
      HashMap<String, List<PostsModel>>();
  final Map<String, DateTime> _cacheTimestamps = HashMap<String, DateTime>();
  final Duration _cacheDuration =
      Duration(minutes: 30); // Tempo de validade do cache

  final Map<String, Map<String, double>> _userInteractions = {};
  final Map<String, Map<String, List<String>>> _videoCategories = {};

  VideoRecommendationController({required this.currentUser});

  @override
  void onInit() {
    super.onInit();
    // Carregar preferências do usuário
    loadUserPreferences();

    // Carregar categorias disponíveis
    loadAvailableCategories();

    // Iniciar timer para processamento em lote
    _startBatchProcessingTimer();
  }

  @override
  void onClose() {
    // Garantir que todas as interações pendentes sejam processadas
    _processPendingInteractionsBatch(force: true);
    _batchProcessingTimer?.cancel();
    super.onClose();
  }

  // Verificar se o cache está válido
  bool _isCacheValid(String cacheKey) {
    if (!_recommendationCache.containsKey(cacheKey) ||
        !_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }

    final DateTime cacheTime = _cacheTimestamps[cacheKey]!;
    final DateTime now = DateTime.now();
    return now.difference(cacheTime) < _cacheDuration;
  }

  // Obter chave de cache com base nos parâmetros da consulta
  String _getCacheKey(bool showPaidVideos, int page) {
    final String categoryFilter =
        favoriteCategories.isNotEmpty ? favoriteCategories.join(',') : 'noCat';
    final String dislikedFilter = dislikedCategories.isNotEmpty
        ? dislikedCategories.join(',')
        : 'noDislike';
    final String userFilters =
        activeFilters.isNotEmpty ? activeFilters.join(',') : 'noFilters';

    return '${currentUser.objectId}_${showPaidVideos}_$page\_$categoryFilter\_$dislikedFilter\_$userFilters';
  }

  // Salvar resultados no cache
  void _cacheRecommendations(String cacheKey, List<PostsModel> videos) {
    _recommendationCache[cacheKey] = videos;
    _cacheTimestamps[cacheKey] = DateTime.now();
    print('Cache de recomendações atualizado: $cacheKey');
  }

  // Limpar cache quando as preferências do usuário mudarem
  void _invalidateCache() {
    final List<String> keysToRemove = [];

    _cacheTimestamps.forEach((key, timestamp) {
      if (key.startsWith('${currentUser.objectId}_')) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _recommendationCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    print(
        'Cache de recomendações invalidado para o usuário: ${currentUser.objectId}');
  }

  // Carregar e analisar interações anteriores do usuário para construir seu perfil
  Future<void> loadUserPreferences() async {
    try {
      isLoading.value = true;

      // Obter histórico de interações do usuário
      QueryBuilder<VideoInteractionModel> query =
          QueryBuilder<VideoInteractionModel>(VideoInteractionModel())
            ..whereEqualTo(
                VideoInteractionModel.keyUserId, currentUser.objectId)
            ..orderByDescending(VideoInteractionModel.keyUpdatedAt)
            ..setLimit(100); // Pegar as 100 interações mais recentes

      ParseResponse response = await query.query();

      if (response.success && response.results != null) {
        // Analisar as interações e extrair preferências
        Map<String, List<String>> tagPreferences = {};
        List<String> likedCategories = [];
        List<String> dislikedCategories = [];

        for (var result in response.results!) {
          VideoInteractionModel interaction = result as VideoInteractionModel;

          // Verificar se há interesse suficiente no vídeo
          bool isInterested = interaction.getWatchPercentage >=
                  preferredWatchPercentageThreshold ||
              interaction.getLiked == true ||
              interaction.getSaved == true;

          bool isDisinterested =
              interaction.getWatchPercentage < minWatchPercentageThreshold ||
                  interaction.getSkipped == true;

          // Processar tags e categorias
          if (interaction.getVideoTags.isNotEmpty) {
            for (String tag in interaction.getVideoTags) {
              if (!tagPreferences.containsKey(tag)) {
                tagPreferences[tag] = [];
              }

              // Adicionar o ID do vídeo à lista de vídeos com esta tag
              if (isInterested &&
                  !tagPreferences[tag]!.contains(interaction.getVideoId)) {
                tagPreferences[tag]!.add(interaction.getVideoId!);
              }
            }
          }

          // Processar a categoria
          if (interaction.getVideoCategory != null) {
            String category = interaction.getVideoCategory!;

            if (isInterested && !likedCategories.contains(category)) {
              likedCategories.add(category);
            } else if (isDisinterested &&
                !dislikedCategories.contains(category)) {
              dislikedCategories.add(category);
            }
          }
        }

        // Atualizar o estado observável
        userPreferences.value = tagPreferences;
        favoriteCategories.assignAll(likedCategories);
        dislikedCategories.assignAll(dislikedCategories);

        // Invalidar o cache quando as preferências mudam
        _invalidateCache();
      }
    } catch (e) {
      print('Erro ao carregar preferências do usuário: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Registrar uma nova interação com um vídeo
  void recordInteraction({
    required PostsModel video,
    required UserModel user,
    double watchPercentage = 0.0,
    int watchTimeSeconds = 0,
    bool? liked,
    bool? saved,
    bool? commented,
    bool? shared,
  }) {
    final userId = user.objectId!;
    final videoId = video.objectId!;

    // Inicializar mapa de interações do usuário se não existir
    if (!_userInteractions.containsKey(userId)) {
      _userInteractions[userId] = {};
    }

    // Calcular peso baseado nas interações
    double weight = 0.0;

    if (liked != null) {
      weight += liked ? 1.0 : -0.5;
    }

    if (saved != null) {
      weight += saved ? 2.0 : -1.0;
    }

    if (commented == true) {
      weight += 1.5;
    }

    if (shared == true) {
      weight += 2.0;
    }

    // Adicionar peso do tempo assistido
    if (watchTimeSeconds > 0) {
      weight += (watchPercentage * 0.5);
      weight += (watchTimeSeconds / 60.0).clamp(0.0, 2.0);
    }

    // Atualizar score de interação
    _userInteractions[userId]![videoId] =
        (_userInteractions[userId]![videoId] ?? 0.0) + weight;

    // Registrar categorias do vídeo
    _recordVideoCategories(video);
  }

  void _recordVideoCategories(PostsModel video) {
    final videoId = video.objectId!;
    final categories = _extractCategories(video);

    for (final category in categories) {
      if (!_videoCategories.containsKey(category)) {
        _videoCategories[category] = {'videos': [], 'tags': []};
      }

      if (!_videoCategories[category]!['videos']!.contains(videoId)) {
        _videoCategories[category]!['videos']!.add(videoId);
      }

      // Adicionar tags relacionadas
      final tags = _extractTags(video);
      for (final tag in tags) {
        if (!_videoCategories[category]!['tags']!.contains(tag)) {
          _videoCategories[category]!['tags']!.add(tag);
        }
      }
    }
  }

  List<String> _extractCategories(PostsModel video) {
    final categories = <String>[];

    // Extrair categorias do texto
    if (video.getText != null) {
      final text = video.getText!.toLowerCase();

      // Adicionar categorias baseadas em palavras-chave
      if (text.contains('#music') || text.contains('#música')) {
        categories.add('music');
      }
      if (text.contains('#dance') || text.contains('#dança')) {
        categories.add('dance');
      }
      // Adicionar mais categorias conforme necessário
    }

    return categories;
  }

  List<String> _extractTags(PostsModel video) {
    final tags = <String>[];

    if (video.getText != null) {
      final matches = RegExp(r'#\w+').allMatches(video.getText!);
      tags.addAll(matches.map((m) => m.group(0)!));
    }

    return tags;
  }

  // Iniciar timer para processamento em lote
  void _startBatchProcessingTimer() {
    _batchProcessingTimer?.cancel();
    _batchProcessingTimer = Timer.periodic(_batchProcessingInterval, (_) {
      _processPendingInteractionsBatch();
    });
    print(
        'Timer de processamento em lote iniciado: a cada ${_batchProcessingInterval.inSeconds} segundos');
  }

  // Processar lote de interações pendentes
  Future<void> _processPendingInteractionsBatch({bool force = false}) async {
    // Não processar se já estiver processando ou se não houver interações pendentes
    if (_processingBatch.value || _pendingInteractions.isEmpty) return;

    // Não processar se não atingiu o limite de tamanho e não é forçado
    if (_pendingInteractions.length < _maxBatchSize && !force) return;

    _processingBatch.value = true;

    try {
      print('Processando lote de ${_pendingInteractions.length} interações');

      // Criar cópia da lista de interações pendentes
      final List<_PendingInteraction> batchToProcess =
          List.from(_pendingInteractions);
      _pendingInteractions.clear();

      // Agrupar interações pelo mesmo vídeo
      final Map<String, _PendingInteraction> consolidatedInteractions = {};

      for (final interaction in batchToProcess) {
        final String videoId = interaction.video.objectId!;

        if (consolidatedInteractions.containsKey(videoId)) {
          // Atualizar interação existente com os valores mais recentes
          consolidatedInteractions[videoId]!.updateFrom(interaction);
        } else {
          // Adicionar nova interação ao mapa
          consolidatedInteractions[videoId] = interaction;
        }
      }

      // Processar interações consolidadas
      for (final interaction in consolidatedInteractions.values) {
        await _saveInteractionToServer(
          video: interaction.video,
          watchPercentage: interaction.watchPercentage,
          watchTimeSeconds: interaction.watchTimeSeconds,
          completed: interaction.completed,
          liked: interaction.liked,
          shared: interaction.shared,
          commented: interaction.commented,
          saved: interaction.saved,
          skipped: interaction.skipped,
        );
      }

      // Verificar se é necessário atualizar preferências do usuário
      bool shouldUpdatePreferences = consolidatedInteractions.values.any(
          (interaction) =>
              interaction.liked ||
              interaction.shared ||
              interaction.commented ||
              interaction.saved ||
              interaction.completed ||
              interaction.skipped);

      if (shouldUpdatePreferences) {
        _invalidateCache();
        loadUserPreferences();
      }

      print(
          'Processamento em lote concluído: ${consolidatedInteractions.length} interações');
    } catch (e) {
      print('Erro ao processar lote de interações: $e');

      // Em caso de erro, recuperar as interações não processadas
      if (_pendingInteractions.isEmpty) {
        // Se a lista atual está vazia, recuperar as interações do lote
        // que não conseguimos processar
        //_pendingInteractions.addAll(batchToProcess);
      }
    } finally {
      _processingBatch.value = false;
    }
  }

  // Salvar interação no servidor (método interno)
  Future<ParseResponse> _saveInteractionToServer({
    required PostsModel video,
    required double watchPercentage,
    required int watchTimeSeconds,
    bool completed = false,
    bool liked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
    bool skipped = false,
  }) async {
    try {
      // Este método contém a lógica original do recordInteraction
      // mas sem a parte de invalidar cache e atualizar preferências

      // Verificar se já existe uma interação com este vídeo
      QueryBuilder<VideoInteractionModel> query =
          QueryBuilder<VideoInteractionModel>(VideoInteractionModel())
            ..whereEqualTo(
                VideoInteractionModel.keyUserId, currentUser.objectId)
            ..whereEqualTo(VideoInteractionModel.keyVideoId, video.objectId);

      ParseResponse response = await query.query();
      VideoInteractionModel interaction;

      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        // Atualizar interação existente
        interaction = response.results!.first as VideoInteractionModel;

        // Apenas atualizar o tempo assistido se for maior que o anterior
        if (watchPercentage > interaction.getWatchPercentage) {
          interaction.setWatchPercentage = watchPercentage;
        }

        // Incrementar o tempo total assistido
        interaction.incrementWatchTime = watchTimeSeconds;

        // Incrementar visualizações completas se aplicável
        if (completed && interaction.getCompletedViews == 0) {
          interaction.incrementCompletedViews = 1;
        } else if (completed) {
          // Se já completou antes, incrementar visualizações repetidas
          interaction.incrementRepeatedViews = 1;
        }
      } else {
        // Criar nova interação
        interaction = VideoInteractionModel()
          ..setUser = currentUser
          ..setUserId = currentUser.objectId!
          ..setVideo = video
          ..setVideoId = video.objectId!
          ..setWatchTimeSeconds = watchTimeSeconds
          ..setWatchPercentage = watchPercentage
          ..setCompletedViews = completed ? 1 : 0
          ..setRepeatedViews = 0;

        // Obter e salvar categorias e tags
        List<String> tags = _extractTagsFromVideo(video);
        String category = _extractCategoryFromVideo(video);

        interaction.setVideoTags = tags;
        interaction.setVideoCategory = category;
      }

      // Atualizar interações sociais
      interaction.setLiked = liked;
      interaction.setShared = shared;
      interaction.setCommented = commented;
      interaction.setSaved = saved;
      interaction.setSkipped = skipped;

      // Calcular e atualizar a pontuação
      interaction.setInteractionScore = interaction.calculateInteractionScore();

      // Salvar a interação
      return await interaction.save();
    } catch (e) {
      print('Erro ao salvar interação no servidor: $e');
      ParseResponse response = ParseResponse();
      response.success = false;
      response.error =
          ParseError(code: 1, message: 'Erro ao salvar interação: $e');
      return response;
    }
  }

  // Obter recomendações de vídeos para o usuário
  Future<void> loadRecommendedVideos({bool reset = false}) async {
    if (isLoading.value || (_isLoadingMore && !reset)) return;

    if (reset) {
      _currentPage = 0;
      recommendedVideos.clear();
      hasMoreRecommendations.value = true;
    }

    if (!hasMoreRecommendations.value) return;

    try {
      isLoading.value = true;
      _isLoadingMore = true;

      // Determinar se é hora de mostrar vídeos pagos
      bool showPaidVideos = math.Random().nextDouble() <= paidVideoPercentage;

      // Verificar se temos um cache válido
      final String cacheKey = _getCacheKey(showPaidVideos, _currentPage);
      if (_isCacheValid(cacheKey)) {
        print('Usando cache de recomendações: $cacheKey');
        final List<PostsModel> cachedVideos = _recommendationCache[cacheKey]!;

        if (cachedVideos.isEmpty) {
          hasMoreRecommendations.value = false;
        } else {
          recommendedVideos.addAll(cachedVideos);
          _currentPage++;
        }

        isLoading.value = false;
        _isLoadingMore = false;
        return;
      }

      // Query principal para vídeos
      QueryBuilder<PostsModel> query = QueryBuilder<PostsModel>(PostsModel())
        ..whereValueExists(PostsModel.postTypeVideo, true)
        ..includeObject([PostsModel.keyAuthor])
        ..orderByDescending(PostsModel.keyCreatedAt);

      // Aplicar filtros de categoria selecionados pelo usuário
      if (filtersEnabled.value && activeFilters.isNotEmpty) {
        query.whereContainedIn('category', activeFilters);
      }
      // Se não há filtros ativos, usar preferências do usuário
      else if (favoriteCategories.isNotEmpty && !showPaidVideos) {
        // Adicionar preferência por categorias que o usuário gosta
        query.whereContainedIn('category', favoriteCategories);
      }

      // Excluir categorias que o usuário não gosta (sempre aplicar isso)
      if (dislikedCategories.isNotEmpty) {
        query.whereNotContainedIn('category', dislikedCategories);
      }

      // Filtro para vídeos pagos
      if (showPaidVideos) {
        query.whereValueExists(PostsModel.keyPaidAmount, true);
      }

      // Paginação
      query.setLimit(showPaidVideos
          ? 3
          : initialRecommendationCount); // Mostrar menos vídeos pagos por vez
      if (_currentPage > 0) {
        query.setAmountToSkip(
            _currentPage * (showPaidVideos ? 3 : initialRecommendationCount));
      }

      // Executar a consulta
      ParseResponse response = await query.query();

      if (response.success && response.results != null) {
        List<PostsModel> newVideos =
            response.results!.map((e) => e as PostsModel).toList();

        // Filtrar vídeos com baixo engajamento
        _filterLowEngagementVideos(newVideos);

        // Aplicar o algoritmo de classificação
        _rankVideos(newVideos);

        if (newVideos.isEmpty) {
          hasMoreRecommendations.value = false;
        } else {
          recommendedVideos.addAll(newVideos);
          _currentPage++;

          // Armazenar no cache
          _cacheRecommendations(cacheKey, newVideos);
        }
      } else {
        print('Falha na consulta: ${response.error?.message}');
        hasMoreRecommendations.value = false;
      }
    } catch (e) {
      print('Erro ao carregar recomendações: $e');
    } finally {
      isLoading.value = false;
      _isLoadingMore = false;
    }
  }

  // Filtrar vídeos com baixo engajamento
  void _filterLowEngagementVideos(List<PostsModel> videos) {
    // Obter vídeos que o usuário assistiu menos de 10% do tempo
    QueryBuilder<VideoInteractionModel> query =
        QueryBuilder<VideoInteractionModel>(VideoInteractionModel())
          ..whereEqualTo(VideoInteractionModel.keyUserId, currentUser.objectId)
          ..whereLessThan(VideoInteractionModel.keyWatchPercentage,
              minWatchPercentageThreshold);

    query.query().then((response) {
      if (response.success && response.results != null) {
        // Criar uma lista de IDs de vídeos com baixo engajamento
        List<String> lowEngagementVideoIds = response.results!
            .map((e) => (e as VideoInteractionModel).getVideoId!)
            .toList();

        // Remover os vídeos com baixo engajamento das recomendações
        videos.removeWhere(
            (video) => lowEngagementVideoIds.contains(video.objectId));
      }
    });
  }

  // Classificar vídeos com base nas preferências do usuário
  void _rankVideos(List<PostsModel> videos) {
    videos.sort((a, b) {
      // Pontuação para o vídeo A
      double scoreA = _calculateVideoScore(a);

      // Pontuação para o vídeo B
      double scoreB = _calculateVideoScore(b);

      // Comparar pontuações (maior primeiro)
      return scoreB.compareTo(scoreA);
    });
  }

  // Calcular pontuação para um vídeo
  double _calculateVideoScore(PostsModel video) {
    double score = 0.0;

    // Verificar se o vídeo está em uma categoria favorita
    String category = _extractCategoryFromVideo(video);
    if (favoriteCategories.contains(category)) {
      score += 2.0;
    }

    // Verificar se o vídeo tem tags favoritas
    List<String> videoTags = _extractTagsFromVideo(video);
    for (String tag in videoTags) {
      if (userPreferences.containsKey(tag) &&
          userPreferences[tag]!.isNotEmpty) {
        score += 0.5 *
            userPreferences[tag]!
                .length; // Mais vídeos vistos com essa tag = maior pontuação
      }
    }

    // Fatores adicionais (popularidade, etc.)
    score +=
        (video.getLikes.length) * 0.01; // Likes adicionam um pouco à pontuação
    score += (video.getComments.length) *
        0.02; // Comentários adicionam mais à pontuação

    return score;
  }

  // Métodos auxiliares para extrair informações dos vídeos
  List<String> _extractTagsFromVideo(PostsModel video) {
    // Implementação fictícia - em um sistema real, estas informações viriam do modelo
    List<String> tags = [];

    // Extrair hashtags da descrição
    String description = video.getDescription;
    RegExp exp = RegExp(r'\#(\w+)');
    Iterable<RegExpMatch> matches = exp.allMatches(description);

    for (var match in matches) {
      String tag = match.group(1)!.toLowerCase();
      if (!tags.contains(tag)) {
        tags.add(tag);
      }
    }

    return tags;
  }

  String _extractCategoryFromVideo(PostsModel video) {
    // Implementação fictícia - em um sistema real, a categoria seria um campo do modelo
    String category = "general";

    // Poderia ser extraída de metadados ou classificada automaticamente
    // Aqui fazemos uma lógica simples baseada na descrição
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

  // Carregar categorias disponíveis no sistema
  Future<void> loadAvailableCategories() async {
    try {
      // Consulta para obter categorias mais populares
      final QueryBuilder<VideoInteractionModel> query =
          QueryBuilder<VideoInteractionModel>(VideoInteractionModel());

      // Definir limite maior para obter uma boa amostra
      query.setLimit(500);

      final ParseResponse response = await query.query();

      if (response.success && response.results != null) {
        final Map<String, int> categories = {};

        // Contabilizar ocorrências de cada categoria
        for (final result in response.results!) {
          final VideoInteractionModel interaction =
              result as VideoInteractionModel;
          final String? category = interaction.getVideoCategory;

          if (category != null && category.isNotEmpty) {
            categories[category] = (categories[category] ?? 0) + 1;
          }
        }

        // Filtrar categorias com pelo menos 3 vídeos
        final Map<String, int> filteredCategories = {};
        categories.forEach((category, count) {
          if (count >= 3) {
            filteredCategories[category] = count;
          }
        });

        // Atualizar o mapa observável
        availableCategories.value = filteredCategories;

        print(
            'Categorias disponíveis carregadas: ${availableCategories.length}');
      }
    } catch (e) {
      print('Erro ao carregar categorias disponíveis: $e');
    }
  }

  // Adicionar ou remover um filtro de categoria
  void toggleCategoryFilter(String category) {
    if (activeFilters.contains(category)) {
      activeFilters.remove(category);
    } else {
      activeFilters.add(category);
    }

    // Atualizar o status de filtros habilitados
    filtersEnabled.value = activeFilters.isNotEmpty;

    // Recarregar recomendações com os novos filtros
    loadRecommendedVideos(reset: true);

    print('Filtros de categoria atualizados: $activeFilters');
  }

  // Limpar todos os filtros ativos
  void clearAllFilters() {
    activeFilters.clear();
    filtersEnabled.value = false;

    // Recarregar recomendações sem filtros
    loadRecommendedVideos(reset: true);

    print('Todos os filtros de categoria foram removidos');
  }

  // Método auxiliar para obter categorias recomendadas para o usuário
  List<String> getRecommendedCategories() {
    final List<String> recommendedCategories = [];

    // Adicionar categorias favoritas do usuário
    recommendedCategories.addAll(favoriteCategories);

    // Se não tivermos categorias suficientes, adicionar categorias populares
    if (recommendedCategories.length < 5 && availableCategories.isNotEmpty) {
      // Obter as 5 categorias mais populares
      final List<MapEntry<String, int>> sorted = availableCategories.entries
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0;
          i < sorted.length && recommendedCategories.length < 5;
          i++) {
        final String category = sorted[i].key;
        if (!recommendedCategories.contains(category) &&
            !dislikedCategories.contains(category)) {
          recommendedCategories.add(category);
        }
      }
    }

    return recommendedCategories;
  }

  // Verificar se um vídeo corresponde aos filtros ativos
  bool videoMatchesActiveFilters(PostsModel video) {
    if (!filtersEnabled.value || activeFilters.isEmpty) {
      return true; // Sem filtros ativos, todos os vídeos correspondem
    }

    // Extrair categoria do vídeo
    final String category = _extractCategoryFromVideo(video);

    // Verificar se a categoria está nos filtros ativos
    return activeFilters.contains(category);
  }

  // Obter vídeos semelhantes a um vídeo de referência
  Future<void> getSimilarVideos(PostsModel referenceVideo,
      {int limit = 10}) async {
    if (isLoadingSimilar.value) return;

    try {
      isLoadingSimilar.value = true;
      similarVideos.clear();
      showingSimilarContent.value = true;
      currentReferenceVideo = referenceVideo;

      // Extrair categoria e tags do vídeo de referência
      final String referenceCategory =
          _extractCategoryFromVideo(referenceVideo);
      final List<String> referenceTags = _extractTagsFromVideo(referenceVideo);
      final String referenceAuthorId = referenceVideo.getAuthor?.objectId ?? '';

      print('Buscando vídeos semelhantes a: ${referenceVideo.objectId}');
      print('Categoria: $referenceCategory, Tags: $referenceTags');

      // Query para vídeos da mesma categoria
      final QueryBuilder<PostsModel> query =
          QueryBuilder<PostsModel>(PostsModel())
            ..whereValueExists(PostsModel.postTypeVideo, true)
            ..includeObject([PostsModel.keyAuthor])
            ..orderByDescending(PostsModel.keyCreatedAt)
            ..setLimit(limit * 2); // Buscar mais para depois filtrar

      // Não incluir o próprio vídeo de referência
      query.whereNotEqualTo(PostsModel.keyObjectId, referenceVideo.objectId);

      // Priorizar vídeos da mesma categoria
      if (referenceCategory.isNotEmpty) {
        // Usamos o campo keyDescription para buscar pelo termo da categoria
        // já que não temos um campo específico de categoria
        query.whereContains(PostsModel.keyDescription, referenceCategory);
      }

      // Executar query
      final ParseResponse response = await query.query();

      if (response.success && response.results != null) {
        // Converter resultados para PostsModel
        final List<PostsModel> results =
            response.results!.map((e) => e as PostsModel).toList();

        // Calcular pontuação de similaridade para cada vídeo
        final List<Map<String, dynamic>> scoredVideos = [];

        for (final video in results) {
          final double score = _calculateSimilarityScore(
            video,
            referenceVideo,
            referenceCategory,
            referenceTags,
            referenceAuthorId,
          );

          scoredVideos.add({
            'video': video,
            'score': score,
          });
        }

        // Ordenar por pontuação (maior primeiro)
        scoredVideos.sort((a, b) => b['score'].compareTo(a['score']));

        // Selecionar os melhores resultados
        final List<PostsModel> bestMatches = scoredVideos
            .take(limit)
            .map((item) => item['video'] as PostsModel)
            .toList();

        // Atualizar a lista observável
        similarVideos.assignAll(bestMatches);

        print('Encontrados ${similarVideos.length} vídeos semelhantes');
      } else {
        print('Erro ao buscar vídeos semelhantes: ${response.error?.message}');
      }
    } catch (e) {
      print('Exceção ao buscar vídeos semelhantes: $e');
    } finally {
      isLoadingSimilar.value = false;
    }
  }

  // Calcular pontuação de similaridade entre dois vídeos
  double _calculateSimilarityScore(
    PostsModel video,
    PostsModel referenceVideo,
    String referenceCategory,
    List<String> referenceTags,
    String referenceAuthorId,
  ) {
    double score = 0.0;

    // 1. Verificar categoria (peso alto)
    final String category = _extractCategoryFromVideo(video);
    if (category == referenceCategory) {
      score += 5.0;
    }

    // 2. Verificar tags compartilhadas (peso médio)
    final List<String> tags = _extractTagsFromVideo(video);
    int sharedTags = 0;
    for (final tag in tags) {
      if (referenceTags.contains(tag)) {
        sharedTags++;
      }
    }

    // Adicionar pontuação proporcional à quantidade de tags compartilhadas
    if (referenceTags.isNotEmpty) {
      final double tagOverlap = sharedTags / referenceTags.length;
      score += tagOverlap * 3.0;
    }

    // 3. Mesmos termos na descrição (peso médio)
    final String videoDesc = video.getDescription.toLowerCase();
    final String referenceDesc = referenceVideo.getDescription.toLowerCase();

    // Calcular sobreposição de palavras-chave
    final Set<String> videoWords = _extractKeywords(videoDesc);
    final Set<String> referenceWords = _extractKeywords(referenceDesc);
    final int commonWords = videoWords.intersection(referenceWords).length;

    if (referenceWords.isNotEmpty) {
      final double wordOverlap = commonWords / referenceWords.length;
      score += wordOverlap * 2.0;
    }

    // 4. Mesmo autor (pequeno bônus)
    final String authorId = video.getAuthor?.objectId ?? '';
    if (authorId.isNotEmpty && authorId == referenceAuthorId) {
      score += 1.0;
    }

    // 5. Popularidade (pequeno bônus)
    final int likes = video.getLikes.length;
    if (likes > 50) score += 0.5;
    if (likes > 100) score += 0.5;

    // 6. Recência (pequeno bônus)
    final DateTime createdAt = video.createdAt ?? DateTime.now();
    final int daysAgo = DateTime.now().difference(createdAt).inDays;
    if (daysAgo < 7) score += 0.5; // Vídeo da última semana

    return score;
  }

  // Extrair palavras-chave de um texto
  Set<String> _extractKeywords(String text) {
    // Remover caracteres especiais e dividir por espaços
    final List<String> words =
        text.replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+'));

    // Filtrar palavras muito curtas e stopwords
    final Set<String> stopwords = {
      'a',
      'e',
      'o',
      'as',
      'os',
      'de',
      'da',
      'do',
      'das',
      'dos',
      'em',
      'no',
      'na',
      'nos',
      'nas',
      'um',
      'uma',
      'uns',
      'umas',
      'para',
      'por',
      'com',
      'seu',
      'sua',
      'meu',
      'minha',
      'que'
    };

    return words
        .where((word) => word.length > 3 && !stopwords.contains(word))
        .toSet();
  }

  // Limpar estado de recomendações semelhantes
  void clearSimilarVideos() {
    similarVideos.clear();
    showingSimilarContent.value = false;
    currentReferenceVideo = null;
  }

  // Verificar se um vídeo é semelhante ao vídeo de referência atual
  bool isSimilarToReference(PostsModel video) {
    if (currentReferenceVideo == null) return false;

    final String referenceCategory =
        _extractCategoryFromVideo(currentReferenceVideo!);
    final String videoCategory = _extractCategoryFromVideo(video);

    return videoCategory == referenceCategory;
  }

  // Método para encontrar vídeos similares ao vídeo atual
  List<PostsModel> findSimilarVideos(PostsModel currentVideo, {int limit = 5}) {
    // Implementação atual: apenas retorna alguns vídeos aleatórios do histórico
    // Em uma implementação real, usaria o histórico de interações e preferências
    List<PostsModel> results = [];

    // ... código existente para buscar vídeos similares ...

    return results;
  }

  /// Registra feedback negativo explícito para um vídeo
  void recordNegativeFeedback(PostsModel video) {
    print(
        'VideoRecommendationController: Registrando feedback negativo para o vídeo ${video.objectId}');

    // Adicionar à lista de usuários não desejados
    final author = video.getAuthor;
    if (author != null && author.objectId != null) {
      String authorId = author.objectId!;
      if (!dislikedCategories.contains("author_$authorId")) {
        dislikedCategories.add("author_$authorId");
        update();
      }
    }

    // Registrar a interação com o vídeo
    recordInteraction(
      video: video,
      user: currentUser,
      watchPercentage: 0.0,
      watchTimeSeconds: 0,
    );

    // Invalidar o cache para atualizar as recomendações
    _invalidateCache();
  }

  // Obter vídeos recomendados para o usuário
  List<PostsModel> getRecommendedVideos(List<PostsModel> videos, UserModel user,
      {int limit = 10}) {
    try {
      // Filtrar vídeos com baixo engajamento
      _filterLowEngagementVideos(videos);

      // Aplicar o algoritmo de classificação
      _rankVideos(videos);

      // Retornar os primeiros 'limit' vídeos
      return videos.take(limit).toList();
    } catch (e) {
      print('Erro ao obter vídeos recomendados: $e');
      return [];
    }
  }
}

// Classe para armazenar interações pendentes
class _PendingInteraction {
  final PostsModel video;
  double watchPercentage;
  int watchTimeSeconds;
  bool completed;
  bool liked;
  bool shared;
  bool commented;
  bool saved;
  bool skipped;
  final DateTime timestamp;

  _PendingInteraction({
    required this.video,
    required this.watchPercentage,
    required this.watchTimeSeconds,
    this.completed = false,
    this.liked = false,
    this.shared = false,
    this.commented = false,
    this.saved = false,
    this.skipped = false,
    required this.timestamp,
  });

  // Método para atualizar esta interação com dados de outra mais recente
  void updateFrom(_PendingInteraction other) {
    // Manter o maior valor de tempo assistido
    if (other.watchPercentage > watchPercentage) {
      watchPercentage = other.watchPercentage;
    }

    // Acumular tempo total assistido
    watchTimeSeconds += other.watchTimeSeconds;

    // Para flags booleanas, usar OR para preservar qualquer interação positiva
    completed = completed || other.completed;
    liked = liked || other.liked;
    shared = shared || other.shared;
    commented = commented || other.commented;
    saved = saved || other.saved;
    skipped = skipped || other.skipped;
  }
}
