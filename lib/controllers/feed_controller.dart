import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/PostsModel.dart';
import '../models/UserModel.dart';
import '../models/NotificationsModel.dart';
import '../models/CommentsModel.dart';
import '../helpers/quick_actions.dart';
import '../models/ReportModel.dart';
import '../services/posts_service.dart';
import 'dart:async';

class FeedController extends GetxController {
  final UserModel currentUser;
  late final PostsService postsService;
  final LiveQuery liveQuery = LiveQuery();
  Subscription? subscription;
  Timer? _refreshTimer;

  // Getter para acessar os posts do PostsService
  RxList<PostsModel> get posts => postsService.allPosts;
  RxBool get isLoading => postsService.isLoading;
  String? get lastViewedPostId => postsService.lastViewedPostId;

  // Controle de pré-carregamento
  bool _preloadingActive = false;
  int _lastPreloadIndex = 0;
  static const int preloadThreshold =
      3; // Pré-carregar quando estiver a 3 posts do fim

  FeedController({required this.currentUser}) {
    // Verificar se o PostsService já está registrado
    if (!Get.isRegistered<PostsService>()) {
      print('FeedController: PostsService não registrado, registrando agora');
      final postsService = PostsService();
      Get.put(postsService, permanent: true);
    }

    // Obter a referência ao serviço
    postsService = Get.find<PostsService>();
  }

  @override
  void onInit() {
    super.onInit();
    // Definir o usuário atual no serviço
    postsService.setCurrentUser(currentUser);

    // Configurar LiveQuery para atualizações em tempo real
    setupLiveQuery();

    // Carregar posts se ainda não foram carregados
    if (postsService.allPosts.isEmpty) {
      postsService.loadInitialContent();
    }

    // Configurar timer para refresh periódico
    _setupRefreshTimer();
  }

  void _setupRefreshTimer() {
    // MEMORY OPTIMIZATION: Reduce posts in memory every 5 minutes
    _refreshTimer = Timer.periodic(Duration(minutes: 5), (_) {
      // Keep only recent posts to save memory (saves ~50-100MB)
      if (posts.length > 50) {
        print(
            '📊 FeedController: Reduced posts from ${posts.length} to 30 for memory optimization');
        // Keep only the most recent 30 posts
        postsService.allPosts.value = posts.take(30).toList();
      }
    });
  }

  @override
  void onClose() {
    disposeLiveQuery();
    _refreshTimer?.cancel();
    super.onClose();
  }

  void saveLastViewedPost(String postId) {
    postsService.saveLastViewedPost(postId);
  }

  Future<int> getLastViewedPostIndex() async {
    return postsService.getLastViewedPostIndex();
  }

  Future<void> loadInitialPosts() async {
    return postsService.loadInitialContent();
  }

  Future<void> loadMorePosts() async {
    return postsService.loadMoreContent();
  }

  void setupLiveQuery() async {
    QueryBuilder<PostsModel> queryBuilderLive =
        QueryBuilder<PostsModel>(PostsModel())
          ..whereEqualTo(PostsModel.keyExclusive, false)
          ..whereNotContainedIn(
              PostsModel.keyAuthorId, currentUser.getBlockedUsersIDs!)
          ..whereNotContainedIn(
              PostsModel.keyObjectId, currentUser.getReportedPostIDs!);

    if (subscription == null) {
      subscription = await liveQuery.client.subscribe(queryBuilderLive);
    }

    subscription!.on(LiveQueryEvent.create, (PostsModel post) async {
      // MEMORY OPTIMIZATION: Only fetch author if not already loaded
      if (post.getAuthor == null && post.getAuthorId != null) {
        await post.getAuthor!.fetch();
      }

      // MEMORY OPTIMIZATION: Skip lastLikeAuthor fetch to save memory and network
      // This information can be loaded on-demand when displaying likes

      // Usar o serviço otimizado para adicionar o novo post
      if (post.getVideo != null && post.getVideoThumbnail != null) {
        // Se for vídeo, não adicionamos ao feed
        // O ReelsController vai gerenciar os vídeos
      } else {
        // Se for post comum, adicionar ao feed
        postsService.addPost(post);
      }
    });

    subscription!.on(LiveQueryEvent.update, (PostsModel post) async {
      // MEMORY OPTIMIZATION: Only fetch author if not already loaded
      if (post.getAuthor == null && post.getAuthorId != null) {
        await post.getAuthor!.fetch();
      }

      // MEMORY OPTIMIZATION: Skip lastLikeAuthor fetch to save memory and network

      // Atualizar apenas posts de feed
      if (post.getVideo == null || post.getVideoThumbnail == null) {
        postsService.updateFeedPost(post);
      }
    });

    subscription!.on(LiveQueryEvent.delete, (PostsModel post) {
      postsService.removePost(post.objectId!);
    });
  }

  void disposeLiveQuery() {
    if (subscription != null) {
      liveQuery.client.unSubscribe(subscription!);
      subscription = null;
    }
  }

