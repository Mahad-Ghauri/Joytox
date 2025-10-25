// ignore_for_file: unused_field, unused_element, unnecessary_null_comparison, deprecated_member_use

import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../models/PostsModel.dart';
import '../models/UserModel.dart';
import 'dart:async';
import 'dart:math';
import 'package:trace/controllers/video_recommendation_controller.dart';
import '../services/video_cache_manager.dart';
import '../services/posts_service.dart';
import 'package:trace/models/VideoQuality.dart';

/// Controlador otimizado para reprodução de vídeos com baixo consumo de memória
class ReelsController extends GetxController with WidgetsBindingObserver {
  static ReelsController get to => Get.find();

  final UserModel? currentUser;
  final bool autoPlay;
  final PostsModel? initialVideo; // Vídeo inicial específico
  final int? initialVideoIndex; // Índice específico para começar

  // Referência ao serviço de posts
  late final PostsService _postsService;

  ReelsController({
    required this.currentUser,
    this.autoPlay = false,
    this.initialVideo,
    this.initialVideoIndex,
  }) {
    // Verificar se o PostsService já está registrado, se não, registrá-lo
    if (!Get.isRegistered<PostsService>()) {
      print('ReelsController: PostsService não registrado, registrando agora');
      final postsService = PostsService();
      Get.put(postsService, permanent: true);
    }

    // Obter a referência ao serviço
    _postsService = Get.find<PostsService>();

    // Garantir que o serviço tenha o usuário atual
    if (currentUser != null) {
      _postsService.setCurrentUser(currentUser!);
      print(
          'ReelsController: Usuário configurado no PostsService: ${currentUser!.objectId}');
    } else {
      print('ReelsController: Usuário atual é nulo');
    }

    // Carregar vídeos de forma síncrona no construtor
    _loadVideosSync();
  }

  /// Carrega vídeos de forma síncrona diretamente no construtor
  void _loadVideosSync() {
    // Verificar se já temos vídeos no serviço
    if (_postsService.videoPosts.isNotEmpty) {
      print(
          'ReelsController: Usando ${_postsService.videoPosts.length} vídeos já carregados no serviço');

      // Copiar vídeos do serviço imediatamente - isso é síncrono
      _videos.assignAll(_postsService.videoPosts);

      // Remover duplicatas
      _videos.assignAll(_removerDuplicatas(_videos));

      print(
          'ReelsController: ${_videos.length} vídeos disponíveis imediatamente');

      // Processar vídeo inicial se fornecido
      if (initialVideo != null) {
        // Adicionar o vídeo inicial ao serviço se não existir
        if (!_videos.any((v) => v.objectId == initialVideo!.objectId)) {
          _videos.add(initialVideo!);
          _postsService.videoPosts.add(initialVideo!);
        }
      }
    } else {
      print(
          'ReelsController: Nenhum vídeo disponível no serviço, carregando assincronamente');
      // Marcar como carregando para exibir indicador
      isLoading.value = true;
    }
  }

  /// Processa o vídeo inicial, colocando-o na posição correta
  void _processInitialVideo() {
    // Adicionar o vídeo inicial ao serviço se não existir
    if (!videos.any((v) => v.objectId == initialVideo!.objectId)) {
      _postsService.videoPosts.add(initialVideo!);
    }

    // Encontrar o índice correto do vídeo inicial
    final initialIndex =
        videos.indexWhere((v) => v.objectId == initialVideo!.objectId);
    if (initialIndex != -1) {
      currentVideoIndex.value = initialIndex;

      // Configurar PageController com o índice correto
      pageController = PageController(
        initialPage: initialIndex,
        keepPage: true,
        viewportFraction: 1.0,
      );

      // Inicializar o vídeo com um pequeno atraso
      Future.delayed(Duration(milliseconds: 100), () {
        prepareVideoAtIndex(initialIndex);
      });
    }
  }

  // Lista de vídeos local para evitar recursão infinita
  final RxList<PostsModel> _videos = <PostsModel>[].obs;

  // Propriedade para acessar os vídeos como lista observável
  RxList<PostsModel> get videos => _videos;

  // Variáveis reativas para controle de UI
  final RxBool isLoading = true.obs;
  final RxInt currentPage = 0.obs;
  final int limit = 5;

  // Configurações de memória
  static const int _maxCachedControllers =
      5; // Aumentado para 5 controladores em memória
// Aumentado para 70% em modo baixa qualidade

  // Tempo máximo de inicialização antes de tentar fallback

  // Flag para controle de qualidade adaptativa

  // Gerenciamento de estado para liberação de recursos
  final RxBool _lowMemoryMode = false.obs;
  bool get lowMemoryMode => _lowMemoryMode.value;

  // Configurações para gerenciamento de controladores
  bool _isInitializing = false;
  int _initializationAttempts = 0;
  static const int _maxInitializationAttempts = 3;

  // Cache e estado dos vídeos
  final Map<String, CachedVideoPlayerPlusController> _videoControllers = {};
  final Map<String, bool> _initializingControllers = {};
  final List<String> _controllerLoadOrder = []; // Para controle FIFO

  // Controle de estado
  final RxInt currentVideoIndex = (-1).obs;
  final RxBool _isInPageTransition = false.obs;
  bool get isInPageTransition => _isInPageTransition.value;
  final RxBool _isPreloading = false.obs;

  // Controle de carregamento
  bool _isLoadingMore = false;
  Timer? _cleanupTimer;
  Timer? _preloadTimer;
  Timer? _memoryMonitorTimer;

  // PageController para controlar navegação entre vídeos
  PageController? pageController;

  // Estado da UI
  final RxBool showPlayPauseIcon = false.obs;
  final RxBool showProgressBar = false.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isMuted = false.obs;
  final RxBool isBuffering = false.obs;
  Timer? _progressBarTimer;

  // Controle de tempo de visualização
  final RxDouble watchPercentage = 0.0.obs;
  Timer? _watchTimeTimer;

  // Duração da barra de progresso
  final RxInt progressBarDurationSeconds = 5.obs;

  final VideoCacheManager _cacheManager = VideoCacheManager();

  // Lista de callbacks para notificar sobre mudanças
  final List<VoidCallback> _customListeners = [];

  // Detectar se o dispositivo está com pouca memória
  bool _isLowMemoryDevice = false;
  int _memoryErrorCount = 0;
  final int _maxMemoryErrorsBeforeLowQualityMode = 2;
  bool _forceLowQualityMode = false;

  // Configurações adaptativas de buffer
  final RxDouble _bufferAhead = 3.0.obs; // Segundos de buffer para frente
  final RxBool _adaptiveQualityEnabled = true.obs;
  final RxBool _preloadEnabled = true.obs;

  // Métricas de desempenho
  final RxInt _droppedFrames = 0.obs;
  final RxDouble _averageLoadTime = 0.0.obs;
  final RxInt _stallCount = 0.obs;

  // Gerenciamento de memória avançado
  bool _isMemoryLow = false;
  final RxBool isLowMemoryMode = false.obs;

  // Gerenciar qualidade de vídeo
  final Rx<VideoQuality> currentQuality = VideoQuality.Auto.obs;

  // Cache de thumbnails
  final Map<String, Uint8List> _thumbnailCache = {};

  // Novo campo para controlar tentativas de retry
  bool _attemptedRetry = false;

  // Melhorando a constante para quantidade de vídeos pré-carregados
  static const int _preloadAheadCount = 5; // Aumentado para 5 vídeos à frente

