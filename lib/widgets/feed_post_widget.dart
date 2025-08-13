// ignore_for_file: unnecessary_null_comparison, deprecated_member_use

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:like_button/like_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:video_player/video_player.dart';
import '../app/setup.dart';
import '../controllers/feed_controller.dart';
import '../helpers/quick_help.dart';
import '../helpers/quick_actions.dart';
import '../home/profile/profile_screen.dart';
import '../models/PostsModel.dart';
import '../models/UserModel.dart';
import '../services/deep_links_service.dart';
import '../ui/container_with_corner.dart';
import '../ui/text_with_tap.dart';
import '../utils/colors.dart';

class FeedPostWidget extends StatelessWidget {
  final PostsModel post;
  final UserModel currentUser;
  final Function(PostsModel) onPostTap;
  final Function(UserModel, PostsModel) onOptionsPressed;
  final Function(PostsModel) onCommentsTap;

  // Novos parâmetros para vídeo
  final VideoPlayerController? videoController;
  final bool? isVideoInitialized;
  final bool? isPlaying;
  final VoidCallback? onVideoTap;

  const FeedPostWidget({
    Key? key,
    required this.post,
    required this.currentUser,
    required this.onPostTap,
    required this.onOptionsPressed,
    required this.onCommentsTap,
    this.videoController,
    this.isVideoInitialized,
    this.isPlaying,
    this.onVideoTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FeedController controller = Get.find<FeedController>();
    bool isDark = QuickHelp.isDarkMode(context);
    Size size = MediaQuery.of(context).size;

    try {
      if (post.getAuthor == null) {
        return Container(
          margin: EdgeInsets.all(10),
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDark ? kContentColorLightTheme : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                  strokeWidth: 2,
                ),
                SizedBox(height: 10),
                Text(
                  "Carregando post...",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }

      return ContainerCorner(
        color: isDark ? kContentColorLightTheme : Colors.white,
        marginTop: 7,
        marginBottom: 0,
        marginLeft: 10,
        marginRight: 10,
        borderRadius: 10,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, size, isDark),
            _buildContent(context, size),
            _buildInteractions(context, controller, isDark),
          ],
        ),
      );
    } catch (e) {
      print("Erro ao construir post: $e");
      return Container(
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? kContentColorLightTheme : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                "Erro ao carregar post",
                style: TextStyle(color: Colors.grey),
              ),
              TextButton(
                onPressed: () {
                  if (onPostTap != null) {
                    onPostTap(post);
                  }
                },
                child: Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildHeader(BuildContext context, Size size, bool isDark) {
    if (post.getAuthor == null) {
      return SizedBox.shrink();
    }

    return Column(
      children: [
        if (post.getTargetPeopleID != null &&
            post.getTargetPeopleID!.contains(currentUser.objectId))
          TextWithTap(
            tr("feed.you_was_mentioned", namedArgs: {
              "author_name": post.getAuthor!.getFullName ?? "Usuário"
            }),
            marginLeft: 10,
            color: kGrayColor.withOpacity(0.7),
            fontSize: 7,
            alignment: Alignment.center,
          ),
        Row(
          children: [
            Expanded(
              child: ContainerCorner(
                marginTop: 10,
                onTap: () {
                  if (post.getAuthorId == currentUser.objectId!) {
                    QuickHelp.goToNavigatorScreen(
                        context,
                        ProfileScreen(
                          currentUser: currentUser,
                        ));
                  } else {
                    QuickActions.showUserProfile(
                      context,
                      currentUser,
                      post.getAuthor!,
                    );
                  }
                },
                color: isDark ? kContentColorLightTheme : Colors.white,
                child: Row(
                  children: [
                    Stack(
                      alignment: AlignmentDirectional.center,
                      children: [
                        QuickActions.avatarWidget(
                          post.getAuthor!,
                          width: 35,
                          height: 35,
                        ),
                        if (post.getAuthor!.getAvatarFrame != null &&
                            post.getAuthor!.getCanUseAvatarFrame == true)
                          ContainerCorner(
                            borderWidth: 0,
                            width: 55,
                            height: 55,
                            child: _buildAvatarFrame(),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            TextWithTap(
                              post.getAuthor!.getFullName ?? "Usuário",
                              fontWeight: FontWeight.w600,
                              fontSize: size.width / 20,
                              marginLeft: 10,
                              marginRight: 5,
                            ),
                            if (post.getAuthor!.getCountryCode != null &&
                                post.getAuthor!.getCountryCode!.isNotEmpty)
                              Image.asset(
                                QuickHelp.getCountryFlag(
                                    code: post.getAuthor!.getCountryCode!),
                                height: 12,
                              )
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: QuickHelp.usersMoreInfo(
                            context,
                            post.getAuthor!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                marginLeft: 15,
              ),
            ),
            Visibility(
              visible: post.getAuthorId == currentUser.objectId,
              child: IconButton(
                onPressed: () => onPostTap(post),
                icon: Icon(
                  Icons.edit,
                  size: 20,
                  color: kGrayColor,
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarFrame() {
    try {
      String? frameUrl = post.getAuthor!.getAvatarFrame?.url;
      if (frameUrl == null) return SizedBox.shrink();

      return CachedNetworkImage(
        imageUrl: frameUrl,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.fill,
            ),
          ),
        ),
        errorWidget: (context, url, error) => SizedBox.shrink(),
      );
    } catch (e) {
      print("Erro ao carregar frame do avatar: $e");
      return SizedBox.shrink();
    }
  }

  Widget _buildContent(BuildContext context, Size size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.getBackgroundColor != null)
          ContainerCorner(
            width: size.width,
            marginLeft: 5,
            marginTop: 10,
            borderRadius: 8,
            marginRight: 5,
            color: QuickHelp.stringToColor(post.getBackgroundColor!),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
                top: 20,
                bottom: 20,
              ),
              child: AutoSizeText(
                post.getText ?? "",
                style: GoogleFonts.nunito(
                  fontSize: 30,
                  color: post.getTextColors != null
                      ? QuickHelp.stringToColor(post.getTextColors!)
                      : Colors.white,
                ),
                minFontSize: 15,
                stepGranularity: 5,
                maxLines: 10,
              ),
            ),
          ),
        // Verificar se tem vídeo para exibir
        if (post.getVideo != null) _buildVideoContent(),
        // Exibir imagens se não houver vídeo ou se o vídeo não estiver carregado
        if (post.getImagesList != null) _buildImagesContent(context),
        if (post.getText != null &&
            post.getText!.isNotEmpty &&
            post.getBackgroundColor == null)
          TextWithTap(
            post.getText!,
            textAlign: TextAlign.start,
            marginTop: 10,
            marginBottom: 5,
            marginLeft: 10,
          ),
      ],
    );
  }

  Widget _buildVideoContent() {
    if (isVideoInitialized != true || videoController == null) {
      return _buildVideoThumbnail();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          // Calcula as dimensões máximas do vídeo baseado no espaço disponível
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          // Obtém as dimensões do vídeo
          final videoRatio = videoController!.value.aspectRatio;

          // Calcula as dimensões finais mantendo a proporção
          double width = maxWidth;
          double height = width / videoRatio;

          // Ajusta se exceder a altura máxima
          if (height > maxHeight && maxHeight > 0) {
            height = maxHeight;
            width = height * videoRatio;
          }

          // Garante dimensões mínimas
          width = width.isFinite ? width : maxWidth;
          height = height.isFinite ? height : 400;

          return GestureDetector(
            onTap: onVideoTap,
            child: Container(
              width: width,
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vídeo com dimensões otimizadas
                  SizedBox(
                    width: width,
                    height: height,
                    child: VideoPlayer(videoController!),
                  ),

                  // Controles e informações
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildVideoControls(),
                  ),

                  // Botão de play/pause central
                  if (isPlaying != true)
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                ],
              ),
            ),
          );
        } catch (e) {
          print("Erro ao construir vídeo: $e");
          return _buildVideoThumbnail();
        }
      },
    );
  }

  Widget _buildVideoThumbnail() {
    return GestureDetector(
      onTap: () => onPostTap(post),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail do vídeo
          if (post.getVideoThumbnail != null)
            QuickActions.photosWidget(
              post.getVideoThumbnail!.url,
              fit: BoxFit.fitWidth,
              height: 400,
              width: double.infinity,
            )

          /*Image.network(
              _getParseFileUrl(post.getVideoThumbnail) ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              height: 400,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 400,
                  color: Colors.grey[300],
                  child: Icon(Icons.movie, size: 50, color: Colors.grey[600]),
                );
              },
            )*/
          else
            Container(
              width: double.infinity,
              height: 400,
              color: Colors.grey[300],
              child: Icon(Icons.movie, size: 50, color: Colors.grey[600]),
            ),

          // Ícone de play
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black54],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de progresso otimizada
          if (isVideoInitialized == true && videoController != null)
            VideoProgressIndicator(
              videoController!,
              allowScrubbing: true,
              padding: EdgeInsets.symmetric(vertical: 8),
              colors: VideoProgressColors(
                backgroundColor: Colors.white.withOpacity(0.3),
                bufferedColor: Colors.white.withOpacity(0.5),
                playedColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagesContent(BuildContext context) {
    return Wrap(
      children: List.generate(
        post.getNumberOfPictures,
        (index) {
          String? imageUrl;
          try {
            if (index < post.getImagesList!.length) {
              var parseFile = post.getImagesList![index];
              imageUrl = _getParseFileUrl(parseFile);
            }
          } catch (e) {
            print("Erro ao obter URL da imagem: $e");
          }

          if (imageUrl == null) {
            return SizedBox.shrink();
          }

          return GestureDetector(
            onTap: () => onPostTap(post),
            child: ContainerCorner(
              width: imageWidth(
                  numberOfPictures: post.getNumberOfPictures, context: context),
              height: imageHeight(
                  numberOfPictures: post.getNumberOfPictures, context: context),
              borderWidth: 0,
              marginRight: 5,
              marginBottom: 5,
              borderRadius: 8,
              child: QuickActions.photosWidget(post.getImagesList![index].url),
            ),
          );
        },
      ),
    );
  }

  // PERFORMANCE OPTIMIZATION: Cache screen size to avoid repeated MediaQuery calls
  static Size? _cachedScreenSize;
  static double _getScreenWidth(BuildContext context) {
    _cachedScreenSize ??= MediaQuery.of(context).size;
    return _cachedScreenSize!.width;
  }

  double imageWidth(
      {required int numberOfPictures, required BuildContext context}) {
    final screenWidth = _getScreenWidth(context);
    if (numberOfPictures == 1) {
      return screenWidth;
    } else if (numberOfPictures == 2 || numberOfPictures == 4) {
      return screenWidth / 2.2;
    } else {
      return screenWidth / 3.4;
    }
  }

  double imageHeight(
      {required int numberOfPictures, required BuildContext context}) {
    if (numberOfPictures == 1) {
      return 400;
    } else if (numberOfPictures == 2 || numberOfPictures == 4) {
      return 170;
    } else {
      return _getScreenWidth(context) / 3.4;
    }
  }

  Widget _buildInteractions(
      BuildContext context, FeedController controller, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.watch_later_outlined,
                size: 14,
                color: kPrimaryColor,
              ),
              SizedBox(width: 8.0),
              Container(
                width: 220,
                child: Text(
                  QuickHelp.getTimeAgoForFeed(post.createdAt!),
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 10,
          color: kTransparentColor,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLikeButton(controller, isDark),
                ContainerCorner(
                  marginBottom: 10,
                  marginLeft: 10,
                  marginTop: 10,
                  onTap: () => onCommentsTap(post),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        "assets/svg/uil_comment.svg",
                        color: isDark ? Colors.white : Colors.black,
                        height: 20,
                        width: 20,
                      ),
                      TextWithTap(
                        post.getComments.length.toString(),
                        marginLeft: 2,
                      ),
                    ],
                  ),
                ),
                ContainerCorner(
                  marginBottom: 10,
                  marginLeft: 10,
                  marginTop: 10,
                  onTap: () => _sharePost(context),
                  child: Image.asset(
                    "assets/images/feed_icon_details_share_new.png",
                    color: isDark ? Colors.white : Colors.black,
                    height: 20,
                    width: 20,
                  ),
                ),
              ],
            ),
            RotatedBox(
              quarterTurns: -1,
              child: IconButton(
                onPressed: () => onOptionsPressed(post.getAuthor!, post),
                icon: SvgPicture.asset(
                  "assets/svg/ic_post_config.svg",
                  color: isDark ? Colors.white : Colors.black,
                  height: 13,
                  width: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLikeButton(FeedController controller, bool isDark) {
    return LikeButton(
      size: 30,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      countPostion: CountPostion.right,
      circleColor: CircleColor(start: kPrimaryColor, end: kPrimaryColor),
      bubblesColor: BubblesColor(
        dotPrimaryColor: kPrimaryColor,
        dotSecondaryColor: kPrimaryColor,
      ),
      isLiked: post.getLikes.contains(currentUser.objectId),
      likeCountAnimationType: LikeCountAnimationType.all,
      likeBuilder: (bool isLiked) {
        return Icon(
          isLiked ? Icons.favorite : Icons.favorite_outline_outlined,
          color: isLiked
              ? kPrimaryColor
              : isDark
                  ? Colors.white
                  : kContentColorLightTheme,
          size: 20,
        );
      },
      likeCount: post.getLikes.length,
      countBuilder: (count, bool isLiked, String text) {
        return TextWithTap(
          count == 0 ? "" : QuickHelp.convertNumberToK(count!),
        );
      },
      onTap: (isLiked) async {
        await controller.toggleLike(post);
        return !isLiked;
      },
    );
  }

  Future<void> _sharePost(BuildContext context) async {
    String linkToShare = await DeepLinksService.createLink(
      branchObject: DeepLinksService.branchObject(
        shareAction: DeepLinksService.keyPostShare,
        objectID: post.objectId!,
        imageURL: QuickHelp.getImageToShare(post),
        title: QuickHelp.getTitleToShare(post),
        description: post.getAuthor!.getFullName,
      ),
      branchProperties: DeepLinksService.linkProperties(
        channel: "link",
      ),
      context: context,
    );
    if (linkToShare.isNotEmpty) {
      Share.share(
        tr("share_post",
            namedArgs: {"link": linkToShare, "app_name": Setup.appName}),
      );
    }
  }

  String? _getParseFileUrl(dynamic parseFile) {
    if (parseFile == null) return null;
    try {
      return parseFile.url as String?;
    } catch (e) {
      print("Erro ao acessar URL: $e");
      return null;
    }
  }
}

extension ParseFileExtension on dynamic {
  String? get safeUrl {
    try {
      if (this == null) return null;
      return this?.url as String?;
    } catch (e) {
      print("Erro ao obter URL: $e");
      return null;
    }
  }
}
