// ignore_for_file: must_be_immutable, unnecessary_null_comparison, unused_element, unused_field, unused_element_parameter, unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:trace/views/reels_interactions.dart';
import '../controllers/reels_controller.dart';
import '../controllers/video_interactions_controller.dart';
import '../models/UserModel.dart';
import '../models/PostsModel.dart';
import '../services/posts_service.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

class ReelsView extends GetView<ReelsController> {
  final UserModel? currentUser;
  final bool autoplayOnLoad;

  static int? lastViewedIndex;

  ReelsView({
    Key? key,
    this.currentUser,
    this.autoplayOnLoad = true,
  }) : super(key: key);

  // Método estático simplificado para navegar para ReelsView
  static void navigateTo({bool showLoadingDialog = true}) {
    // Verificar se o PostsService está registrado
    if (!Get.isRegistered<PostsService>()) {
      print('ReelsView: PostsService não registrado');
      return;
    }

    // Se o ReelsController ainda não estiver registrado, registrá-lo
    if (!Get.isRegistered<ReelsController>()) {
      UserModel? currentUser =
          Get.isRegistered<UserModel>() ? Get.find<UserModel>() : null;
      Get.put(ReelsController(
        currentUser: currentUser,
        autoPlay: true,
      ));
    }

    Get.to(() => ReelsView(
          currentUser:
              Get.isRegistered<UserModel>() ? Get.find<UserModel>() : null,
          autoplayOnLoad: true,
        ));
  }

  // Controladores para o botão de voltar ao topo
  final RxBool _showBackToTopButton = false.obs;
  Timer? _scrollTimer;
  final int _minIndexForButton = 5;