  // Notificar listeners customizados
  void _notifyCustomListeners() {
    for (var listener in List.from(_customListeners)) {
      if (_customListeners.contains(listener)) {
        listener();
      }
    }
  }

  // Adicionar listener personalizado
  void addCustomListener(VoidCallback listener) {
    if (!_customListeners.contains(listener)) {
      _customListeners.add(listener);
    }
  }

  // Remover listener personalizado
  void removeCustomListener(VoidCallback listener) {
    _customListeners.remove(listener);
  }

  // Configurar opções de qualidade adaptativa
  void setAdaptiveQuality(bool enabled) {}

  @override
  void onInit() async {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // Detectar dispositivos com pouca memória com base em erros anteriores
    _isLowMemoryDevice = false;

    // Inicializar o cache manager
    try {
      await _cacheManager.initialize();
      print('ReelsController: Gerenciador de cache inicializado com sucesso');
    } catch (e) {
      print('ReelsController: Erro ao inicializar cache: $e');
    }

    // Ativar modo de baixa qualidade automaticamente em dispositivos conhecidos com baixa memória
    if (_isLowMemoryDevice) {
      _forceLowQualityMode = true;
      print("ReelsController: Modo de baixa qualidade ativado automaticamente");
    }

    // Definir o usuário atual no serviço se ainda não estiver definido
    if (currentUser != null && _postsService.currentUser == null) {
      _postsService.setCurrentUser(currentUser!);
    }

    // Carregar vídeos imediatamente
    await _loadVideosImediately();

    // Configurar vídeo inicial
    if (initialVideo != null) {
      _processInitialVideo();
    } else {
      // Restaurar último vídeo assistido
      await _restoreLastVideo();
    }

    // Configurar temporizador para monitorar memória
    _setupMemoryMonitor();

    // Configurar timer de limpeza de controladores não utilizados
    _setupCleanupTimer();
  }