  // Método otimizado para alternância de like
  Future<void> toggleLike(PostsModel post) async {
    try {
      if (post.getLikes.contains(currentUser.objectId)) {
        post.removeLike = currentUser.objectId!;
        await _deleteLikeNotification(post);
      } else {
        post.setLikes = currentUser.objectId!;
        post.setLastLikeAuthor = currentUser;
        await _createLikeNotification(post);
      }
      await post.save();

      // Atualizar no cache local também
      postsService.updatePost(post);
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<void> _createLikeNotification(PostsModel post) async {
    await QuickActions.createOrDeleteNotification(
      currentUser,
      post.getAuthor!,
      NotificationsModel.notificationTypeLikedPost,
      post: post,
    );
  }

  Future<void> _deleteLikeNotification(PostsModel post) async {
    QueryBuilder<NotificationsModel> queryBuilder =
        QueryBuilder<NotificationsModel>(NotificationsModel())
          ..whereEqualTo(NotificationsModel.keyAuthor, currentUser)
          ..whereEqualTo(NotificationsModel.keyPost, post);

    ParseResponse parseResponse = await queryBuilder.query();
    if (parseResponse.success && parseResponse.results != null) {
      NotificationsModel notification = parseResponse.results!.first;
      await notification.delete();
    }
  }

  Future<void> createComment(PostsModel post, String text) async {
    CommentsModel comment = CommentsModel()
      ..setAuthor = currentUser
      ..setText = text
      ..setAuthorId = currentUser.objectId!
      ..setPostId = post.objectId!
      ..setPost = post;

    await comment.save();
    await post.save();

    QuickActions.createOrDeleteNotification(
      currentUser,
      post.getAuthor!,
      NotificationsModel.notificationTypeCommentPost,
      post: post,
    );

    // Atualizar post no cache também
    postsService.updatePost(post);
  }

  Future<void> deletePost(PostsModel post) async {
    try {
      await removePostIdOnUser(post.objectId!);
      await post.delete();

      // Remover do cache
      postsService.removePost(post.objectId!);
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  Future<void> removePostIdOnUser(String postId) async {
    currentUser.removePostId = postId;
    await currentUser.save();
  }

  Future<void> reportPost(PostsModel post, String reason) async {
    try {
      currentUser.setReportedPostIDs = post.objectId;
      currentUser.setReportedPostReason = reason;
      await currentUser.save();

      await QuickActions.report(
        type: ReportModel.reportTypePost,
        message: reason,
        accuser: currentUser,
        accused: post.getAuthor!,
        postsModel: post,
      );

      // Remover o post reportado das listas e do cache
      postsService.removePost(post.objectId!);
    } catch (e) {
      print('Error reporting post: $e');
    }
  }

  Future<void> blockUser(UserModel user) async {
    try {
      currentUser.setBlockedUser = user;
      currentUser.setBlockedUserIds = user.objectId!;
      await currentUser.save();

      // Remover posts do usuário bloqueado do cache e da memória
      List<String> postsToRemove = [];

      // Identificar posts para remover da lista em memória
      for (var post in postsService.allPosts) {
        if (post.getAuthorId == user.objectId) {
          postsToRemove.add(post.objectId!);
        }
      }

      // Remover os posts identificados do cache e da memória
      for (var postId in postsToRemove) {
        postsService.removePost(postId);
      }

      print(
          'FeedController: Removidos ${postsToRemove.length} posts do usuário bloqueado');
    } catch (e) {
      print('Error blocking user: $e');
    }
  }

  // Método para buscar o autor de um post
  Future<void> fetchAuthorForPost(PostsModel post) async {
    return postsService.fetchAuthorForPost(post);
  }

  // Método para forçar atualização do feed
  Future<void> refreshFeed() async {
    await postsService.refreshContent();
  }

  // Método para iniciar o pré-carregamento de mais posts
  void startPreloading(int currentIndex) {
    // Evitar múltiplas chamadas de pré-carregamento
    if (_preloadingActive) return;

    // Verificar se estamos próximos do final da lista
    if (posts.length - currentIndex <= preloadThreshold &&
        posts.length > 0 &&
        currentIndex > _lastPreloadIndex) {
      _preloadingActive = true;
      _lastPreloadIndex = currentIndex;

      // Carregar mais posts
      postsService.loadMoreContent().then((_) {
        _preloadingActive = false;
      });

      print(
          'FeedController: Iniciando pré-carregamento de posts a partir do índice $currentIndex');
    }

    // Pré-carregar posts próximos para rolagem mais suave
    int preloadStart = currentIndex - 2 < 0 ? 0 : currentIndex - 2;
    int preloadEnd = currentIndex + 5;

    // Iniciar pré-carregamento em background
    postsService.preloadPostsRange(preloadStart, preloadEnd);
  }

  // Método para obter um post específico
  Future<PostsModel?> getPostById(String postId) async {
    return postsService.getPostById(postId);
  }

  // Método para obter estatísticas do cache
  Map<String, dynamic> getCacheStats() {
    return postsService.getCacheStats();
  }

  // Método para definir o usuário atual
  void setCurrentUser(UserModel user) {
    postsService.setCurrentUser(user);
  }

  // Método para forçar atualização completa do feed
  Future<void> forceFeedRefresh() async {
    return postsService.refreshContent();
  }
}
