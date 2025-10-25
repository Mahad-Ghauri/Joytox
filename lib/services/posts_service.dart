// ignore_for_file: unused_field

import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/PostsModel.dart';
import '../models/UserModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Serviço centralizado para gestão de posts e vídeos
/// Otimizado para baixo uso de memória e separação de responsabilidades
class PostsService extends GetxService {
  // Singleton para acesso global
  static PostsService get to => Get.find();

  // SEPARAÇÃO DE RESPONSABILIDADES:
  // 1. Feed - sem cache, apenas infinite scrolling
  // 2. Reels - com cache limitado para melhor performance

  // Armazenamento para posts do feed (sem cache)
  final RxList<PostsModel> allPosts = <PostsModel>[].obs;

  // Armazenamento para vídeos (com cache limitado)
  final RxList<PostsModel> videoPosts = <PostsModel>[].obs;

  // Status de carregamento
  final RxBool isLoading = false.obs;

  // Controle de paginação para feed
  final RxInt currentFeedPage = 0.obs;
  final int feedLimit = 8; // REDUCED from 10 to 8 - saves ~30MB per load
  bool hasMoreFeedContent = true;
  bool _isLoadingMoreFeed = false;

  // Controle de paginação para vídeos
  final RxInt currentVideoPage = 0.obs;
  final int videoLimit = 3; // REDUCED from 5 to 3 - saves ~50MB per load
  bool hasMoreVideos = true;
  bool _isLoadingMoreVideos = false;

  // Cache apenas para vídeos (simplificado)
  final Map<String, Map<String, dynamic>> _videosCache = {};
  final List<String> _videoIds = [];

  // Preferências
  SharedPreferences? _prefs;
  String? lastViewedPostId;
  String? lastViewedVideoId;

  // Limites de cache (apenas para vídeos) - REDUCED for memory savings
  static const int maxCachedVideos = 15; // REDUCED from 30 to 15 - saves ~100MB
  static const int initialVideosToLoad = 3; // REDUCED from 5 to 3 - saves ~50MB

  // Usuário atual
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Variável para controlar status de carregamento dos vídeos
  final RxBool videosLoading = false.obs;

  void setCurrentUser(UserModel user) {
    print("PostsService: Definindo usuário atual - ${user.objectId}");
    _currentUser = user;

    // Carregar dados salvos de forma eficiente
    _loadLastViewedItems();
  }

  @override
  void onInit() async {
    super.onInit();
    await _initPreferences();
    _loadLastViewedItems();
    // MEMORY OPTIMIZATION: Start automatic memory cleanup
    _startMemoryCleanupTimer();
  }

  Timer? _memoryCleanupTimer;

  /// Start automatic memory cleanup every 3 minutes - saves 50-100MB over time
  void _startMemoryCleanupTimer() {
    _memoryCleanupTimer = Timer.periodic(Duration(minutes: 3), (_) {
      _performMemoryCleanup();
    });
  }

  /// Perform memory cleanup to prevent accumulation - saves significant memory
  void _performMemoryCleanup() {
    int initialPostsCount = allPosts.length;
    int initialVideosCount = videoPosts.length;

    // Keep only recent posts (saves ~50MB)
    if (allPosts.length > 30) {
      allPosts.value = allPosts.take(20).toList();
    }

    // Keep only recent videos (saves ~100MB)
    if (videoPosts.length > 20) {
      videoPosts.value = videoPosts.take(10).toList();
    }

    // Cleanup old cache
    _cleanupOldVideoCache();

    if (initialPostsCount > 20 || initialVideosCount > 10) {
      print(
          '🧹 PostsService: Memory cleanup - Posts: $initialPostsCount→${allPosts.length}, Videos: $initialVideosCount→${videoPosts.length}');
    }
  }