  /// Carrega vídeos imediatamente, sem estado de carregamento assíncrono
  Future<void> _loadVideosImediately() async {
    isLoading.value = true;

    try {
      print('ReelsController: Carregando vídeos imediatamente');

      // Se a lista de posts já está vazia, tentar carregar
      if (_postsService.videoPosts.isEmpty) {
        await _postsService.loadInitialVideos();
      }

      // Se ainda está vazia após tentar carregar, tentar novamente
      if (_postsService.videoPosts.isEmpty) {
        print('ReelsController: Primeira tentativa falhou, tentando novamente');
        await _postsService.loadInitialVideos();
      }

      // Copiar vídeos do serviço e garantir que não há duplicatas
      _videos.assignAll(_postsService.videoPosts);
      _videos.assignAll(_removerDuplicatas(_videos));

      // Garantir que os autores dos vídeos estejam carregados
      await _verificarECarregarAutoresDosPosts();

      // Force refresh of author data for all videos
      for (var video in _videos) {
        if (video.getAuthor == null && video.getAuthorId != null) {
          print(
              'ReelsController: Force loading author for video ${video.objectId}');
          await _postsService.fetchAuthorForPost(video);
        }
      }

      print(
          'ReelsController: ${_videos.length} vídeos carregados imediatamente');

      // Iniciar pré-carregamento em segundo plano
      if (_videos.isNotEmpty) {
        _preloadInitialVideos();
      }
    } catch (e) {
      print('ReelsController: Erro ao carregar vídeos imediatamente: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Pré-carregar os vídeos iniciais em segundo plano
  Future<void> _preloadInitialVideos() async {
    try {
      print('ReelsController: Iniciando pré-carregamento de vídeos');

      // Determinar quantidade de vídeos a pré-carregar
      final preloadCount = math.min(_preloadAheadCount, videos.length);

      // Lista para guardar os metadados dos vídeos a serem pré-carregados
      final List<Map<String, String>> videosToPreload = [];

      // Adicionar os primeiros N vídeos à lista de pré-carregamento
      for (int i = 0; i < preloadCount; i++) {
        if (i < videos.length) {
          final video = videos[i];
          if (video.objectId != null) {
            final videoUrl = _getVideoUrl(video);
            if (videoUrl.isNotEmpty) {
              videosToPreload.add({
                'id': video.objectId!,
                'url': videoUrl,
              });
            }
          }
        }
      }

      // Iniciar pré-carregamento em segundo plano
      if (videosToPreload.isNotEmpty) {
        print(
            'ReelsController: Pré-carregando ${videosToPreload.length} vídeos iniciais');
        _cacheManager.preloadVideos(videosToPreload,
            maxConcurrent: 2, priority: true);
      }
    } catch (e) {
      print('ReelsController: Erro no pré-carregamento inicial: $e');
    }
  }

  /// Pré-carrega os próximos vídeos (mídia completa, não apenas metadados)
  Future<void> _preloadNextVideos(int currentIndex) async {
    // Se o pré-carregamento está desativado, sair
    if (!_preloadEnabled.value) return;

    // Verificar se já está pré-carregando para evitar chamadas simultâneas
    if (_isPreloading.value) {
      print('ReelsController: Pré-carregamento já em andamento, ignorando');
      return;
    }

    // Marcar como em pré-carregamento
    _isPreloading.value = true;

    try {
      // Apenas preparar o próximo vídeo, sem download em massa
      final nextIndex = currentIndex + 1;
      if (nextIndex < videos.length) {
        print('ReelsController: Preparando próximo vídeo (índice $nextIndex)');

        // Usar prepareVideoAtIndex diretamente, que já tem lógica de cache
        await prepareVideoAtIndex(nextIndex, highPriority: false);

        // Opcionalmente, preparar um segundo vídeo à frente com prioridade ainda mais baixa
        final secondNextIndex = currentIndex + 2;
        if (secondNextIndex < videos.length && !isLowMemoryMode.value) {
          print(
              'ReelsController: Preparando segundo próximo vídeo (índice $secondNextIndex)');
          prepareVideoAtIndex(secondNextIndex, highPriority: false);
        }
      }
    } catch (e) {
      print('ReelsController: Erro ao pré-carregar próximos vídeos: $e');
    } finally {
      // Importante: garantir que o estado seja redefinido após um período
      Future.delayed(Duration(seconds: 2), () {
        _isPreloading.value = false;
      });
    }
  }

  /// Verificar e carregar autores dos posts se necessário
  Future<void> _verificarECarregarAutoresDosPosts() async {
    try {
      // Debug: Print all videos and their authors
      print(
          'ReelsController: Verificando autores para ${videos.length} vídeos');
      for (int i = 0; i < videos.length; i++) {
        final video = videos[i];
        print(
            'ReelsController: Vídeo $i - ID: ${video.objectId}, Author: ${video.getAuthor?.getFullName}, AuthorID: ${video.getAuthorId}');
      }

      // Verificar se algum vídeo não tem autor
      final videosComAutorNulo =
          videos.where((v) => v.getAuthor == null).toList();

      if (videosComAutorNulo.isEmpty) {
        print('ReelsController: Todos os vídeos já têm autor');
        return;
      }

      print(
          'ReelsController: ${videosComAutorNulo.length} vídeos sem autor, carregando...');

      // Carregar autores em lote se possível
      if (Get.isRegistered<PostsService>()) {
        for (var video in videosComAutorNulo) {
          // Salvar o vídeo localmente para garantir que estamos trabalhando com a mesma instância
          final PostsModel videoLocal = video;

          // Verificar se podemos modificar o vídeo de forma segura
          try {
            await _postsService.fetchAuthorForPost(videoLocal);

            // Force UI update after author is loaded
            if (videoLocal.getAuthor != null) {
              print(
                  'ReelsController: Author loaded for video ${videoLocal.objectId}: ${videoLocal.getAuthor!.getFullName}');
              // Force UI refresh
              videos.refresh();
            }
          } catch (e) {
            print(
                'ReelsController: Erro ao carregar autor para vídeo ${videoLocal.objectId}: $e');
          }
        }
      } else {
        // Carregamento manual
        for (var video in videosComAutorNulo) {
          if (video.getAuthorId != null) {
            try {
              // Salvar o vídeo localmente para garantir que estamos trabalhando com a mesma instância
              final PostsModel videoLocal = video;
              final String autorId = videoLocal.getAuthorId!;

              // Usar forQuery() para criar a consulta
              QueryBuilder<UserModel> query =
                  QueryBuilder<UserModel>(UserModel.forQuery())
                    ..whereEqualTo(UserModel.keyObjectId, autorId);

              final response = await query.query();
              if (response.success &&
                  response.results != null &&
                  response.results!.isNotEmpty) {
                final author = response.results!.first as UserModel;
                videoLocal.setAuthor = author;
                print(
                    'ReelsController: Autor ${author.getFullName} carregado para vídeo ${videoLocal.objectId}');
              }
            } catch (e) {
              print(
                  'ReelsController: Erro ao carregar autor para vídeo ${video.objectId}: $e');
            }
          }
        }
      }

      // Atualizar a lista para garantir que as mudanças sejam refletidas na UI
      videos.refresh();
    } catch (e) {
      print('ReelsController: Erro ao verificar autores dos posts: $e');
    }
  }

  /// Carrega os vídeos do Parse para exibição
  Future<void> _loadVideos() async {
    isLoading.value = true;

    try {
      print('ReelsController: Carregando vídeos...');

      // Verificar se já temos vídeos
      if (_videos.isNotEmpty) {
        // Se já temos vídeos, apenas garantir que temos autores
        await _verificarECarregarAutoresDosPosts();
        return;
      }

      // Usar o serviço de posts para carregar vídeos
      if (_postsService.videoPosts.isEmpty) {
        // Carregar vídeos iniciais se ainda não estiverem carregados
        await _postsService.loadInitialVideos();
      }

      // Copiar vídeos do serviço e garantir que temos autores
      _videos.assignAll(_postsService.videoPosts);
      _videos.assignAll(_removerDuplicatas(_videos));

      // Verificar que temos autores para todos os vídeos
      await _verificarECarregarAutoresDosPosts();

      print('ReelsController: ${_videos.length} vídeos carregados');

      // Se ainda não temos vídeos suficientes, carregar mais
      if (_videos.length < 5) {
        print('ReelsController: Poucos vídeos, carregando mais...');

        // Usar o método específico de vídeos
        await _postsService.loadMoreVideos();
        _videos.assignAll(_postsService.videoPosts);
        _videos.assignAll(_removerDuplicatas(_videos));

        // Verificar autores novamente
        await _verificarECarregarAutoresDosPosts();
      }
    } catch (e) {
      print('ReelsController: Erro ao carregar vídeos: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Carregar mais vídeos quando estiver próximo ao fim da lista
  Future<void> loadMoreVideos() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;

    try {
      print('ReelsController: Carregando mais vídeos...');

      // Usar o serviço para carregar mais vídeos
      await _postsService.loadMoreVideos();

      // Atualizar lista com vídeos do serviço
      _videos.assignAll(_postsService.videoPosts);

      // Remover duplicatas que possam ter sido adicionadas
      _videos.assignAll(_removerDuplicatas(_videos));

      // Verificar autores
      await _verificarECarregarAutoresDosPosts();

      // Precarregar o próximo vídeo se necessário
      if (currentVideoIndex.value == _videos.length - 2) {
        prepareVideoAtIndex(currentVideoIndex.value + 1);
      }

      print(
          'ReelsController: Novos vídeos carregados (total: ${_videos.length})');
    } catch (e) {
      print('ReelsController: Erro ao carregar mais vídeos: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Restaurar o último vídeo visualizado
  Future<void> _restoreLastVideo() async {
    final savedVideoId = _postsService.lastViewedVideoId;

    // Carregar vídeos se não estiverem carregados
    if (_videos.isEmpty) {
      isLoading.value = true;
      await _postsService.loadInitialVideos();
      _videos.assignAll(_postsService.videoPosts);
      _videos.assignAll(_removerDuplicatas(_videos));
      await _verificarECarregarAutoresDosPosts();
      isLoading.value = false;
    }

    // Verificar se o vídeo salvo existe na lista
    if (savedVideoId != null) {
      final videoIndex = _videos.indexWhere((v) => v.objectId == savedVideoId);
      if (videoIndex != -1) {
        // Configurar PageController com o índice correto
        pageController = PageController(
          initialPage: videoIndex,
          keepPage: true,
          viewportFraction: 1.0,
        );

        // Atualizar índice atual
        currentVideoIndex.value = videoIndex;

        // Inicializar o vídeo com um pequeno atraso
        Future.delayed(Duration(milliseconds: 100), () {
          prepareVideoAtIndex(videoIndex);
        });
      } else {
        // Se o vídeo salvo não existe mais, começar do início
        pageController = PageController(
          initialPage: 0,
          keepPage: true,
          viewportFraction: 1.0,
        );
        currentVideoIndex.value = 0;

        Future.delayed(Duration(milliseconds: 100), () {
          prepareVideoAtIndex(0);
        });
      }
    } else {
      // Se não há vídeo salvo, começar do início
      pageController = PageController(
        initialPage: 0,
        keepPage: true,
        viewportFraction: 1.0,
      );
      currentVideoIndex.value = 0;

      Future.delayed(Duration(milliseconds: 100), () {
        prepareVideoAtIndex(0);
      });
    }
  }

  /// Configurar monitoramento de memória
  void _setupMemoryMonitor() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = Timer.periodic(Duration(seconds: 30), (_) {
      // Verificar uso de memória
      _checkMemoryUsage();
    });
  }

  /// Verificar uso de memória e ajustar comportamento
  void _checkMemoryUsage() {
    try {
      // Contar número de controladores ativos
      int activeControllers = _videoControllers.length;

      // Se temos muitos controladores ativos e não estamos em modo de baixa memória
      if (activeControllers > _maxCachedControllers / 2 &&
          !_lowMemoryMode.value) {
        // Liberar controladores não utilizados
        releaseUnusedControllers();
      }

      print(
          'ReelsController: Monitoramento de memória - $activeControllers controladores ativos');
    } catch (e) {
      print('ReelsController: Erro ao verificar memória: $e');
    }
  }

  /// Configurar timer de limpeza
  void _setupCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _performControllerCleanup();

      // Verificar se precisamos carregar mais vídeos
      checkAndLoadMoreVideos();
    });
  }

  /// Método para verificar e carregar mais vídeos se estiver próximo do fim da lista
  void checkAndLoadMoreVideos() {
    // Se estamos próximos do fim da lista, carregar mais vídeos
    if (currentVideoIndex.value >= 0 &&
        videos.isNotEmpty &&
        currentVideoIndex.value >= videos.length - 3 &&
        !_isLoadingMore) {
      print(
          'ReelsController: Próximo do fim da lista, carregando mais vídeos automaticamente');
      loadMoreVideos();
    }
  }

  /// Método para atualizar um vídeo específico na lista
  void updateVideo(PostsModel updatedVideo) {
    try {
      if (updatedVideo.objectId == null) return;

      // Encontrar o índice do vídeo na lista
      final index = _videos
          .indexWhere((video) => video.objectId == updatedVideo.objectId);

      if (index != -1) {
        // Substituir o vídeo antigo pelo atualizado
        _videos[index] = updatedVideo;
        print('ReelsController: Vídeo atualizado: ${updatedVideo.objectId}');

        // Atualizar a UI
        _videos.refresh();
      }
    } catch (e) {
      print('ReelsController: Erro ao atualizar vídeo: $e');
    }
  }

  /// Método para atualizar a lista de vídeos com recomendações
  Future<void> updateRecommendedVideos() async {
    try {
      print('ReelsController: Atualizando lista de vídeos recomendados');

      // Verificar se temos o serviço de recomendação registrado
      if (Get.isRegistered<VideoRecommendationController>()) {
        final recommendationController =
            Get.find<VideoRecommendationController>();

        // Obter recomendações personalizadas
        final recommendedVideos = recommendationController
            .getRecommendedVideos(videos, currentUser!, limit: 10);

        if (recommendedVideos.isNotEmpty) {
          // Adicionar novos vídeos recomendados que ainda não estão na lista
          for (final video in recommendedVideos) {
            if (!videos.any((v) => v.objectId == video.objectId)) {
              videos.add(video);
            }
          }

          // Garantir que temos autores para os vídeos
          await _verificarECarregarAutoresDosPosts();

          // Atualizar a UI
          videos.refresh();
          print(
              'ReelsController: ${recommendedVideos.length} vídeos recomendados adicionados');
        }
      }

      // Verificar se ainda temos vídeos suficientes
      if (videos.length < 10) {
        await loadMoreVideos();
      }
    } catch (e) {
      print('ReelsController: Erro ao atualizar vídeos recomendados: $e');
    }
  }

  /// Obtém o controlador para um índice específico, garantindo que seja válido
  Future<CachedVideoPlayerPlusController?> getControllerForIndex(
      int index) async {
    if (index < 0 || index >= videos.length) {
      print('ReelsController: Índice $index fora dos limites');
      return null;
    }

    try {
      final video = videos[index];
      final videoUrl = video.getVideo?.url;

      if (videoUrl == null) {
        print('ReelsController: URL nula para vídeo $index');
        return null;
      }

      // Verificar se já existe um controlador para este URL e se ele é válido
      if (_videoControllers.containsKey(videoUrl)) {
        final controller = _videoControllers[videoUrl];

        if (controller != null) {
          try {
            // Verificar se o controlador ainda é válido e inicializado
            if (controller.value.isInitialized && !controller.value.hasError) {
              // Teste para verificar se o controlador não está descartado
              controller.addListener(() {});
              controller.removeListener(() {});

              return controller;
            }
          } catch (e) {
            // Se ocorrer um erro, o controlador pode ter sido descartado
            print(
                'ReelsController: Controlador descartado detectado para $videoUrl: $e');
            _videoControllers.remove(videoUrl);
          }
        } else {
          // Se o controlador for nulo, remover do mapa
          _videoControllers.remove(videoUrl);
        }
      }

      // Se não encontramos um controlador válido, preparar um novo
      print('ReelsController: Criando novo controlador para o vídeo $index');
      return await prepareVideoAtIndex(index);
    } catch (e) {
      print(
          'ReelsController: Erro ao obter controlador para índice $index: $e');
      return null;
    }
  }

  /// Libera controladores de vídeo não utilizados para economizar memória
  Future<void> releaseUnusedControllers() async {
    try {
      if (currentVideoIndex.value < 0 ||
          currentVideoIndex.value >= videos.length) {
        return;
      }

      // Obter URL do vídeo atual
      final currentVideo = videos[currentVideoIndex.value];
      final currentVideoUrl = currentVideo.getVideo?.url;
      if (currentVideoUrl == null) return;

      // Manter atual e próximo por URL
      final List<String> urlsToKeep = [currentVideoUrl];
      if (currentVideoIndex.value < videos.length - 1) {
        final nextVideo = videos[currentVideoIndex.value + 1];
        if (nextVideo.getVideo?.url != null) {
          urlsToKeep.add(nextVideo.getVideo!.url!);
        }
      }

      // Lista de controladores a liberar (chaves são URLs)
      final List<String> idsToRelease = _videoControllers.keys
          .where((url) => !urlsToKeep.contains(url))
          .toList();

      // Liberar controladores não utilizados
      for (final id in idsToRelease) {
        await _videoControllers[id]?.pause();
        await _videoControllers[id]?.dispose();
        _videoControllers.remove(id);
      }

      // Atualizar lista de ordem
      _controllerLoadOrder
          .removeWhere((id) => !_videoControllers.containsKey(id));

      if (idsToRelease.isNotEmpty) {
        print(
            'ReelsController: Liberados ${idsToRelease.length} controladores não utilizados');
      }
    } catch (e) {
      print(
          'ReelsController: Erro ao liberar controladores não utilizados: $e');
    }
  }

  /// Libera todos os controladores para limpeza de memória
  Future<void> disposeAllControllers() async {
    try {
      // Lista de controladores a serem liberados
      final controllersToDispose =
          Map<String, CachedVideoPlayerPlusController>.from(_videoControllers);

      // Limpar o mapa principal primeiro para evitar acesso durante a liberação
      _videoControllers.clear();
      _controllerLoadOrder.clear();

      // Liberar cada controlador com tratamento de erros
      for (final entry in controllersToDispose.entries) {
        try {
          final controller = entry.value;
          // Verificar se o controlador está inicializado antes de tentar pausar/descartar
          if (controller.value.isInitialized) {
            try {
              await controller.pause();
              await controller.dispose();
            } catch (e) {
              // Ignorar erros ao descartar, pois o controlador pode já estar descartado
              print('ReelsController: Erro ao descartar controlador: $e');
            }
          }
        } catch (e) {
          print(
              'ReelsController: Erro ao liberar controlador ${entry.key}: $e');
        }
      }

      print('ReelsController: Todos os controladores liberados');
    } catch (e) {
      print('ReelsController: Erro ao liberar todos os controladores: $e');
    }
  }

  @override
  void onClose() {
    // Garantir que todos os controladores são liberados quando o controlador for fechado
    disposeAllControllers();

    // Cancelar todos os timers
    _cleanupTimer?.cancel();
    _preloadTimer?.cancel();
    _memoryMonitorTimer?.cancel();
    _watchTimeTimer?.cancel();
    _progressBarTimer?.cancel();

    // Remover observador
    WidgetsBinding.instance.removeObserver(this);

    super.onClose();
  }

  /// Método para buscar controlador por URL (necessário para compatibilidade)
  CachedVideoPlayerPlusController? getCurrentControllerByUrl(String url) {
    try {
      // Encontrar controlador para a URL
      for (var entry in _videoControllers.entries) {
        if (entry.value != null) {
          // Verificar se é o URL correto (verificando com path completo ou parcial)
          if (url.contains(entry.key) || entry.key.contains(url)) {
            return entry.value;
          }
        }
      }
    } catch (e) {
      print('ReelsController: Erro ao obter controlador por URL: $e');
    }

    return null;
  }

  /// Método para buscar posição de vídeo
  Future<void> seekVideo(int index, Duration position) async {
    if (index < 0 || index >= videos.length) {
      print('ReelsController: Índice inválido para busca: $index');
      return;
    }

    final video = videos[index];
    final videoUrl = video.getVideo?.url;
    if (videoUrl == null) return;

    if (_videoControllers.containsKey(videoUrl)) {
      final controller = _videoControllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        await controller.seekTo(position);
        print('ReelsController: Vídeo buscado para posição $position');
      }
    }
  }

  /// Atualiza métricas de memória
  void _updateMemoryMetrics() {
    try {
      // Contar número de controladores ativos
      int activeControllers = _videoControllers.length;
      print(
          'ReelsController: Métricas de memória - $activeControllers controladores ativos');
    } catch (e) {
      print('ReelsController: Erro ao atualizar métricas de memória: $e');
    }
  }

  /// Método para limpar controladores antigos periodicamente
  void _performControllerCleanup() {
    if (_videoControllers.length > _maxCachedControllers / 2) {
      releaseUnusedControllers();
    }
  }

  /// Relata métricas de desempenho para análise e depuração
  void reportPerformanceMetrics() {
    print("=== Métricas de Desempenho de Vídeo ===");
    print(
        "Tempo médio de carregamento: ${_averageLoadTime.value.toStringAsFixed(2)}s");
    print("Quadros descartados: ${_droppedFrames.value}");
    print("Travamentos: ${_stallCount.value}");
    print("Modo de memória baixa: ${isLowMemoryMode.value}");
    print("Controladores ativos: ${_videoControllers.length}");
    print("======================================");
  }

  /// Obter instância do gerenciador de cache
  VideoCacheManager _getCacheManager() {
    return VideoCacheManager();
  }

  /// Pausa todos os vídeos em execução
  Future<void> pauseAllVideos() async {
    try {
      // Pausar todos os controladores em execução
      for (final controller in _videoControllers.values) {
        if (controller.value.isPlaying) {
          await controller.pause();
        }
      }

      // Atualizar estado de reprodução
      isPlaying.value = false;
    } catch (e) {
      print("ReelsController: Erro ao pausar todos os vídeos: $e");
    }
  }

  /// Reproduz o vídeo atual
  Future<void> playCurrentVideo() async {
    try {
      final currentIndex = currentVideoIndex.value;
      if (currentIndex >= 0 && currentIndex < videos.length) {
        print(
            'ReelsController: Reproduzindo vídeo atual no índice $currentIndex');

        // Pausar todos os outros vídeos primeiro
        await pauseAllVideos();

        final controller = await getControllerForIndex(currentIndex);
        if (controller != null) {
          // Garantir que começamos do início se for a primeira reprodução
          if (controller.value.position == Duration.zero ||
              controller.value.position >=
                  controller.value.duration - Duration(milliseconds: 200)) {
            await controller.seekTo(Duration.zero);
          }

          // Verificar volume
          await controller.setVolume(1.0);

          // Iniciar reprodução
          await controller.play();
          isPlaying.value = true;

          // Verificar se o vídeo está realmente reproduzindo após um breve período
          await Future.delayed(Duration(milliseconds: 500));
          if (!controller.value.isPlaying && isPlaying.value) {
            print(
                "ReelsController: Vídeo não está reproduzindo, tentando recuperar");
            // Tentar reiniciar a reprodução
            await controller.seekTo(Duration.zero);
            await controller.play();
          }
        }
      }
    } catch (e) {
      print('ReelsController: Erro ao reproduzir vídeo atual: $e');

      // Tentar reiniciar o controlador em caso de erro
      final currentIndex = currentVideoIndex.value;
      if (currentIndex >= 0 && currentIndex < videos.length) {
        final video = videos[currentIndex];
        if (video.objectId != null &&
            _videoControllers.containsKey(video.objectId)) {
          try {
            await _videoControllers[video.objectId]!.dispose();
            _videoControllers.remove(video.objectId);
            await prepareVideoAtIndex(currentIndex);
          } catch (e2) {
            print('ReelsController: Erro ao tentar reiniciar controlador: $e2');
          }
        }
      }
    }
  }

  /// Alterna entre reproduzir e pausar o vídeo atual
  Future<void> togglePlayPause() async {
    try {
      final currentIndex = currentVideoIndex.value;
      if (currentIndex >= 0 && currentIndex < videos.length) {
        final controller = await getControllerForIndex(currentIndex);
        if (controller != null) {
          if (controller.value.isPlaying) {
            await controller.pause();
            isPlaying.value = false;
          } else {
            await controller.play();
            isPlaying.value = true;
          }

          // Mostrar ícone de play/pause
          showPlayPauseIcon.value = true;
          Future.delayed(Duration(milliseconds: 800), () {
            showPlayPauseIcon.value = false;
          });
        }
      }
    } catch (e) {
      print('ReelsController: Erro ao alternar reprodução: $e');
    }
  }

  /// Registra um travamento no vídeo (buffer insuficiente)
  void reportStall() {
    _stallCount.value++;

    // Se temos muitos travamentos, verificar memória
    if (_stallCount.value > 3) {
      _stallCount.value = 0;
      _checkMemoryPressure();

      if (!isLowMemoryMode.value) {
        print(
            'ReelsController: Muitos travamentos, ativando modo de baixa memória');
        isLowMemoryMode.value = true;
      }
    }
  }

  /// Reportar quadros perdidos para análise de desempenho
  void reportDroppedFrames(int count) {
    _droppedFrames.value += count;
    print(
        "ReelsController: Reportados $count quadros perdidos. Total: ${_droppedFrames.value}");

    // Se temos muitos quadros perdidos, liberar recursos
    if (_droppedFrames.value > 60 && !isLowMemoryMode.value) {
      print("ReelsController: Muitos quadros perdidos, liberando recursos");
      isLowMemoryMode.value = true;
      _forceReleaseAllControllersExceptCurrent();
    }
  }

  /// Preparar para rolagem rápida (pré-liberar recursos)
  Future<void> prepareForFastScroll() async {
    if (_isInPageTransition.value) return;

    _isInPageTransition.value = true;
    print("ReelsController: Preparando para rolagem rápida");

    // Liberação proativa de recursos para rolagem suave
    await pauseAllVideos();
    _forceReleaseAllControllersExceptCurrent();
  }

  /// Retoma comportamento normal após rolagem rápida
  void resumeFromFastScroll() {
    _isInPageTransition.value = false;
    _preloadEnabled.value = true;

    // Tentar pré-carregar os próximos vídeos
    _preloadNextVideos(currentVideoIndex.value);
  }

  /// Manipula a mudança de página/índice do vídeo
  Future<void> onPageChanged(int index) async {
    if (index < 0 || index >= videos.length) return;

    // Evitar processamento desnecessário se já estamos nesta página
    if (currentVideoIndex.value == index) return;

    try {
      // Registrar índice anterior para limpeza
      final int previousIndex = currentVideoIndex.value;

      // Atualizar índice atual
      currentVideoIndex.value = index;
      print('ReelsController: Índice alterado para $index');

      // Em caso de scroll rápido ou memória baixa, liberar recursos primeiro
      if ((previousIndex - index).abs() > 1 || isLowMemoryMode.value) {
        await _forceReleaseAllControllersExceptCurrent();
      }

      // Preparar controlador para o vídeo atual - isso já lida com cache
      CachedVideoPlayerPlusController? controller;
      try {
        controller = await prepareVideoAtIndex(index, highPriority: true)
            .timeout(Duration(seconds: 8), onTimeout: () {
          print('ReelsController: Timeout ao preparar vídeo $index');
          // Tentar uma vez mais com qualidade reduzida
          isLowMemoryMode.value = true;
          return null;
        });
      } catch (e) {
        // Verificar se é erro de memória
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('memory') || errorMsg.contains('no_memory')) {
          print(
              'ReelsController: Erro de memória ao preparar vídeo $index, tentando recuperar');
          _memoryErrorCount++;
          isLowMemoryMode.value = true;

          // Limpar recursos e tentar novamente com qualidade baixa
          await _forceReleaseAllControllersExceptCurrent();
          await _clearSystemCache();
          await Future.delayed(Duration(milliseconds: 500));

          // Tentar novamente com alta prioridade
          controller = await prepareVideoAtIndex(index, highPriority: true);
        }
      }

      // Iniciar reprodução se temos um controlador válido
      if (controller != null && controller.value.isInitialized) {
        // Pausar vídeos anteriores
        await pauseAllVideos();

        // Reproduzir este vídeo
        await controller.play();
        isPlaying.value = true;
      } else {
        // Se falhou, tentar chamar o tratador de erros
        await handleVideoError(index);
      }

      // Pré-carregar próximo vídeo em segundo plano depois de um intervalo
      // para evitar competição por recursos
      Future.delayed(Duration(milliseconds: 1000), () {
        if (currentVideoIndex.value == index) {
          // Verificar se ainda estamos neste índice
          _preloadNextVideos(index);
        }
      });

      // Verificar se precisamos carregar mais vídeos
      if (index >= videos.length - 3 && !_isLoadingMore) {
        // Usar um pequeno atraso para não competir com o carregamento atual
        Future.delayed(Duration(milliseconds: 2000), () {
          loadMoreVideos();
        });
      }

      // Salvar o vídeo atual para retorno posterior do usuário
      if (index >= 0 &&
          index < videos.length &&
          videos[index].objectId != null) {
        _postsService.saveLastViewedVideo(videos[index].objectId!);
      }
    } catch (e) {
      print('ReelsController: Erro em onPageChanged: $e');

      // Tentar recuperar em caso de erro
      Future.delayed(Duration(milliseconds: 500), () {
        handleVideoError(index);
      });
    }
  }

  /// Método para pular para trás em um vídeo
  Future<void> skipBackward(int index, int seconds) async {
    if (index < 0 || index >= videos.length) {
      print('ReelsController: Índice inválido para pular para trás: $index');
      return;
    }

    final video = videos[index];
    final videoUrl = video.getVideo?.url;
    if (videoUrl == null) return;

    if (_videoControllers.containsKey(videoUrl)) {
      final controller = _videoControllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        final currentPosition = controller.value.position;
        final newPosition = currentPosition - Duration(seconds: seconds);
        // Garantir que não pulamos para um tempo negativo
        final targetPosition =
            newPosition.inMilliseconds < 0 ? Duration.zero : newPosition;
        await controller.seekTo(targetPosition);
        print('ReelsController: Vídeo pulado para trás $seconds segundos');
      }
    }
  }

  /// Método para pular para frente em um vídeo
  Future<void> skipForward(int index, int seconds) async {
    if (index < 0 || index >= videos.length) {
      print('ReelsController: Índice inválido para pular para frente: $index');
      return;
    }

    final video = videos[index];
    final videoUrl = video.getVideo?.url;
    if (videoUrl == null) return;

    if (_videoControllers.containsKey(videoUrl)) {
      final controller = _videoControllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        final currentPosition = controller.value.position;
        final duration = controller.value.duration;
        final newPosition = currentPosition + Duration(seconds: seconds);
        // Garantir que não pulamos além da duração
        final targetPosition = newPosition > duration
            ? duration - Duration(milliseconds: 500)
            : newPosition;
        await controller.seekTo(targetPosition);
        print('ReelsController: Vídeo pulado para frente $seconds segundos');
      }
    }
  }