  /// Navegação para o ReelsView com um vídeo específico
  static void navigateToVideo(
    BuildContext context,
    PostsModel video,
    UserModel currentUser,
  ) {
    // Verificar se o PostsService está registrado
    if (!Get.isRegistered<PostsService>()) {
      print('ReelsView: PostsService não registrado, registrando agora');
      final postsService = PostsService();
      Get.put(postsService, permanent: true);

      // Configurar o usuário atual
      if (currentUser != null) {
        postsService.setCurrentUser(currentUser);
      }
    }

    // Pré-carregar os vídeos antes de navegar
    PostsService postsService = Get.find<PostsService>();

    // Mostrar indicador de carregamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  "Carregando vídeos...",
                  style: TextStyle(color: Colors.white),
                )
              ],
            ),
          ),
        );
      },
    );

    // Verificar se já temos vídeos ou se precisamos carregar
    (postsService.videoPosts.isNotEmpty
            ? Future.value(postsService.videoPosts)
            : postsService
                .loadInitialVideos()
                .then((_) => postsService.videoPosts))
        .then((videos) {
      // Fechar diálogo de carregamento
      Navigator.of(context).pop();

      if (videos.isEmpty) {
        print('ReelsView: Nenhum vídeo disponível após carregamento');
        // Mostrar mensagem de erro
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nenhum vídeo disponível no momento')));
        return;
      }

      print(
          'ReelsView: ${videos.length} vídeos carregados, continuando navegação');

      // Criar uma tag única para o controller
      final String controllerTag =
          'reels_controller_${DateTime.now().millisecondsSinceEpoch}';

      // Criar o controlador com o vídeo inicial
      final controller = Get.put(
        ReelsController(
          currentUser: currentUser,
          initialVideo: video,
          autoPlay: true,
        ),
        tag: controllerTag,
      );

      // Navegue para o ReelsView
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => GetBuilder<ReelsController>(
            tag: controllerTag,
            builder: (controller) {
              return ReelsView(
                currentUser: currentUser,
                autoplayOnLoad: true,
              );
            },
          ),
        ),
      )
          .then((_) {
        // Salvar o índice atual antes de fechar
        lastViewedIndex = controller.currentVideoIndex.value;
        print('ReelsView: Salvando último índice visto: $lastViewedIndex');

        // Limpar recursos quando a tela for fechada
        if (Get.isRegistered<ReelsController>(tag: controllerTag)) {
          Get.delete<ReelsController>(tag: controllerTag);
        }
      });
    }).catchError((error) {
      // Fechar diálogo em caso de erro
      Navigator.of(context).pop();
      print('ReelsView: Erro ao carregar vídeos: $error');

      // Exibir mensagem de erro
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar vídeos: $error')));
    });
  }

  @override
  Widget build(BuildContext context) {
    print('ReelsView: build iniciado');

    // Iniciar reprodução assim que a tela for construída
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.videos.isEmpty && !controller.isLoading.value) {
        print(
            'ReelsView: Lista vazia no primeiro frame, forçando carregamento');
        controller.loadInitialVideos(forceRefresh: true);
      } else if (autoplayOnLoad && controller.videos.isNotEmpty) {
        print('ReelsView: Iniciando reprodução automática');
        controller.playCurrentVideo();
      }
    });

    return WillPopScope(
      onWillPop: () async {
        print('ReelsView: Voltando, pausando todos os vídeos');
        lastViewedIndex = controller.currentVideoIndex.value;
        await controller.pauseAllVideos();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        floatingActionButton: Obx(() {
          return _showBackToTopButton.value
              ? FloatingActionButton(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  mini: true,
                  tooltip: 'Voltar ao topo',
                  onPressed: _scrollToTop,
                  child: Icon(Icons.keyboard_arrow_up, size: 22),
                )
              : SizedBox.shrink();
        }),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Obx(() {
          // Debug info
          print(
              'ReelsView: Construindo body com ${controller.videos.length} vídeos, carregando=${controller.isLoading.value}');

          // Se estiver carregando, mostrar indicador
          if (controller.isLoading.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    "Carregando vídeos...",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            );
          }

          // Se não estiver carregando, mas a lista estiver vazia, mostrar mensagem
          if (controller.videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Nenhum vídeo encontrado",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      print('ReelsView: Botão forçar carregamento pressionado');
                      controller.loadInitialVideos(forceRefresh: true);
                    },
                    child: Text("Carregar vídeos"),
                  ),
                ],
              ),
            );
          }

          // Inicializar PageController com o índice correto
          final initialPage =
              lastViewedIndex ?? controller.currentVideoIndex.value;

          print(
              'ReelsView: Criando PageView com initialPage=$initialPage, total=${controller.videos.length} vídeos');

          // Criar o PageController se ainda não existir
          if (controller.pageController == null) {
            controller.pageController = PageController(
              initialPage: initialPage,
              keepPage: true,
              viewportFraction: 1.0,
            );

            // Atualizar o índice atual
            controller.currentVideoIndex.value = initialPage;
          }

          return PageView.builder(
            key: const PageStorageKey('reels_pageview'),
            scrollDirection: Axis.vertical,
            itemCount: controller.videos.length,
            controller: controller.pageController,
            // Comportamento de clipping para melhorar performance
            clipBehavior: Clip.hardEdge,
            // Evitar pré-carregar páginas para melhorar performance
            allowImplicitScrolling: false,
            onPageChanged: _pageChanged,
            itemBuilder: (context, index) {
              // Verificar se o índice é válido
              if (index < 0 || index >= controller.videos.length) {
                return SizedBox.shrink();
              }

              final video = controller.videos[index];
              final String tag = 'video_interactions_${video.objectId}';

              // Determinar se este é o vídeo atual
              final isCurrentVideo =
                  index == controller.currentVideoIndex.value;

              // Log para debug
              if (isCurrentVideo) {
                print(
                    'ReelsView: Renderizando vídeo atual (index=$index, id=${video.objectId})');
                print('ReelsView: URL do vídeo: ${video.getVideo?.url}');
              }

              // Verificar se este vídeo está muito distante do atual
              final distanceFromCurrent =
                  (index - controller.currentVideoIndex.value).abs();
              final isTooFar = distanceFromCurrent > 2;

              if (isTooFar) {
                return Container(color: Colors.black);
              }

              // Criar um controller de interações apenas para o vídeo atual
              if (isCurrentVideo &&
                  !Get.isRegistered<VideoInteractionsController>(tag: tag)) {
                Get.put(
                  VideoInteractionsController(
                    video: video,
                    currentUser: currentUser,
                  ),
                  tag: tag,
                );
              }

              // Usar uma estratégia diferente dependendo se é o vídeo atual
              if (isCurrentVideo) {
                // Mostrar player completo para o vídeo atual
                return VideoPlayerItem(
                  index: index,
                  video: video,
                  tag: tag,
                  currentUser: currentUser,
                  isPrimary: true,
                );
              } else {
                // Mostrar apenas thumbnail para vídeos adjacentes
                return BasicVideoPlaceholder(
                  thumbnailUrl: video.getVideoThumbnail?.url,
                  index: index,
                );
              }
            },
          );
        }),
      ),
    );
  }

  // Função para voltar ao topo da lista de vídeos
  void _scrollToTop() {
    if (controller.pageController != null) {
      controller.pauseAllVideos();
      controller.pageController!.animateToPage(
        0,
        duration: Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
      _showBackToTopButton.value = false;
    }
  }

  void _preloadAdjacentVideos(int currentIndex) {
    if (currentIndex < controller.videos.length - 1) {
      // Pré-carregar próximo vídeo
      controller.prepareVideoAtIndex(currentIndex + 1);
    }

    if (currentIndex > 0) {
      // Pré-carregar vídeo anterior com prioridade mais baixa
      Future.delayed(Duration(milliseconds: 300), () {
        controller.prepareVideoAtIndex(currentIndex - 1);
      });
    }
  }

  // Flag para evitar múltiplas mudanças de página simultâneas
  bool _isChangingPage = false;

  void _pageChanged(int index) {
    if (index < 0 || index >= controller.videos.length) {
      print('Índice de vídeo inválido: $index');
      return;
    }

    // Define o índice atual do vídeo
    controller.currentVideoIndex.value = index;
    print('📱 Mudando para vídeo $index');

    // Mostrar ou esconder botão de voltar ao topo
    _updateBackToTopButton(index);

    // Pausa todos os vídeos e reproduz apenas o atual
    controller.pauseAllVideos();

    // Tentar reproduzir o vídeo atual com tratamento de erro
    Future.delayed(Duration(milliseconds: 100), () async {
      try {
        await controller.playCurrentVideo();
      } catch (e) {
        print('⚠️ Erro ao reproduzir vídeo: $e');
        // Tentativa de recuperação automática
        controller.handleVideoError(index);
      }
    });

    // Limpar controladores de vídeos muito distantes para economizar memória
    if (index % 3 == 0) {
      print('🧹 Limpeza periódica de recursos em _pageChanged');
      // Liberar controladores não utilizados para economizar memória
      controller.releaseUnusedControllers();

      // Limpar cache de imagens para vídeos que não estão sendo exibidos
      PaintingBinding.instance.imageCache.clear();
    }

    // Verificar se precisamos carregar mais vídeos
    if (index >= controller.videos.length - 3) {
      print('📦 Carregando mais vídeos pois chegou próximo ao fim da lista');
      controller.loadMoreVideos();
    }
  }

  // Atualizar estado do botão de voltar ao topo
  void _updateBackToTopButton(int index) {
    // Cancelar timer anterior se existir
    _scrollTimer?.cancel();

    // Esconder o botão enquanto o usuário está deslizando
    _showBackToTopButton.value = false;

    // Criar novo timer para mostrar o botão após o usuário parar de deslizar
    if (index >= _minIndexForButton) {
      _scrollTimer = Timer(Duration(milliseconds: 1200), () {
        _showBackToTopButton.value = true;
      });
    }
  }

  // Método para registrar analíticos de mudança de vídeo
  void _trackVideoChange(int index) {
    try {
      if (index >= 0 && index < controller.videos.length) {
        final video = controller.videos[index];
        // Implementar analytics aqui se necessário
        print('ReelsView: Vídeo visualizado - ${video.objectId}');
      }
    } catch (e) {
      print('ReelsView: Erro ao registrar analytics - $e');
    }
  }
}

