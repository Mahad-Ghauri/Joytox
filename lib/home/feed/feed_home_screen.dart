// ignore_for_file: deprecated_member_use, unused_element

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:trace/controllers/feed_controller.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/home/feed/post_type_chooser.dart';
import 'package:trace/home/profile/profile_screen.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/ui/container_with_corner.dart';
import 'package:trace/ui/text_with_tap.dart';
import 'package:trace/utils/colors.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart';
import 'package:trace/widgets/optimized_feed_post.dart';
import 'dart:async';

import '../notifications/notifications_screen.dart';
import '../search/global_search_widget.dart';
import 'comment_post_screen.dart';
import 'edit_pictures_post.dart';
import 'edit_text_post_screen.dart';
import 'edit_video_post.dart';
import 'feed_on_reels_screen.dart';

// ignore: must_be_immutable
class FeedHomeScreen extends StatefulWidget {
  final UserModel? currentUser;
  FeedHomeScreen({this.currentUser});

  @override
  _FeedHomeScreenState createState() => _FeedHomeScreenState();
}

class _FeedHomeScreenState extends State<FeedHomeScreen>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  late FeedController _feedController;
  bool _isScrolling = false;
  int clickedImageIndex = 0;
  bool _isFirstBuild = true;

  // Controle do botão de voltar ao topo
  final RxBool _showBackToTopButton = false.obs;
  Timer? _scrollTimer;
  static const int _minScrollExtentForButton = 2000; // Aproximadamente 5 posts

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Inicializar o FeedController com o usuário atual
    _feedController = Get.put(FeedController(currentUser: widget.currentUser!));
    print("FeedHomeScreen: FeedController inicializado");

    _scrollController.addListener(_onScroll);

    // Definir a posição inicial do scroll
    if (_feedController.lastViewedPostId != null) {
      print(
          "FeedHomeScreen: Último post visualizado encontrado - ${_feedController.lastViewedPostId}");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        int index = _feedController.posts.indexWhere(
            (post) => post.objectId == _feedController.lastViewedPostId);
        print("FeedHomeScreen: Índice do último post: $index");
        if (index > 0) {
          _scrollController.jumpTo(index * _getEstimatedItemSize());
          print(
              "FeedHomeScreen: Scroll posicionado na posição: ${index * _getEstimatedItemSize()}");
        }
      });
    } else {
      print("FeedHomeScreen: Não há último post visualizado");
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Esconder o botão quando o usuário começa a rolar
    if (_scrollController.position.isScrollingNotifier.value) {
      _showBackToTopButton.value = false;
    }

    if (!_isScrolling) {
      _isScrolling = true;
      Future.delayed(const Duration(seconds: 1), () {
        if (_scrollController.hasClients && _feedController.posts.isNotEmpty) {
          int currentIndex =
              (_scrollController.position.pixels / _getEstimatedItemSize())
                  .floor();
          if (currentIndex >= 0 &&
              currentIndex < _feedController.posts.length) {
            _feedController.saveLastViewedPost(
                _feedController.posts[currentIndex].objectId!);
            _feedController.startPreloading(currentIndex);
          }
        }
        _isScrolling = false;

        // Atualizar visibilidade do botão de voltar ao topo
        _updateBackToTopButton();
      });
    }
  }

  // Atualizar estado do botão de voltar ao topo
  void _updateBackToTopButton() {
    // Cancelar timer anterior se existir
    _scrollTimer?.cancel();

    // Verificar se o scroll é suficiente para mostrar o botão
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _minScrollExtentForButton) {
      // Criar novo timer para mostrar o botão após o usuário parar de deslizar
      _scrollTimer = Timer(Duration(milliseconds: 500), () {
        _showBackToTopButton.value = true;
      });
    } else {
      _showBackToTopButton.value = false;
    }
  }

  // Voltar para o topo da lista
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
      _showBackToTopButton.value = false;
    }
  }

  double _getEstimatedItemSize() {
    // Tamanho estimado de cada item do feed (ajuste conforme necessário)
    return 400.0;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isDark = QuickHelp.isDarkMode(context);

    if (_isFirstBuild) {
      _isFirstBuild = false;
      // Pré-carrega imagens em segundo plano
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_feedController.posts.isNotEmpty) {
          for (var post in _feedController.posts.take(5)) {
            if (post.getImagesList != null && post.getImagesList!.isNotEmpty) {
              try {
                String? imageUrl = post.getImagesList!.first.url;
                if (imageUrl != null) {
                  precacheImage(NetworkImage(imageUrl), context);
                }
              } catch (e) {
                print("Erro ao pré-carregar imagem: $e");
              }
            }
          }
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(isDark),
      backgroundColor: isDark ? kContentDarkShadow : kGrayWhite,
      floatingActionButton: Stack(
        children: [
          // Botão de voltar ao topo
          Positioned(
            right: 0,
            bottom: 80, // Acima do botão de adicionar post
            child: Obx(() => _showBackToTopButton.value
                ? FloatingActionButton(
                    mini: true,
                    backgroundColor: isDark
                        ? Colors.white24
                        : kPrimaryColor.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    tooltip: "Voltar ao topo",
                    onPressed: _scrollToTop,
                    child: Icon(Icons.keyboard_arrow_up, size: 22),
                  )
                : SizedBox.shrink()),
          ),
          // Botão de criar post (posição normal)
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildFloatingActionButton(isDark),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? kContentColorLightTheme : Colors.white,
      surfaceTintColor: isDark ? kContentColorLightTheme : Colors.white,
      leading: IconButton(
        onPressed: () {
          showGlobalSearch(
            currentUser: widget.currentUser!,
            context: context,
            onlyEvent: false,
            onlyLives: false,
            onlyUsers: true,
          );
        },
        icon: SvgPicture.asset(
          isDark
              ? "assets/svg/ic_search_for_dark_mode.svg"
              : "assets/svg/ic_search_for_light_mode.svg",
          height: 25,
          width: 25,
        ),
      ),
      actions: [
        Stack(
          alignment: AlignmentDirectional.topEnd,
          children: [
            IconButton(
              onPressed: () => QuickHelp.goToNavigatorScreen(
                context,
                NotificationsScreen(currentUser: widget.currentUser),
              ),
              icon: Icon(
                Icons.notifications,
                color: isDark ? Colors.white : kContentDarkShadow,
                size: 20,
              ),
            ),
            ContainerCorner(
              width: 14,
              height: 14,
              borderRadius: 50,
              borderWidth: 0,
              marginRight: 5,
              marginTop: 3,
              color: Colors.red,
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: _buildNotificationCount(),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => QuickHelp.goToNavigatorScreen(
            context,
            ProfileScreen(currentUser: widget.currentUser),
          ),
          icon: Icon(
            Icons.dashboard_rounded,
            color: isDark ? Colors.white : kContentDarkShadow,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(bool isDark) {
    return ContainerCorner(
      borderRadius: 9,
      color: isDark ? Colors.white : kContentDarkShadow,
      shadowColor: kGrayColor,
      shadowColorOpacity: 0.3,
      onTap: () => QuickHelp.goToNavigatorScreen(
        context,
        PostTypeChooserScreen(currentUser: widget.currentUser),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7.0),
        child: Icon(
          Icons.add,
          color: isDark ? kContentDarkShadow : Colors.white,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (_feedController.posts.isEmpty) {
        // Usa um skeleton loader em vez de indicador de progresso
        if (_feedController.isLoading.value) {
          return _buildSkeletonLoader();
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Nenhum post encontrado", style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  print("FeedHomeScreen: Forçando carregamento dos posts");
                  if (widget.currentUser != null && mounted) {
                    _feedController.setCurrentUser(widget.currentUser!);
                    _feedController.forceFeedRefresh();
                  }
                },
                child: Text("Recarregar"),
              ),
            ],
          ),
        );
      }

      // Use o builder para criar os itens sob demanda
      return _buildPostsList();
    });
  }

  Widget _buildPostsList() {
    if (!mounted) {
      return Container(); // Retornar um widget vazio se o widget não estiver montado
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            if (mounted) {
              print("FeedHomeScreen: Atualizando feed");
              try {
                await _feedController.loadInitialPosts();
              } catch (e) {
                print("Erro ao atualizar feed: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erro ao atualizar feed. Tente novamente."),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            }
          },
          child: ListView.builder(
            key: PageStorageKey('feed_list'),
            controller: _scrollController,
            itemCount: _feedController.posts.length,
            // Use cacheExtent para pré-carregar mais itens
            cacheExtent: 1000,
            // Use clipBehavior para melhorar a performance do scroll
            clipBehavior: Clip.none,
            // Adicionamos o buildOptimizedItem para carregar progressivamente os itens
            itemBuilder: (context, index) {
              if (index < 0 || index >= _feedController.posts.length) {
                return SizedBox
                    .shrink(); // Evitar erros de índice fora do intervalo
              }

              final post = _feedController.posts[index];
              return _buildOptimizedItem(post, index);
            },
          ),
        ),
        // Prevenir interação durante o carregamento inicial
        if (_feedController.isLoading.value && _feedController.posts.isEmpty)
          Container(
            color: Colors.transparent,
          ),
      ],
    );
  }

  Widget _buildOptimizedItem(PostsModel post, int index) {
    if (!mounted || widget.currentUser == null) {
      return SizedBox.shrink();
    }

    // Verificações de segurança antes de renderizar o post
    try {
      // Verifica se o post tem as informações essenciais
      if (post.objectId == null) {
        print("Post sem objectId detectado no índice $index");
        return _buildErrorPost("Post inválido (sem ID)");
      }

      // Tenta carregar o autor do post se não estiver disponível
      if (post.getAuthor == null && post.getAuthorId != null) {
        print(
            "Post sem autor detectado: ${post.objectId}. Tentando buscar autor...");

        // Observe que isso carrega o autor mas não atualizará a UI imediatamente
        // Uma solução mais robusta envolveria solicitar ao controller para recarregar este post
        _feedController.fetchAuthorForPost(post);

        // Mostre um placeholder enquanto o autor é carregado
        return _buildLoadingPost();
      }

      // Se for um post válido, carrega normalmente
      return OptimizedFeedPost(
        post: post,
        currentUser: widget.currentUser!,
        onPostTap: _handlePostTap,
        onOptionsPressed: _showPostOptions,
        onCommentsTap: _showComments,
      );
    } catch (e) {
      print("Erro ao preparar post $index: $e");
      return _buildErrorPost("Erro ao preparar post");
    }
  }

  // Widget para mostrar enquanto o post está sendo carregado
  Widget _buildLoadingPost() {
    return Container(
      height: 250,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  // Widget para mostrar quando há erro no post
  Widget _buildErrorPost(String message) {
    return Container(
      height: 100,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey),
            SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCount() {
    return TextWithTap(
      "0",
      color: Colors.white,
      fontSize: 5,
      marginTop: 3,
      marginLeft: 3,
      marginBottom: 3,
    );
  }

  void _handlePostTap(PostsModel post) {
    int clickedPostIndex = 0;
    /* // Usar o novo ReelsView para vídeos
      ReelsView.navigateToVideo(
        context,
        post,
        widget.currentUser!,
      );*/


    for (int i = 0; i < _feedController.posts.length; i++) {
      if (_feedController.posts[i].objectId == post.objectId) {
        clickedPostIndex = i;
      }
    }

    QuickHelp.goToNavigatorScreen(
      context,
      FeedReelsScreen(
        currentUser: widget.currentUser,
        preloadsPost: _feedController.posts,
        initialIndex: clickedPostIndex,
        pictureIndex: clickedImageIndex,
      ),
    );
  }

  void _editPost(PostsModel post) {
    if (post.getVideo != null) {
      QuickHelp.goToNavigatorScreen(
        context,
        EditVideoPostScreen(
          currentUser: widget.currentUser,
          postsModel: post,
        ),
      );
    } else if (post.getBackgroundColor != null) {
      QuickHelp.goToNavigatorScreen(
        context,
        EditTextPostScreen(
          currentUser: widget.currentUser,
          postsModel: post,
        ),
      );
    } else {
      QuickHelp.goToNavigatorScreen(
        context,
        EditPicturesPost(
          currentUser: widget.currentUser,
          postsModel: post,
        ),
      );
    }
  }

  void _showPostOptions(UserModel author, PostsModel post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) {
        return _buildPostOptionsSheet(author, post);
      },
    );
  }

  Widget _buildPostOptionsSheet(UserModel author, PostsModel post) {
    bool isDark = QuickHelp.isDarkMode(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.0),
          topRight: Radius.circular(25.0),
        ),
      ),
      child: ContainerCorner(
        radiusTopRight: 20.0,
        radiusTopLeft: 20.0,
        color: isDark ? kContentColorLightTheme : Colors.white,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.currentUser!.objectId != post.getAuthorId)
                TextWithTap(
                  tr("feed.report_post",
                      namedArgs: {"name": author.getFullName!}),
                  alignment: Alignment.center,
                  marginBottom: 10,
                  marginTop: 20,
                  onTap: () => _showReportOptions(author, post),
                ),
              if (widget.currentUser!.objectId != post.getAuthorId)
                TextWithTap(
                  tr("feed.block_user",
                      namedArgs: {"name": author.getFullName!}),
                  alignment: Alignment.center,
                  marginBottom: 10,
                  marginTop: 10,
                  onTap: () => _confirmBlockUser(author),
                ),
              if (widget.currentUser!.objectId == post.getAuthorId ||
                  widget.currentUser!.isAdmin!)
                TextWithTap(
                  tr("feed.delete_post"),
                  alignment: Alignment.center,
                  marginBottom: 10,
                  marginTop: 10,
                  onTap: () => _confirmDeletePost(post),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportOptions(UserModel author, PostsModel post) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) {
        return _buildReportOptionsSheet(author, post);
      },
    );
  }

  Widget _buildReportOptionsSheet(UserModel author, PostsModel post) {
    bool isDark = QuickHelp.isDarkMode(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.0),
          topRight: Radius.circular(25.0),
        ),
      ),
      child: ContainerCorner(
        radiusTopRight: 20.0,
        radiusTopLeft: 20.0,
        color: isDark ? kContentColorLightTheme : Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextWithTap(
              tr("feed.report_"),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              marginBottom: 50,
              marginTop: 20,
            ),
            Column(
              children: List.generate(
                QuickHelp.getReportCodeMessageList().length,
                (index) {
                  String code = QuickHelp.getReportCodeMessageList()[index];
                  return TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _feedController.reportPost(
                          post, QuickHelp.getReportMessage(code));
                    },
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextWithTap(
                              QuickHelp.getReportMessage(code),
                              color: kGrayColor,
                              fontSize: 15,
                              marginBottom: 5,
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: kGrayColor,
                            ),
                          ],
                        ),
                        Divider(height: 1.0),
                      ],
                    ),
                  );
                },
              ),
            ),
            ContainerCorner(
              marginTop: 30,
              marginBottom: 20,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: TextWithTap(
                  tr("cancel").toUpperCase(),
                  color: kGrayColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBlockUser(UserModel author) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.post_block_title"),
      message: tr("feed.post_block_message",
          namedArgs: {"name": author.getFullName!}),
      cancelButtonText: tr("cancel"),
      confirmButtonText: tr("feed.post_block_confirm"),
      onPressed: () => _feedController.blockUser(author),
    );
  }

  void _confirmDeletePost(PostsModel post) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.delete_post_alert"),
      message: tr("feed.delete_post_message"),
      cancelButtonText: tr("no"),
      confirmButtonText: tr("feed.yes_delete"),
      onPressed: () => _feedController.deletePost(post),
    );
  }

  void _showComments(PostsModel post) {
    QuickHelp.goToNavigatorScreen(
      context,
      CommentPostScreen(
        post: post,
        currentUser: widget.currentUser,
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho do post
              ListTile(
                leading: _buildSkeletonCircle(40),
                title: _buildSkeletonLine(80),
                subtitle: _buildSkeletonLine(50),
              ),
              // Conteúdo do post
              Container(
                height: 200,
                color: Colors.grey.withOpacity(0.2),
              ),
              // Rodapé do post
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSkeletonLine(40),
                    _buildSkeletonLine(40),
                    _buildSkeletonLine(40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildSkeletonLine(double width) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