  /// Define a duração da barra de progresso
  void setProgressBarDuration(int seconds) {
    progressBarDurationSeconds.value = seconds;
    print(
        'ReelsController: Duração da barra de progresso definida para $seconds segundos');
  }

  // Verifica se o dispositivo está com pouca memória
  Future<bool> _checkMemoryPressure() async {
    try {
      // Em iOS/Android podemos verificar métricas específicas da plataforma
      // Esta é uma implementação simulada para demonstração

      // Verificar número de controladores ativos como proxy para uso de memória
      final int activeControllers = _videoControllers.length;

      // Se temos muitos controladores ativos, considerar como pressão de memória
      _isMemoryLow = activeControllers > 5 || _droppedFrames.value > 60;

      // Ativar modo de baixa memória se necessário
      if (_isMemoryLow && !isLowMemoryMode.value) {
        print("ReelsController: Ativando modo de baixa memória");
        isLowMemoryMode.value = true;

        // Liberar todos os controladores exceto o atual para recuperar memória
        _forceReleaseAllControllersExceptCurrent();
      } else if (!_isMemoryLow && isLowMemoryMode.value) {
        // Condições melhoraram, desativar modo de baixa memória
        print("ReelsController: Desativando modo de baixa memória");
        isLowMemoryMode.value = false;
      }

      return _isMemoryLow;
    } catch (e) {
      print("ReelsController: Erro ao verificar pressão de memória: $e");
      return true; // Em caso de erro, assumir que há pressão de memória
    }
  }