// Widget simples para mostrar apenas o thumbnail de vídeos distantes
class BasicVideoPlaceholder extends StatelessWidget {
  final String? thumbnailUrl;
  final int index;

  const BasicVideoPlaceholder({
    Key? key,
    required this.thumbnailUrl,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(Icons.error, color: Colors.white),
                ),
                // Usar configurações de cache mínimas
                memCacheWidth: 360, // Largura reduzida
                memCacheHeight: 640, // Altura reduzida
              )
            : Container(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    "Vídeo #$index",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
      ),
    );
  }
}

class VideoPlayerItem extends StatefulWidget {
  final int index;
  final PostsModel video;
  final String tag;
  final UserModel? currentUser;
  final VoidCallback? onDoubleTap;
  final bool isPrimary;

  const VideoPlayerItem({
    Key? key,
    required this.index,
    required this.video,
    required this.tag,
    this.currentUser,
    this.onDoubleTap,
    this.isPrimary = false,
  }) : super(key: key);

  @override
  _VideoPlayerItemState createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ReelsController controller = Get.find();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  String? _thumbnailUrl;
  bool _hasError = false;
  bool _isDisposed = false;
  String? _videoUrl;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Chave única para o player
  final GlobalKey<_PlayerContainerState> _playerKey = GlobalKey();

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _thumbnailUrl = widget.video.getVideoThumbnail?.url;
    _videoUrl = widget.video.getVideo?.url;