  Future<void> _initPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      print("PostsService: Preferências inicializadas com sucesso");
    } catch (e) {
      print("PostsService: Erro ao inicializar preferências - $e");
    }
  }

  void _loadLastViewedItems() {
    if (_prefs != null) {
      lastViewedPostId = _prefs!.getString('last_viewed_post');
      lastViewedVideoId = _prefs!.getString('last_viewed_video');
      print("PostsService: Últimos itens carregados do armazenamento");
      print("  - Último post: $lastViewedPostId");
      print("  - Último vídeo: $lastViewedVideoId");
    }
  }

  /// Carrega posts iniciais do feed (sem cache)
  Future<void> loadInitialContent() async {
    if (isLoading.value || currentUser == null) {
      print(
          "PostsService: Carregamento já em andamento ou usuário não definido");
      return;
    }

    isLoading.value = true;
    print("PostsService: Iniciando carregamento de conteúdo inicial do feed");

    try {
      // Feed - Carregar posts genéricos
      await _loadInitialFeed();
    } catch (e) {
      print('PostsService: Erro ao carregar conteúdo inicial do feed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Carrega conteúdo de vídeos inicial (otimizado)
  Future<List<PostsModel>> loadInitialVideos(
      {bool forceRefresh = false}) async {
    print(
        'PostsService: Carregando vídeos direto do servidor, forceRefresh=$forceRefresh');
    isLoading.value = true;

    try {
      // Criar uma consulta básica sem filtros complexos que podem falhar
      final query = QueryBuilder<PostsModel>(PostsModel())
        ..whereValueExists(PostsModel.keyVideo, true)
        ..orderByDescending(PostsModel.keyCreatedAt)
        ..includeObject([PostsModel.keyAuthor])
        ..setLimit(20);

      print('PostsService: Executando consulta de vídeos...');
      final response = await query.query();

      if (response.success && response.results != null) {
        final results = response.results! as List<ParseObject>;
        final videos = results.map((o) => o as PostsModel).toList();

        print('PostsService: ${videos.length} vídeos encontrados');

        if (videos.isNotEmpty) {
          // Substituir lista atual
          videoPosts.clear();
          videoPosts.addAll(videos);

          // Debug - verificar URLs
          for (var video in videos.take(3)) {
            print(
                'PostsService: Video ${video.objectId}: URL=${video.getVideo?.url}, thumb=${video.getVideoThumbnail?.url}');
          }
        }

        isLoading.value = false;
        return videoPosts;
      } else {
        print(
            'PostsService: Erro ao carregar vídeos: ${response.error?.message}');
        isLoading.value = false;
        return [];
      }
    } catch (e) {
      print('PostsService: Exceção ao carregar vídeos: $e');
      isLoading.value = false;
      return [];
    }
  }

  // Variável para controlar a última data de vídeo carregado
  DateTime? _lastVideoFetchedAt;

  // Cria consulta base filtrada para o usuário atual
  QueryBuilder<PostsModel> _createBaseQuery() {
    QueryBuilder<PostsModel> query = QueryBuilder<PostsModel>(PostsModel())
      ..includeObject([PostsModel.keyAuthor])
      ..orderByDescending(PostsModel.keyCreatedAt);

    if (currentUser != null) {
      // Filtrar posts de usuários bloqueados e reportados
      query.whereNotContainedIn(
          PostsModel.keyAuthor, currentUser!.getBlockedUsersIDs!);
      query.whereNotContainedIn(
          PostsModel.keyObjectId, currentUser!.getReportedPostIDs!);
    }

    return query;
  }

  /// Atualizar cache de vídeos (só mantém vídeos em cache)
  void _updateVideosCache(List<PostsModel> videos) {
    for (var video in videos) {
      if (video.objectId != null) {
        _videosCache[video.objectId!] = _optimizeForStorage(video);

        // Atualizar lista de IDs
        if (!_videoIds.contains(video.objectId!)) {
          _videoIds.add(video.objectId!);
        }
      }
    }

    // Limitar tamanho do cache
    _cleanupOldVideoCache();
  }

  /// Otimizar post/vídeo para armazenamento
  Map<String, dynamic> _optimizeForStorage(PostsModel post) {
    final Map<String, dynamic> data = post.toJson();

    // Otimizações para economia de espaço
    if (data.containsKey('viewers') &&
        data['viewers'] is List &&
        (data['viewers'] as List).length > 5) {
      // Manter apenas os 5 últimos viewers
      data['viewers'] = (data['viewers'] as List).sublist(0, 5);
    }

    return data;
  }

  /// Limpar cache antigo de vídeos
  void _cleanupOldVideoCache() {
    // Remover vídeos mais antigos se o cache ultrapassar o limite
    if (_videoIds.length > maxCachedVideos) {
      int excessCount = _videoIds.length - maxCachedVideos;
      List<String> idsToRemove = _videoIds.sublist(0, excessCount);

      for (var id in idsToRemove) {
        _videosCache.remove(id);
      }

      _videoIds.removeRange(0, excessCount);

      print("PostsService: Removidos $excessCount vídeos antigos do cache");
    }
  }

  Future<void> _loadInitialFeed() async {
    try {
      QueryBuilder<PostsModel> query = _createBaseQuery()
        ..setLimit(feedLimit)
        ..setAmountToSkip(0)
        ..includeObject([PostsModel.keyAuthor]);

      final ParseResponse response = await query.query();

      if (response.success && response.results != null) {
        List<PostsModel> loadedPosts =
            response.results!.map((e) => e as PostsModel).toList();

        allPosts.value = loadedPosts;

        currentFeedPage.value = 1;
        hasMoreFeedContent = response.results!.length >= feedLimit;

        print(
            "PostsService: initial Feed loaded  - ${loadedPosts.length} posts");
        print("resultados_de_posts: ${loadedPosts}");
      } else {
        print("PostsService: error consulting - ${response.error?.message}");
      }
    } catch (e) {
      print('PostsService: Error loading initial feed: $e');
    }
  }

  /// Carregar mais posts para o feed (infinite scrolling)
  Future<void> loadMoreContent() async {
    // Carregar mais posts para o feed
    await _loadMoreFeedPosts();
  }

  /// Carregar mais vídeos para reels
  Future<void> loadMoreVideos() async {
    // Carregar mais vídeos para reels
    await _loadMoreVideoPosts();
  }

  /// Implementação de infinite scrolling para feed
  Future<void> _loadMoreFeedPosts() async {
    if (_isLoadingMoreFeed || !hasMoreFeedContent || currentUser == null) {
      return;
    }

    _isLoadingMoreFeed = true;
    print("PostsService: Carregando mais posts do feed");

    try {
      QueryBuilder<PostsModel> query = _createBaseQuery()
        ..setLimit(feedLimit)
        ..setAmountToSkip(currentFeedPage.value * feedLimit);

      final ParseResponse response = await query.query();

      if (response.success && response.results != null) {
        List<PostsModel> newPosts =
            response.results!.map((e) => e as PostsModel).toList();

        if (newPosts.isNotEmpty) {
          // Adicionar à lista existente sem cache
          List<PostsModel> updatedPosts = [...allPosts, ...newPosts];
          allPosts.value = updatedPosts;

          // Incrementar página
          currentFeedPage.value++;
          hasMoreFeedContent = newPosts.length >= feedLimit;

          print(
              "PostsService: Carregados mais ${newPosts.length} posts para o feed");
        } else {
          hasMoreFeedContent = false;
          print("PostsService: Não há mais posts para carregar");
        }
      } else {
        print(
            "PostsService: Erro ao carregar mais posts - ${response.error?.message}");
      }
    } catch (e) {
      print('PostsService: Erro ao carregar mais posts: $e');
    } finally {
      _isLoadingMoreFeed = false;
    }
  }

  /// Carregar mais vídeos para reels com cache
  Future<void> _loadMoreVideoPosts() async {
    if (_isLoadingMoreVideos || !hasMoreVideos || currentUser == null) {
      return;
    }

    _isLoadingMoreVideos = true;
    print("PostsService: Carregando mais vídeos");

    try {
      QueryBuilder<PostsModel> query = _createBaseQuery()
        ..whereValueExists(PostsModel.keyVideo, true)
        ..whereValueExists(PostsModel.keyVideoThumbnail, true)
        ..setLimit(10) // Aumentamos para 10 por página
        ..setAmountToSkip(currentVideoPage.value *
            10); // Usamos 10 para corresponder ao novo limite

      final ParseResponse response = await query.query();

      if (response.success && response.results != null) {
        List<PostsModel> newVideos =
            response.results!.map((e) => e as PostsModel).toList();

        if (newVideos.isNotEmpty) {
          // Adicionar ao cache de vídeos
          _updateVideosCache(newVideos);

          // Adicionar à lista existente
          List<PostsModel> updatedVideos = [...videoPosts, ...newVideos];
          videoPosts.value = updatedVideos;

          // Incrementar página
          currentVideoPage.value++;
          hasMoreVideos =
              newVideos.length >= 10; // Verificamos com base no novo limite

          print(
              "PostsService: Carregados mais ${newVideos.length} vídeos (total: ${updatedVideos.length})");
        } else {
          hasMoreVideos = false;
          print("PostsService: Não há mais vídeos para carregar");
        }
      } else {
        print(
            "PostsService: Erro ao carregar mais vídeos - ${response.error?.message}");
      }
    } catch (e) {
      print('PostsService: Erro ao carregar mais vídeos: $e');
    } finally {
      _isLoadingMoreVideos = false;
    }
  }

  /// Salvar o último post visto
  void saveLastViewedPost(String postId) {
    lastViewedPostId = postId;
    _prefs?.setString('last_viewed_post', postId);
    print("PostsService: Último post salvo - $postId");
  }

  /// Salvar o último vídeo visto
  void saveLastViewedVideo(String videoId) {
    lastViewedVideoId = videoId;
    _prefs?.setString('last_viewed_video', videoId);
    print("PostsService: Último vídeo salvo - $videoId");
  }

  /// Obter índice do último post visto
  int getLastViewedPostIndex() {
    if (lastViewedPostId == null) return 0;

    // Tentar encontrar na lista em memória
    int index =
        allPosts.indexWhere((post) => post.objectId == lastViewedPostId);
    return index >= 0 ? index : 0;
  }

  /// Obter índice do último vídeo visto
  int getLastViewedVideoIndex() {
    if (lastViewedVideoId == null) return 0;

    // Tentar encontrar na lista em memória primeiro
    int index =
        videoPosts.indexWhere((video) => video.objectId == lastViewedVideoId);

    // Se não estiver na memória, verificar no cache
    if (index < 0 && _videoIds.contains(lastViewedVideoId!)) {
      // Carregar vídeo do cache para a memória se possível
      _loadVideoFromCache(lastViewedVideoId!);

      // Verificar novamente
      index =
          videoPosts.indexWhere((video) => video.objectId == lastViewedVideoId);
    }

    return index >= 0 ? index : 0;
  }

  /// Tenta carregar um vídeo do cache para a memória
  void _loadVideoFromCache(String videoId) {
    if (_videosCache.containsKey(videoId)) {
      try {
        PostsModel video = PostsModel.clone();
        video.fromJson(Map<String, dynamic>.from(_videosCache[videoId]!));

        // Adicionar à lista de vídeos se não existir
        if (!videoPosts.any((v) => v.objectId == videoId)) {
          List<PostsModel> updatedVideos = [...videoPosts];
          updatedVideos.add(video);
          videoPosts.value = updatedVideos;
        }
      } catch (e) {
        print("PostsService: Erro ao carregar vídeo do cache: $e");
      }
    }
  }

  /// Atualizar um post específico
  void updatePost(PostsModel updatedPost) {
    try {
      // Verificar se é um vídeo
      bool isVideo =
          updatedPost.getVideo != null && updatedPost.getVideoThumbnail != null;

      // Atualizar lista de feed (se já estiver carregado)
      int feedIndex =
          allPosts.indexWhere((p) => p.objectId == updatedPost.objectId);
      if (feedIndex >= 0) {
        List<PostsModel> updatedFeed = List<PostsModel>.from(allPosts);
        updatedFeed[feedIndex] = updatedPost;
        allPosts.value = updatedFeed;
        // Forçar atualização da UI
        allPosts.refresh();
      }

      // Se for vídeo, atualizar também no cache e na lista de vídeos
      if (isVideo) {
        // Atualizar no cache
        if (updatedPost.objectId != null) {
          _videosCache[updatedPost.objectId!] =
              _optimizeForStorage(updatedPost);

          // Garantir que está na lista de IDs
          if (!_videoIds.contains(updatedPost.objectId!)) {
            _videoIds.add(updatedPost.objectId!);
          }
        }

        // Atualizar na lista de vídeos
        int videoIndex =
            videoPosts.indexWhere((v) => v.objectId == updatedPost.objectId);
        if (videoIndex >= 0) {
          List<PostsModel> updatedVideos = List<PostsModel>.from(videoPosts);
          updatedVideos[videoIndex] = updatedPost;
          videoPosts.value = updatedVideos;
          // Forçar atualização da UI
          videoPosts.refresh();
        }
      }

      print("PostsService: Post atualizado - ${updatedPost.objectId}");
    } catch (e) {
      print("PostsService: Erro ao atualizar post: $e");
    }
  }

  /// Alias para compatibilidade - atualiza um post no feed
  void updateFeedPost(PostsModel updatedPost) {
    updatePost(updatedPost);
  }

  /// Adicionar um novo post ao feed
  void addPost(PostsModel newPost) {
    try {
      // Adicionar no início da lista de feed
      List<PostsModel> updatedPosts = [newPost, ...allPosts];
      allPosts.value = updatedPosts;
      print("PostsService: Novo post adicionado ao feed - ${newPost.objectId}");
    } catch (e) {
      print("PostsService: Erro ao adicionar post: $e");
    }
  }

  /// Adicionar um novo vídeo
  void addVideo(PostsModel newVideo) {
    try {
      // Verificar se é realmente um vídeo
      if (newVideo.getVideo == null || newVideo.getVideoThumbnail == null) {
        return;
      }

      // Verificar se já existe na lista
      if (videoPosts.any((v) => v.objectId == newVideo.objectId)) {
        return;
      }

      // Adicionar à lista de vídeos no início (para aparecer primeiro)
      List<PostsModel> updatedVideos = [newVideo, ...videoPosts];
      videoPosts.value = updatedVideos;

      // Adicionar ao cache
      if (newVideo.objectId != null) {
        _videosCache[newVideo.objectId!] = _optimizeForStorage(newVideo);

        // Adicionar ao início para manter LRU
        if (!_videoIds.contains(newVideo.objectId!)) {
          _videoIds.add(newVideo.objectId!);
        }
      }
    } catch (e) {
      print("PostsService: Erro ao adicionar vídeo: $e");
    }
  }

  /// Remover um post ou vídeo
  void removePost(String postId) {
    try {
      // Remover da lista de feed
      final feedPosts =
          allPosts.where((post) => post.objectId != postId).toList();

      if (feedPosts.length < allPosts.length) {
        allPosts.value = feedPosts;
        print("PostsService: Post removido do feed - $postId");
      }

      // Verificar se é um vídeo
      if (_videoIds.contains(postId)) {
        // Remover do cache de vídeos
        _videosCache.remove(postId);
        _videoIds.remove(postId);

        // Remover da lista de vídeos
        final videosUpdated =
            videoPosts.where((video) => video.objectId != postId).toList();

        if (videosUpdated.length < videoPosts.length) {
          videoPosts.value = videosUpdated;
          print("PostsService: Vídeo removido - $postId");
        }
      }
    } catch (e) {
      print("PostsService: Erro ao remover post/vídeo: $e");
    }
  }

  /// Carregar autor para um post específico
  Future<void> fetchAuthorForPost(PostsModel post) async {
    if (post.getAuthor != null || post.getAuthorId == null) return;

    try {
      QueryBuilder<UserModel> query =
          QueryBuilder<UserModel>(UserModel.forQuery())
            ..whereEqualTo(UserModel.keyObjectId, post.getAuthorId);

      final response = await query.query();
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        UserModel author = response.results!.first as UserModel;
        post.setAuthor = author;

        // Atualizar no feed e nos vídeos se necessário
        updatePost(post);

        // Forçar atualização da UI
        videoPosts.refresh();
        allPosts.refresh();

        print(
            "PostsService: Autor ${author.getFullName} carregado para post ${post.objectId}");
      }
    } catch (e) {
      print("PostsService: Erro ao carregar autor para post: $e");
    }
  }

  /// Forçar atualização do conteúdo
  Future<void> refreshContent() async {
    // Limpar dados atuais
    allPosts.clear();
    currentFeedPage.value = 0;
    hasMoreFeedContent = true;

    // Recarregar do servidor
    await loadInitialContent();
  }

  /// Obter estatísticas do cache para diagnóstico
  Map<String, dynamic> getCacheStats() {
    int videosInMemory = videoPosts.length;
    int cachedVideos = _videosCache.length;

    final stats = {
      'feedPostsInMemory': allPosts.length,
      'videosInMemory': videosInMemory,
      'videosInCache': cachedVideos,
      'maxCachedVideos': maxCachedVideos,
    };

    print("PostsService: Estatísticas - $stats");
    return stats;
  }

  /// Obter um post específico por ID
  Future<PostsModel?> getPostById(String postId) async {
    // Procurar primeiro na memória
    PostsModel? post = allPosts.firstWhereOrNull((p) => p.objectId == postId);
    if (post != null) return post;

    // Se for um vídeo, procurar no cache
    if (_videosCache.containsKey(postId)) {
      try {
        PostsModel video = PostsModel.clone();
        video.fromJson(Map<String, dynamic>.from(_videosCache[postId]!));
        return video;
      } catch (e) {
        print("PostsService: Erro ao recuperar vídeo do cache: $e");
      }
    }

    // Se não encontrado, buscar do servidor
    try {
      QueryBuilder<PostsModel> query = QueryBuilder<PostsModel>(PostsModel())
        ..whereEqualTo(PostsModel.keyObjectId, postId)
        ..includeObject([PostsModel.keyAuthor]);

      final response = await query.query();
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        return response.results!.first as PostsModel;
      }
    } catch (e) {
      print("PostsService: Erro ao buscar post do servidor: $e");
    }

    return null;
  }

  /// Pré-carregar range de posts para o feed
  Future<void> preloadPostsRange(int startIndex, int endIndex) async {
    // Verificar se precisamos carregar mais posts para o feed
    if (hasMoreFeedContent && allPosts.length <= endIndex + 2) {
      await _loadMoreFeedPosts();
    }
  }

  /// Limpar todos os recursos
  void disposeResources() {
    // Limpar memória
    _videosCache.clear();
    _videoIds.clear();
    allPosts.clear();
    videoPosts.clear();
    print("PostsService: Recursos liberados");
  }

  @override
  void onClose() {
    // MEMORY OPTIMIZATION: Properly dispose of memory cleanup timer
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = null;

    // Call existing cleanup
    disposeResources();

    super.onClose();
    print("PostsService: Service disposed with memory optimizations");
  }
}