  /// Método mais agressivo para liberar memória em caso de erros de falta de memória
  Future<void> _forceReleaseAllControllersExceptCurrent() async {
    try {
      if (videos.isEmpty ||
          currentVideoIndex.value < 0 ||
          currentVideoIndex.value >= videos.length) {
        return;
      }

      final String? currentVideoUrl =
          videos[currentVideoIndex.value].getVideo?.url;
      if (currentVideoUrl == null) return;

      // Pausar todos os vídeos primeiro
      await pauseAllVideos();

      // Liberar todos os controladores exceto o atual
      final List<String> keysToRemove = [];

      _videoControllers.forEach((url, controller) {
        if (url != currentVideoUrl) {
          keysToRemove.add(url);
        }
      });

      // Remover os controladores
      for (final id in keysToRemove) {
        try {
          final controller = _videoControllers[id];
          if (controller != null) {
            await controller.dispose();
          }
        } catch (e) {
          print("ReelsController: Erro ao liberar controlador $id: $e");
        } finally {
          _videoControllers.remove(id);
        }
      }

      // Liberar memória adicional
      _controllerLoadOrder.clear();
      if (currentVideoUrl.isNotEmpty) {
        _controllerLoadOrder.add(currentVideoUrl);
      }

      // Forçar coleta de lixo
      PaintingBinding.instance.imageCache.clear();
      print(
          "ReelsController: Liberação forçada - ${keysToRemove.length} controladores liberados");

      // Em caso de problemas severos de memória, também limpar cache do sistema
      if (isLowMemoryMode.value) {
        _clearSystemCache();
      }
    } catch (e) {
      print("ReelsController: Erro na liberação forçada de controladores: $e");
    }
  }