    // Inicializar imediatamente, sem delay
    _initializeVideo();

    // Adicionar listener para atualização do controlador
    controller.addCustomListener(_checkController);
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  Future<void> _initializeVideo() async {
    if (_isDisposed) return;

    try {
      setState(() => _isLoading = true);

      // Apenas solicitar inicialização do controlador no ReelsController
      if (_videoUrl != null) {
        try {
          await controller.getControllerForIndex(widget.index);

          if (_isDisposed) return;

          setState(() {
            _isLoading = false;
            _hasError = false;
            _retryCount = 0;
          });
        } catch (e) {
          print('Erro ao inicializar vídeo: $e');
          _handleError(e.toString());
        }
      }
    } catch (e) {
      print('Erro geral ao inicializar vídeo: $e');
      _handleError(e.toString());
    }
  }

  void _handleError(String error) {
    if (_isDisposed) return;

    setState(() {
      _isLoading = false;
      _hasError = true;
    });

    if (_retryCount < _maxRetries) {
      _retryCount++;
      print('Tentativa $_retryCount de $_maxRetries para carregar o vídeo');

      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, () {
        if (!_isDisposed) {
          _initializeVideo();
        }
      });
    }
  }

  void _showPlayPauseAnimation() {
    if (_isDisposed) return;

    controller.showPlayPauseIcon.value = true;
    _animationController.forward(from: 0.0).then((_) {
      if (!_isDisposed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isDisposed) {
            controller.showPlayPauseIcon.value = false;
          }
        });
      }
    });
  }

  void _checkController() {
    if (_isDisposed) return;

    if (_videoUrl != null) {
      try {
        final videoController =
            controller.getCurrentControllerByUrl(_videoUrl!);
        if (videoController != null) {
          // Verificar de forma segura se o controlador é válido e inicializado
          try {
            if (videoController.value.isInitialized &&
                !videoController.value.hasError &&
                mounted) {
              // Teste adicional para garantir que o controlador não foi descartado
              videoController.addListener(() {});
              videoController.removeListener(() {});

              // Forçar reconstrução do widget para atualizar o player
              setState(() {
                _isLoading = false;
                _hasError = false;
              });

              // Forçar reconstrução do PlayerContainer
              if (_playerKey.currentState != null) {
                _playerKey.currentState!._createPlayer();
              }
            }
          } catch (e) {
            print('VideoPlayerItem: Erro ao verificar controlador: $e');
            // O controlador pode ter sido descartado, tentar recriar após um delay
            if (!_isDisposed && mounted) {
              Future.delayed(Duration(milliseconds: 500), () {
                _initializeVideo();
              });
            }
          }
        }
      } catch (e) {
        print('VideoPlayerItem: Erro ao acessar controlador: $e');
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _videoUrl = widget.video.getVideo?.url;
      _thumbnailUrl = widget.video.getVideoThumbnail?.url;
      _initializeVideo();

      // Verificar controlador imediatamente após a atualização
      _checkController();
    }
  }

  @override
  void dispose() {
    print('VideoPlayerItem: dispose para o índice ${widget.index}');
    _isDisposed = true;
    _retryTimer?.cancel();
    _animationController.dispose();
    controller.removeCustomListener(_checkController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () async {
            await controller.togglePlayPause();
            _showPlayPauseAnimation();
          },
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Miniatura sempre visível inicialmente para carregamento instantâneo
                if (_thumbnailUrl != null) _buildThumbnail(),

                // Loading indicator (mais sutil, apenas um indicador pequeno)
                if (_isLoading)
                  const Positioned(
                    bottom: 10,
                    right: 10,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white60,
                      ),
                    ),
                  ),

                // Erro
                if (_hasError && _retryCount >= _maxRetries)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Falha ao carregar vídeo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Player - exibir como camada superior, mesmo durante o carregamento
                if (!_hasError && _videoUrl != null)
                  _PlayerContainer(
                    key: _playerKey,
                    index: widget.index,
                    isPrimary: widget.isPrimary,
                  ),
              ],
            ),
          ),
        ),

        // Ícone de play/pause animado
        Obx(() {
          if (controller.showPlayPauseIcon.value) {
            return Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Icon(
                    controller.isPlaying.value ? Icons.pause : Icons.play_arrow,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        // Barra de progresso e controles
        Obx(() {
          if (!controller.showProgressBar.value) {
            return const SizedBox.shrink();
          }

          // Usar o método público para obter o controlador
          final videoController = _videoUrl != null
              ? controller.getCurrentControllerByUrl(_videoUrl!)
              : null;

          if (videoController == null || !videoController.value.isInitialized) {
            return const SizedBox.shrink();
          }

          return Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildProgressBar(
              videoController.value.position,
              videoController.value.duration,
              videoController.value.position.inMilliseconds /
                  videoController.value.duration.inMilliseconds,
              videoController,
            ),
          );
        }),

        // Interações (likes, comentários, etc)
        Builder(
          builder: (context) {
            // Verificar se o autor do vídeo está nulo e tentar carregar se necessário
            if (widget.video.getAuthor == null &&
                Get.isRegistered<PostsService>()) {
              final postsService = Get.find<PostsService>();
              Future.microtask(
                  () => postsService.fetchAuthorForPost(widget.video));

              // Mostrar um placeholder enquanto carrega o autor
              return Container(
                padding: EdgeInsets.all(16),
                alignment: Alignment.bottomLeft,
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            return ReelsInteractions(
              postModel: widget.video,
              currentUser: widget.currentUser ?? Get.find<UserModel>(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThumbnail() {
    return Container(
      color: Colors.black,
      child: Image.network(
        _thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(
    Duration position,
    Duration duration,
    double progress,
    CachedVideoPlayerPlusController videoController,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.0, 0.4],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de progresso
          _buildProgressBarSlider(
              progress, position, duration, videoController),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 10),
          _buildControlsRow(position, duration, videoController),
        ],
      ),
    );
  }

  Widget _buildProgressBarSlider(
    double progress,
    Duration position,
    Duration duration,
    CachedVideoPlayerPlusController videoController,
  ) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        if (videoController.value.isPlaying) {
          videoController.pause();
        }
      },
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final tapPos = box.globalToLocal(details.globalPosition);
        final newProgress = tapPos.dx / box.size.width;
        final newPosition = Duration(
          milliseconds: (duration.inMilliseconds * newProgress).round(),
        );
        controller.seekVideo(widget.index, newPosition);
      },
      onHorizontalDragEnd: (details) {
        if (controller.isPlaying.value) {
          videoController.play();
        }
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final tapPos = box.globalToLocal(details.globalPosition);
        final tapProgress = tapPos.dx / box.size.width;
        final newPosition = Duration(
          milliseconds: (duration.inMilliseconds * tapProgress).round(),
        );
        controller.seekVideo(widget.index, newPosition);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          backgroundColor: Colors.white24,
          minHeight: 3,
        ),
      ),
    );
  }

  Widget _buildControlsRow(
    Duration position,
    Duration duration,
    CachedVideoPlayerPlusController videoController,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatDuration(position),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlButton(
              icon: Icons.replay_10,
              onTap: () => controller.skipBackward(widget.index, 10),
            ),
            const SizedBox(width: 20),
            _buildControlButton(
              icon: Icons.forward_10,
              onTap: () => controller.skipForward(widget.index, 10),
            ),
            const SizedBox(width: 20),
            _buildControlButton(
              icon: Icons.settings,
              onTap: _showDurationSettings,
            ),
          ],
        ),
        Text(
          _formatDuration(duration),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white24,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  void _showDurationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Duração da barra de progresso",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [3, 5, 10, 30]
                  .map((seconds) => _durationOption(seconds))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationOption(int seconds) {
    return Obx(() {
      final bool isSelected =
          controller.progressBarDurationSeconds.value == seconds;
      return InkWell(
        onTap: () {
          controller.setProgressBarDuration(seconds);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$seconds seg",
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

/// Container para o player de vídeo com seu próprio ciclo de vida isolado
class _PlayerContainer extends StatefulWidget {
  final int index;
  final bool isPrimary;
  final bool isVisible;

  const _PlayerContainer({
    Key? key,
    required this.index,
    this.isPrimary = false,
    this.isVisible = false,
  }) : super(key: key);

  @override
  _PlayerContainerState createState() => _PlayerContainerState();
}

class _PlayerContainerState extends State<_PlayerContainer> {
  CachedVideoPlayerPlusController? _videoController;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isCreatingPlayer = false;

  // Usar um ValueKey baseado no índice para garantir recriação quando o player mudar
  Widget? _playerWidget;

  @override
  void initState() {
    super.initState();

    // Se for o player principal, iniciar criação imediatamente
    if (widget.isPrimary) {
      _createPlayer();
    }
  }

  Future<void> _createPlayer() async {
    // Evitar criações simultâneas do mesmo player
    if (_isCreatingPlayer || _isDisposed) {
      print(
          '_PlayerContainer: Pulando criação de player - já em andamento ou descartado');
      return;
    }

    _isCreatingPlayer = true;

    try {
      // Verificar se o widget foi descartado antes de criar o player
      if (_isDisposed) {
        print(
            '_PlayerContainer: Não criando player pois o widget foi descartado');
        return;
      }

      // Limpar referências anteriores para garantir que não haja vazamento de memória
      _playerWidget = null;

      // Obter uma referência ao ReelsController
      final controller = Get.find<ReelsController>();
      if (_isDisposed) return; // Verificar novamente antes de continuar

      // Verificar se o controlador já existe e é válido para este índice
      final videoController =
          await controller.getControllerForIndex(widget.index);

      // Verificações de segurança
      if (_isDisposed) return;

      if (videoController != null && videoController.value.isInitialized) {
        // Verificar se o controlador é válido
        try {
          // Teste para verificar se o controlador não foi descartado
          final isLooping = videoController.value.isLooping;

          // Usar setState apenas se o widget ainda estiver montado
          if (mounted && !_isDisposed) {
            setState(() {
              _videoController = videoController;
              _isInitialized = true;

              // Criar o widget player com uma chave única baseada no índice e no hash do controlador
              _playerWidget = CachedVideoPlayerPlus(
                videoController,
                key: ValueKey(
                    'player_${widget.index}_${DateTime.now().millisecondsSinceEpoch}'),
              );
            });
          }
        } catch (e) {
          print('_PlayerContainer: Controlador inválido detectado: $e');
          // O controlador foi descartado, vamos solicitar um novo após um breve delay
          if (!_isDisposed && mounted) {
            Future.delayed(Duration(milliseconds: 300), () {
              if (!_isDisposed && mounted) {
                _createPlayer();
              }
            });
          }
        }
      } else if (!_isDisposed && mounted) {
        // Se não conseguiu inicializar, mas o widget ainda está montado
        setState(() {
          _isInitialized = false;
        });

        // Tentar novamente após um breve delay
        Future.delayed(Duration(milliseconds: 500), () {
          if (!_isDisposed && mounted) {
            _createPlayer();
          }
        });
      }
    } catch (e) {
      print('Erro ao criar player: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = false;
        });
      }
    } finally {
      _isCreatingPlayer = false;
    }
  }

  @override
  void didUpdateWidget(_PlayerContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Se tornou o player principal (visível no centro da tela)
    if (widget.isPrimary && !oldWidget.isPrimary) {
      _recreatePlayerIfNeeded();
    }
  }

  // Recriar o player se necessário
  void _recreatePlayerIfNeeded() {
    if (!_isInitialized || _videoController == null || _playerWidget == null) {
      _createPlayer();
    }
  }

  @override
  void dispose() {
    print('_PlayerContainer: dispose para índice ${widget.index}');
    _isDisposed = true;

    // Garantir que não utilizamos mais o controlador
    _playerWidget = null;

    // Não devemos descartar o controlador aqui, pois ele é gerenciado pelo ReelsController
    // Apenas liberamos a referência local
    _videoController = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Caso não esteja inicializado mas seja o player principal, tentar criar
    if ((!_isInitialized || _playerWidget == null) &&
        widget.isPrimary &&
        !_isDisposed &&
        !_isCreatingPlayer) {
      Future.microtask(() => _createPlayer());

      // Mostrar um container transparente enquanto carrega
      return Container(color: Colors.transparent);
    }

    // Se não for o principal e não estiver inicializado, não mostrar nada
    if (!_isInitialized || _playerWidget == null || _isDisposed) {
      return const SizedBox.shrink();
    }

    // Verificar se o controlador é válido
    if (_videoController == null ||
        !_videoController!.value.isInitialized ||
        _videoController!.value.hasError) {
      if (widget.isPrimary && !_isDisposed && !_isCreatingPlayer) {
        Future.microtask(() => _createPlayer());
      }
      return const SizedBox.shrink();
    }

    // Player inicializado corretamente
    return Center(
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          // Usar uma chave única para o widget CachedVideoPlayerPlus
          child: _playerWidget,
        ),
      ),
    );
  }
}