  /// Método para limpar o cache do sistema em caso de problemas severos de memória
  Future<void> _clearSystemCache() async {
    try {
      // Limpar cache de imagens do Flutter
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Limpar cache permanente e temporário
      await _cacheManager.clearCache();

      // Forçar coleta de lixo (não funciona diretamente, mas pode ajudar)
      // ignore: unused_local_variable
      const int memoryHungry = 1024 * 1024; // 1MB
      // ignore: unused_local_variable, prefer_final_locals
      var list = <int>[];
      try {
        list = List<int>.filled(memoryHungry, 0);
        list.clear();
      } catch (e) {
        // Ignorar erro, isso é apenas para forçar GC
      }
      list = [];

      print("ReelsController: Cache do sistema limpo para recuperar memória");
    } catch (e) {
      print("ReelsController: Erro ao limpar cache do sistema: $e");
    }
  }

  /// Método para lidar com erros de vídeo
  Future<void> handleVideoError(int index) async {
    try {
      // Incrementar contador de erros
      _memoryErrorCount++;

      print(
          'ReelsController: Tentando recuperar de erro de vídeo no índice $index');

      // Se tivermos muitos erros consecutivos, tentar pular para o próximo vídeo
      if (_memoryErrorCount > 2) {
        print(
            'ReelsController: Múltiplos erros, tentando pular para o próximo vídeo');

        // Resetar contador
        _memoryErrorCount = 0;

        // Verificar se podemos avançar para o próximo vídeo
        if (index + 1 < _videos.length) {
          currentVideoIndex.value = index + 1;
          await prepareVideoAtIndex(index + 1);
          await playCurrentVideo();
          return;
        }
      }

      // Tentar reproduzir com baixa qualidade após um breve atraso
      await Future.delayed(Duration(milliseconds: 500));

      // Limpar recursos
      await _forceReleaseAllControllersExceptCurrent();

      // Re-preparar o vídeo priorizando baixa qualidade
      CachedVideoPlayerPlusController? controller =
          await prepareVideoAtIndex(index, highPriority: true);

      if (controller != null) {
        await controller.play();
        isPlaying.value = true;
      } else {
        print('ReelsController: Não foi possível recuperar de erro de vídeo');
      }
    } catch (e) {
      print('ReelsController: Falha ao recuperar de erro de vídeo: $e');

      // Em caso de falha crítica, tentar reiniciar todo o controlador
      if (currentVideoIndex.value >= 0 &&
          currentVideoIndex.value < _videos.length) {
        try {
          // Limpar todos os controladores
          for (final controller in _videoControllers.values) {
            await controller.dispose();
          }
          _videoControllers.clear();

          // Reiniciar com o vídeo atual
          await prepareVideoAtIndex(currentVideoIndex.value);
          await playCurrentVideo();
        } catch (e2) {
          print('ReelsController: Falha na recuperação crítica: $e2');
        }
      }
    }
  }

  /// Verifica se o dispositivo está sob pressão de memória
  bool _isUnderMemoryPressure() {
    // Simplificada - apenas verifica número de controladores
    return _videoControllers.length > 3 || _memoryErrorCount > 0;
  }

  /// Libera todos os controladores exceto o atual
  Future<void> _releaseAllControllersExceptCurrent() async {
    try {
      if (currentVideoIndex.value < 0 ||
          currentVideoIndex.value >= videos.length) {
        return;
      }

      final currentVideo = videos[currentVideoIndex.value];
      final currentVideoUrl = currentVideo.getVideo?.url;

      if (currentVideoUrl == null) return;

      // Lista de URLs para remover
      final urlsToRemove = <String>[];

      // Coletar URLs para remover (exceto o atual e seus adjacentes)
      for (final url in _videoControllers.keys) {
        if (url != currentVideoUrl) {
          // Manter apenas vídeos adjacentes (anterior e próximo)
          bool isAdjacent = false;

          if (currentVideoIndex.value > 0) {
            final prevVideo = videos[currentVideoIndex.value - 1];
            if (prevVideo.getVideo?.url == url) {
              isAdjacent = true;
            }
          }

          if (currentVideoIndex.value < videos.length - 1) {
            final nextVideo = videos[currentVideoIndex.value + 1];
            if (nextVideo.getVideo?.url == url) {
              isAdjacent = true;
            }
          }

          if (!isAdjacent) {
            urlsToRemove.add(url);
          }
        }
      }

      // Remover controladores não essenciais
      for (final url in urlsToRemove) {
        try {
          final controller = _videoControllers[url];
          if (controller != null) {
            await controller.dispose();
          }
          _videoControllers.remove(url);
        } catch (e) {
          print('ReelsController: Erro ao liberar controlador: $e');
        }
      }

      print('ReelsController: ${urlsToRemove.length} controladores liberados');

      // Limpar cache de memória
      PaintingBinding.instance.imageCache.clear();
    } catch (e) {
      print('ReelsController: Erro ao liberar controladores: $e');
    }
  }

  /// Prepara um vídeo específico para reprodução com tratamento de erros melhorado
  Future<CachedVideoPlayerPlusController?> prepareVideoAtIndex(int index,
      {bool highPriority = false}) async {
    if (index < 0 || index >= _videos.length) {
      print(
          'ReelsController: Índice $index fora dos limites (0-${_videos.length - 1})');
      return null;
    }

    final video = _videos[index];
    final videoUrl = video.getVideo?.url;

    if (videoUrl == null) {
      print('ReelsController: URL nula para o vídeo no índice $index');
      return null;
    }

    print(
        'ReelsController: Preparando vídeo em $index: ${videoUrl.substring(0, min(videoUrl.length, 50))}...');

    // Verificar se já existe um controlador inicializado para este URL
    if (_videoControllers.containsKey(videoUrl)) {
      try {
        final existingController = _videoControllers[videoUrl];
        if (existingController != null &&
            existingController.value.isInitialized &&
            !existingController.value.hasError) {
          // Verificar se o controlador não está descartado
          existingController.addListener(() {});
          existingController.removeListener(() {});

          print('ReelsController: Controlador já existe para $index, reusando');
          return existingController;
        } else {
          // Remover controlador inválido
          if (existingController != null) {
            try {
              await existingController.dispose();
            } catch (e) {
              // Ignorar erros ao tentar descartar um controlador já descartado
            }
          }
          _videoControllers.remove(videoUrl);
        }
      } catch (e) {
        // Controlador provavelmente descartado, remover
        print('ReelsController: Erro ao verificar controlador existente: $e');
        _videoControllers.remove(videoUrl);
      }
    }

    try {
      // Verificar memória disponível antes de inicializar
      final bool lowMemory = await _checkLowMemory();
      if (lowMemory && !highPriority) {
        print(
            'ReelsController: Pressão de memória detectada, descarregando controladores não essenciais');
        await _releaseAllControllersExceptCurrent();
      }

      print(
          'ReelsController: Criando controlador para o vídeo $index com URL: $videoUrl');

      // Verificar se o controlador já existe no mapa para evitar criar duplicatas
      if (_videoControllers.containsKey(videoUrl)) {
        _videoControllers.remove(videoUrl);
      }

      // Criar o controlador com opções otimizadas para economia de memória
      final controller = CachedVideoPlayerPlusController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true, // Permitir outros sons
          allowBackgroundPlayback: false, // Pausar em background
        ),
        // Forçar baixa qualidade para evitar problemas de memória
        httpHeaders: {'Accept': '*/*'},
      );

      // Adicionar ao mapa de controladores imediatamente para evitar inicializações duplicadas
      _videoControllers[videoUrl] = controller;

      // Inicializar com timeout e verificar resultado
      bool initializationSuccessful = false;
      try {
        await controller.initialize().timeout(
          Duration(seconds: 15),
          onTimeout: () {
            print('ReelsController: TIMEOUT ao inicializar vídeo $index');
            throw TimeoutException('Tempo esgotado ao inicializar vídeo.');
          },
        );
        // Se chegou aqui sem erros, a inicialização foi bem-sucedida
        initializationSuccessful = true;
      } catch (e) {
        print(
            'ReelsController: Erro durante inicialização do vídeo $index: $e');

        // Se falhar na inicialização, tentar remover do mapa
        try {
          if (_videoControllers.containsKey(videoUrl)) {
            await _videoControllers[videoUrl]?.dispose();
            _videoControllers.remove(videoUrl);
          }
        } catch (disposeError) {
          print(
              'ReelsController: Erro ao descartar controlador com falha: $disposeError');
        }

        return null;
      }

      // Se inicializado com sucesso
      if (initializationSuccessful && controller.value.isInitialized) {
        print(
            'ReelsController: Vídeo $index inicializado com sucesso (duração: ${controller.value.duration.inSeconds}s)');

        // Garantir loop
        controller.setLooping(true);

        // Se for o vídeo atual, reproduzir
        if (index == currentVideoIndex.value) {
          controller.play();
        }

        return controller;
      } else {
        print('ReelsController: Falha ao inicializar vídeo $index');

        // Tentar descartar controlador não inicializado
        try {
          if (_videoControllers.containsKey(videoUrl)) {
            await _videoControllers[videoUrl]?.dispose();
            _videoControllers.remove(videoUrl);
          }
        } catch (e) {
          // Ignorar erros de dispose
        }

        return null;
      }
    } catch (e) {
      print('ReelsController: Erro ao preparar vídeo $index: $e');

      // Remover controlador com erro
      if (_videoControllers.containsKey(videoUrl)) {
        try {
          await _videoControllers[videoUrl]?.dispose();
        } catch (_) {}
        _videoControllers.remove(videoUrl);
      }

      return null;
    }
  }

  /// Verificar se o dispositivo está com pouca memória
  Future<bool> _checkLowMemory() async {
    try {
      // Verificar aproximadamente baseado no número de controladores ativos
      bool tooManyControllers = _videoControllers.length > 3;

      // Verificar usando WidgetsBinding para verificar memória de imagem
      final imageCache = PaintingBinding.instance.imageCache;
      int currentCacheSize = imageCache.currentSizeBytes;
      bool imageCacheUnderPressure =
          currentCacheSize > 50 * 1024 * 1024; // 50MB

      return tooManyControllers || imageCacheUnderPressure;
    } catch (e) {
      print('ReelsController: Erro ao verificar memória: $e');
      return false;
    }
  }

  /// Extrai a URL do vídeo do modelo
  String _getVideoUrl(PostsModel video) {
    if (video.getVideo?.url != null) {
      return video.getVideo!.url!;
    }
    return '';
  }

  /// Método para remover duplicatas de uma lista de vídeos
  List<PostsModel> _removerDuplicatas(List<PostsModel> listaVideos) {
    final Set<String> objectIdsProcessados = {};
    final List<PostsModel> videosUnicos = [];

    for (var video in listaVideos) {
      if (video.objectId != null &&
          !objectIdsProcessados.contains(video.objectId)) {
        objectIdsProcessados.add(video.objectId!);
        videosUnicos.add(video);
      }
    }

    return videosUnicos;
  }

  // Atualiza métricas de carregamento para análise de desempenho
  void _updateLoadingMetrics(double loadTimeInSeconds) {
    if (_averageLoadTime.value == 0) {
      _averageLoadTime.value = loadTimeInSeconds;
    } else {
      // Média móvel ponderada (70% média anterior, 30% novo valor)
      _averageLoadTime.value =
          _averageLoadTime.value * 0.7 + loadTimeInSeconds * 0.3;
    }
  }

  /// Carrega vídeos iniciais
  Future<void> loadInitialVideos({
    bool forceRefresh = false,
    bool showLoading = true,
  }) async {
    if (!Get.isRegistered<PostsService>()) {
      print("ReelsController: PostsService não registrado, registrando agora");
      Get.put(PostsService(), permanent: true);
    }

    final postsService = Get.find<PostsService>();

    if (showLoading) {
      isLoading.value = true;
    }

    print(
        "ReelsController: Carregando vídeos iniciais, forceRefresh=$forceRefresh");

    try {
      // Carregar vídeos diretamente do PostsService
      final videos =
          await postsService.loadInitialVideos(forceRefresh: forceRefresh);

      if (videos.isNotEmpty) {
        print(
            "ReelsController: ${videos.length} vídeos carregados com sucesso");

        // Garantir que os IDs sejam únicos
        final List<PostsModel> uniqueVideos = [];
        final Set<String> processedIds = {};

        for (var video in videos) {
          if (video.objectId != null &&
              !processedIds.contains(video.objectId)) {
            processedIds.add(video.objectId!);
            uniqueVideos.add(video);
          }
        }

        // Atualizar lista diretamente
        _videos.clear();
        _videos.addAll(uniqueVideos);

        // Atualizar UI
        videos.assignAll(uniqueVideos);

        // Garantir que o índice atual é válido
        if (currentVideoIndex.value >= _videos.length) {
          currentVideoIndex.value = 0;
        }

        if (_videos.isNotEmpty) {
          // Preparar o primeiro vídeo
          await prepareVideoAtIndex(currentVideoIndex.value);
        }
      } else {
        print("ReelsController: Nenhum vídeo retornado do servidor");
      }
    } catch (e) {
      print("ReelsController: Erro ao carregar vídeos: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Pré-carrega vídeos à frente do índice atual
  Future<void> _preloadVideosAhead(int currentIndex) async {
    if (_videos.isEmpty) return;

    try {
      // Determinar quantos vídeos pré-carregar à frente
      for (int i = 1; i <= _preloadAheadCount; i++) {
        int indexToPreload = currentIndex + i;

        // Verificar se o índice é válido
        if (indexToPreload < 0 || indexToPreload >= _videos.length) continue;

        // Pré-carregar vídeo com prioridade decrescente
        final video = _videos[indexToPreload];
        if (video.getVideo?.url != null) {
          print('ReelsController: Pré-carregando vídeo $indexToPreload');
          await prepareVideoAtIndex(indexToPreload, highPriority: i <= 2);
        }
      }
    } catch (e) {
      print('ReelsController: Erro ao pré-carregar vídeos: $e');
    }
  }

  /// Método para reproduzir um vídeo em tela cheia
  Future<void> playFullscreenVideo(int index) async {
    try {
      if (index < 0 || index >= _videos.length) {
        print('ReelsController: Índice inválido para reprodução em tela cheia');
        return;
      }

      final video = _videos[index];
      final videoUrl = video.getVideo?.url;

      if (videoUrl == null) {
        print('ReelsController: URL nula para o vídeo no índice $index');
        return;
      }

      // Obter ou criar controlador
      CachedVideoPlayerPlusController? controller;

      try {
        // Verificar se já existe um controlador
        if (_videoControllers.containsKey(videoUrl) &&
            _videoControllers[videoUrl]!.value.isInitialized) {
          controller = _videoControllers[videoUrl];
        } else {
          // Criar novo com prioridade alta
          controller = await prepareVideoAtIndex(index, highPriority: true);
        }

        if (controller == null) {
          print(
              'ReelsController: Não foi possível obter controlador para tela cheia');
          return;
        }

        // Pausar todos os vídeos
        await pauseAllVideos();

        // Iniciar reprodução do vídeo selecionado
        await controller.play();
        isPlaying.value = true;
      } catch (e) {
        print('ReelsController: Erro ao preparar vídeo para tela cheia: $e');

        // Tentar liberar memória e criar novamente com baixa qualidade
        await _forceReleaseAllControllersExceptCurrent();
        await _clearSystemCache();

        // Tentar novamente após um breve atraso
        await Future.delayed(Duration(milliseconds: 500));
        controller = await prepareVideoAtIndex(index, highPriority: true);
      }
    } catch (e) {
      print('ReelsController: Erro em playFullscreenVideo: $e');
    }
  }
}
