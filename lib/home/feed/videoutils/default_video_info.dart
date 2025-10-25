// ignore_for_file: deprecated_member_use, unused_element

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:like_button/like_button.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:trace/home/reels/reels_video_screen.dart';
import 'package:trace/models/CommentsModel.dart';
import 'package:trace/ui/text_with_tap.dart';

import '../../../helpers/quick_actions.dart';
import '../../../helpers/quick_cloud.dart';
import '../../../helpers/quick_help.dart';
import '../../../models/NotificationsModel.dart';
import '../../../models/PostsModel.dart';
import '../../../models/ReportModel.dart';
import '../../../models/UserModel.dart';
import '../../../ui/button_with_icon.dart';
import '../../../ui/container_with_corner.dart';
import '../../../utils/colors.dart';
import '../../../widgets/hashtagable/widgets/hashtag_text.dart';
import '../video_reels_comments_screen.dart';

// ignore: must_be_immutable
class DefaultVideoInfoWidget extends StatelessWidget {
  PostsModel? postModel;
  UserModel? currentUser;

  DefaultVideoInfoWidget({this.postModel, this.currentUser});

  TextEditingController textEditingController = TextEditingController();
  bool following = false;

  @override
  Widget build(BuildContext context) {
    if (currentUser!.getFollowing!.contains(postModel!.getAuthor!.objectId)) {
      following = true;
    } else {
      following = false;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              /// Username, time, brand information
              ///
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _userNameAndTimeUploadedWidget(context),
                  SizedBox(height: 8.0),

                  /// rainbow brand
                  ///
                  _rainBowBrandWidget(),
                  SizedBox(height: 8.0),

                  /// song name

                  //_hashtagWidget(),
                  SizedBox(height: 8.0),

                  if (postModel!.getText != null &&
                      postModel!.getText!.isNotEmpty)
                    _descriptionWidget(),
                  SizedBox(height: 8.0),
                ],
              ),

              /// Like, more.
              _likeWidget(context),

              //_likeMoreWidget()
            ],
          ),
        ),
      ],
    );
  }

  /// Like heart icon: tap to increase like number
  /// More option: tap to share or edit
  ///
  Widget _likeWidget(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: LikeButton(
              size: 37,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              countPostion: CountPostion.top,
              circleColor:
                  CircleColor(start: kPrimaryColor, end: kPrimaryColor),
              bubblesColor: BubblesColor(
                dotPrimaryColor: kPrimaryColor,
                dotSecondaryColor: kPrimaryColor,
              ),
              isLiked: postModel!.getLikes.contains(currentUser!.objectId),
              likeCountAnimationType: LikeCountAnimationType.all,
              likeBuilder: (bool isLiked) {
                return Icon(
                  isLiked ? Icons.favorite : Icons.favorite_outline_outlined,
                  color: isLiked ? kPrimaryColor : Colors.white,
                  size: 30,
                );
              },
              likeCount: postModel!.getLikes.length,
              countBuilder: (count, bool isLiked, String text) {
                var color = isLiked ? Colors.white : Colors.white;
                Widget result;
                if (count == 0) {
                  result = Text(
                    "",
                    style: TextStyle(color: color),
                  );
                } else
                  result = Text(
                    QuickHelp.convertNumberToK(count!),
                    style: TextStyle(color: color),
                  );
                return result;
              },
              onTap: (isLiked) {
                print("Liked: $isLiked");

                if (isLiked) {
                  //postModel!.removeLike = currentUser!.objectId!;

                  postModel!.save().then((value) {
                    postModel = value.results!.first as PostsModel;
                  });

                  _deleteLike(postModel!);

                  return Future.value(false);
                } else {
                  //postModel!.setLikes = currentUser!.objectId!;
                  postModel!.setLastLikeAuthor = currentUser!;

                  postModel!.save().then((value) {
                    postModel = value.results!.first as PostsModel;
                  });

                  _likePost(postModel!);

                  return Future.value(true);
                }
              },
            ),
          ),
          Visibility(
            visible: currentUser!.objectId != postModel!.getAuthor!.objectId!,
            child: SizedBox(height: 10),
          ),
          Visibility(
            visible: currentUser!.objectId != postModel!.getAuthor!.objectId!,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: LikeButton(
                size: 37,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                countPostion: CountPostion.top,
                circleColor:
                    CircleColor(start: kPrimaryColor, end: kPrimaryColor),
                bubblesColor: BubblesColor(
                  dotPrimaryColor: kPrimaryColor,
                  dotSecondaryColor: kPrimaryColor,
                ),
                isLiked: postModel!.getSaves.contains(currentUser!.objectId),
                likeCountAnimationType: LikeCountAnimationType.all,
                likeBuilder: (bool isLiked) {
                  return Icon(
                    isLiked ? Icons.bookmark : Icons.bookmark_border_outlined,
                    color: isLiked ? kPrimaryColor : Colors.white,
                    size: 37,
                  );
                },
                likeCount: postModel!.getSaves.length,
                countBuilder: (count, bool isLiked, String text) {
                  var color = isLiked ? Colors.white : Colors.white;
                  Widget result;
                  if (count == 0) {
                    result = Text(
                      "",
                      style: TextStyle(color: color),
                    );
                  } else
                    result = Text(
                      QuickHelp.convertNumberToK(count!),
                      style: TextStyle(color: color),
                    );
                  return result;
                },
                onTap: (isLiked) {
                  print("Liked: $isLiked");

                  if (isLiked) {
                    //postModel!.removeSave = currentUser!.objectId!;

                    postModel!.save().then((value) {
                      postModel = value.results!.first as PostsModel;
                    });

                    return Future.value(false);
                  } else {
                    //postModel!.setSaved = currentUser!.objectId!;

                    postModel!.save().then((value) {
                      postModel = value.results!.first as PostsModel;
                    });

                    return Future.value(true);
                  }
                },
              ),
            ),
          ),
          SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FutureBuilder<int>(
              future: QuickHelp.getCommentsCount(postModel!.objectId!),
              builder: (context, snapshot) {
                int commentsCount = snapshot.data ?? 0;
                return LikeButton(
                  size: 37,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  countPostion: CountPostion.top,
                  circleColor:
                      CircleColor(start: kPrimaryColor, end: kPrimaryColor),
                  bubblesColor: BubblesColor(
                    dotPrimaryColor: kPrimaryColor,
                    dotSecondaryColor: kPrimaryColor,
                  ),
                  isLiked: false,
                  likeCountAnimationType: LikeCountAnimationType.none,
                  likeBuilder: (bool isLiked) {
                    return Icon(
                      isLiked
                          ? Icons.mode_comment_rounded
                          : Icons.mode_comment_rounded,
                      color: Colors.white,
                      size: 30,
                    );
                  },
                  likeCount: commentsCount,
                  countBuilder: (count, bool isLiked, String text) {
                    var color = isLiked ? Colors.white : Colors.white;
                    Widget result;
                    if (count == 0) {
                      result = Text(
                        "",
                        style: TextStyle(color: color),
                      );
                    } else
                      result = Text(
                        QuickHelp.convertNumberToK(count!),
                        style: TextStyle(color: color),
                      );
                    return result;
                  },
                  onTap: (isLiked) {
                    print("Liked: $isLiked");

                    //openComments(context, currentUser!, postModel!);
                    QuickHelp.goToNavigatorScreen(
                      context,
                      VideoReelsCommentScreen(
                        currentUser: currentUser,
                        post: postModel,
                      ),
                    );

                    return Future.value(false);
                    /*if (isLiked) {

                      return Future.value(false);
                    } else {

                      return Future.value(false);
                    }*/
                  },
                );
              },
            ),
          ),
          SizedBox(height: 15),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: EdgeInsets.only(right: 5),
              child: InkWell(
                onTap: () {
                  openSheet(context, postModel!.getAuthor!, postModel!);
                },
                child: Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _descriptionWidget() {
    return Container(
      width: 220,
      //height: 20,
      child: TextWithTap(
        postModel!.getText!,
        color: Colors.white,
        fontSize: 14,
        selectableText: false,
        urlDetectable: true,
        humanize: true,
        overflow: TextOverflow.fade,
      ),
    );
  }

  Widget _hashtagWidget() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 220,
          height: 20,
          child: HashTagText(
            text: "#welcome #trace #reels",
            decoratedStyle: TextStyle(
                fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
            basicStyle: TextStyle(fontSize: 14, color: Colors.white),
            onTap: (text) {
              print(text);
            },
          ),
        )
      ],
    );
  }

  /// Rainbow branch information
  Widget _rainBowBrandWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.watch_later_outlined,
          color: Colors.white,
          size: 16,
        ),
//        Image(
//          image: ,
//          width: 16,
//          height: 16,
//          color:  Colors.white,
//        ),
        SizedBox(width: 8.0),
        Container(
          width: 220,
          child: Text(
            QuickHelp.getTimeAgoForFeed(postModel!.createdAt!),
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// Show user name and the time video uploaded

  goToProfile(BuildContext context, {UserModel? author}) {
    if (author!.objectId == currentUser!.objectId!) {
      QuickHelp.goToNavigatorScreen(
        context,
        ReelsVideosScreen(
          currentUser: currentUser,
        ),
      );
    } else {
      QuickHelp.goToNavigatorScreen(
        context,
        ReelsVideosScreen(
          currentUser: currentUser,
          mUser: author,
        ),
      );
    }
  }

  Widget _userNameAndTimeUploadedWidget(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => goToProfile(context, author: postModel!.getAuthor!),
          child: QuickActions.avatarWidget(
            postModel!.getAuthor!,
            width: 45,
            height: 45,
            margin: EdgeInsets.only(bottom: 0, top: 0, left: 0, right: 5),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextWithTap(
              postModel!.getAuthor!.getFullName!,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(1.0),
              fontSize: 15,
              marginLeft: 3,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  "assets/svg/ic_diamond.svg",
                  height: 20,
                ),
                TextWithTap(
                  "${postModel!.getAuthor!.getDiamondsTotal.toString()}",
                  color: Colors.white,
                  fontSize: 13,
                ),
                VerticalDivider(),
                SvgPicture.asset(
                  "assets/svg/ic_followers_active.svg",
                  height: 19,
                ),
                TextWithTap(
                  "${postModel!.getAuthor!.getFollowers!.length.toString()}",
                  color: Colors.white,
                  fontSize: 13,
                ),
              ],
            )
          ],
        ),
        Visibility(
          visible: currentUser!.objectId != postModel!.getAuthor!.objectId,
          child: _followWidget(context),
        ),
      ],
    );
    /*return Text(
      postModel!.getAuthor!.getFullName!,
      style: TextStyle(color: Colors.white),
    );*/
  }

  Widget _followWidget(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      margin: EdgeInsets.only(left: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: LikeButton(
              size: 37,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              countPostion: CountPostion.top,
              circleColor:
                  CircleColor(start: kPrimaryColor, end: kPrimaryColor),
              bubblesColor: BubblesColor(
                dotPrimaryColor: kPrimaryColor,
                dotSecondaryColor: kPrimaryColor,
              ),
              isLiked: following,
              likeCountAnimationType: LikeCountAnimationType.none,
              likeBuilder: (bool isLiked) {
                return ContainerCorner(
                  //marginLeft: 10,
                  //marginRight: 6,
                  colors: [
                    isLiked ? Colors.black.withOpacity(0.4) : kPrimaryColor,
                    isLiked ? Colors.black.withOpacity(0.4) : kPrimaryColor
                  ],
                  child: ContainerCorner(
                      color: kTransparentColor,
                      //marginAll: 5,
                      height: 30,
                      width: 30,
                      child: Icon(
                        isLiked ? Icons.done : Icons.add,
                        color: Colors.white,
                        //isLiked ? kPrimaryColor : Colors.white,
                        size: 24,
                      )),
                  borderRadius: 50,
                  height: 40,
                  width: 40,
                );
              },
              onTap: (isLiked) {
                print("Liked: $isLiked");

                if (isLiked) {
                  followOrUnfollow();

                  return Future.value(false);
                } else {
                  followOrUnfollow();

                  return Future.value(true);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  _deleteLike(PostsModel postsModel) async {
    QueryBuilder<NotificationsModel> queryBuilder =
        QueryBuilder<NotificationsModel>(NotificationsModel());
    queryBuilder.whereEqualTo(NotificationsModel.keyAuthor, currentUser);
    queryBuilder.whereEqualTo(NotificationsModel.keyPost, postsModel);

    ParseResponse parseResponse = await queryBuilder.query();

    if (parseResponse.success && parseResponse.results != null) {
      NotificationsModel notification = parseResponse.results!.first;
      await notification.delete();
    }
  }

  _likePost(PostsModel post) {
    QuickActions.createOrDeleteNotification(currentUser!, post.getAuthor!,
        NotificationsModel.notificationTypeLikedReels,
        post: post);
  }

  void openSheet(
      BuildContext context, UserModel author, PostsModel? post) async {
    showModalBottomSheet(
        context: (context),
        //isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isDismissible: true,
        builder: (__) {
          return _showPostOptionsAndReportAuthor(context, author, post: post);
        });
  }

  Widget _showPostOptionsAndReportAuthor(BuildContext context, UserModel author,
      {PostsModel? post}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.0),
          topRight: Radius.circular(25.0),
        ),
      ),
      child: post != null
          ? ContainerCorner(
              radiusTopRight: 20.0,
              radiusTopLeft: 20.0,
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Visibility(
                      visible: currentUser!.objectId != post.getAuthorId,
                      child: ButtonWithIcon(
                        text: "feed.report_post"
                            .tr(namedArgs: {"name": author.getFullName!}),
                        //iconURL: "assets/svg/ic_blocked_menu.svg",
                        icon: Icons.report_problem_outlined,
                        iconColor: kPrimaryColor,
                        iconSize: 26,
                        height: 60,
                        radiusTopLeft: 25.0,
                        radiusTopRight: 25.0,
                        backgroundColor: Colors.white,
                        mainAxisAlignment: MainAxisAlignment.start,
                        textColor: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        onTap: () {
                          openReportMessage(context, author, post);
                        },
                      ),
                    ),
                    Visibility(
                        visible: currentUser!.objectId != post.getAuthorId,
                        child: Divider()),
                    Visibility(
                      visible: currentUser!.objectId != post.getAuthorId,
                      child: ButtonWithIcon(
                        text: "feed.block_user"
                            .tr(namedArgs: {"name": author.getFullName!}),
                        textColor: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        //iconURL: "assets/images/ic_block_user.png",
                        icon: Icons.block,
                        iconColor: kPrimaryColor,
                        iconSize: 26,
                        onTap: () {
                          Navigator.of(context).pop();
                          QuickHelp.showDialogWithButtonCustom(
                            context: context,
                            title: "feed.post_block_title".tr(),
                            message: "feed.post_block_message"
                                .tr(namedArgs: {"name": author.getFullName!}),
                            cancelButtonText: "cancel".tr(),
                            confirmButtonText: "feed.post_block_confirm".tr(),
                            onPressed: () => _blockUser(context, author),
                          );
                        },
                        height: 60,
                        backgroundColor: Colors.white,
                        mainAxisAlignment: MainAxisAlignment.start,
                      ),
                    ),
                    Visibility(
                        visible: currentUser!.objectId != post.getAuthorId,
                        child: Divider()),
                    Visibility(
                      visible: currentUser!.objectId == post.getAuthorId ||
                          currentUser!.isAdmin!,
                      child: ButtonWithIcon(
                        text: "feed.delete_post".tr(),
                        iconURL: "assets/svg/config.svg",
                        height: 60,
                        radiusTopLeft: 25.0,
                        radiusTopRight: 25.0,
                        backgroundColor: Colors.white,
                        mainAxisAlignment: MainAxisAlignment.start,
                        textColor: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        onTap: () {
                          _deletePost(context, post);
                        },
                      ),
                    ),
                    Visibility(
                        visible: currentUser!.objectId == post.getAuthorId ||
                            currentUser!.isAdmin!,
                        child: Divider()),
                    Visibility(
                      visible: currentUser!.isAdmin!,
                      child: ButtonWithIcon(
                        text: "feed.suspend_user".tr(),
                        iconURL: "assets/svg/config.svg",
                        height: 60,
                        radiusTopLeft: 25.0,
                        radiusTopRight: 25.0,
                        backgroundColor: Colors.white,
                        mainAxisAlignment: MainAxisAlignment.start,
                        textColor: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        onTap: () {
                          _suspendUser(context, post.getAuthor!);
                        },
                      ),
                    ),
                    Visibility(
                        visible: currentUser!.isAdmin!, child: Divider()),
                  ],
                ),
              ),
            )
          : ContainerCorner(
              radiusTopRight: 20.0,
              radiusTopLeft: 20.0,
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Visibility(
                    visible: true,
                    child: ButtonWithIcon(
                      text: "feed.block_user"
                          .tr(namedArgs: {"name": author.getFullName!}),
                      textColor: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      iconURL: "assets/images/ic_block_user.png",
                      onTap: () {
                        Navigator.of(context).pop();
                        QuickHelp.showDialogWithButtonCustom(
                          context: context,
                          title: "feed.post_block_title".tr(),
                          message: "feed.post_block_message"
                              .tr(namedArgs: {"name": author.getFullName!}),
                          cancelButtonText: "cancel".tr(),
                          confirmButtonText: "feed.post_block_confirm".tr(),
                          onPressed: () => _blockUser(context, author),
                        );
                      },
                      height: 60,
                      backgroundColor: Colors.white,
                      mainAxisAlignment: MainAxisAlignment.start,
                    ),
                  ),
                  Visibility(visible: true, child: Divider()),
                  Visibility(
                    visible: currentUser!.isAdmin!,
                    child: ButtonWithIcon(
                      text: "feed.suspend_user".tr(),
                      iconURL: "assets/svg/config.svg",
                      height: 60,
                      radiusTopLeft: 25.0,
                      radiusTopRight: 25.0,
                      backgroundColor: Colors.white,
                      mainAxisAlignment: MainAxisAlignment.start,
                      textColor: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      onTap: () {
                        _suspendUser(context, post!.getAuthor!);
                      },
                    ),
                  ),
                  Visibility(visible: currentUser!.isAdmin!, child: Divider()),
                ],
              ),
            ),
    );
  }

  _blockUser(BuildContext context, UserModel author) async {
    Navigator.of(context).pop();
    QuickHelp.showLoadingDialog(context);

    currentUser!.setBlockedUser = author;
    currentUser!.setBlockedUserIds = author.objectId!;

    ParseResponse response = await currentUser!.save();
    if (response.success) {
      currentUser = response.results!.first as UserModel;

      QuickHelp.hideLoadingDialog(context);
      //QuickHelp.goToNavigator(context, BlockedUsersScreen.route);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "feed.post_block_success_title"
            .tr(namedArgs: {"name": author.getFullName!}),
        message: "feed.post_block_success_message".tr(),
        isError: false,
      );
    } else {
      QuickHelp.hideLoadingDialog(context);
    }
  }

  void openReportMessage(
      BuildContext context, UserModel author, PostsModel post) async {
    showModalBottomSheet(
        context: (context),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isDismissible: true,
        builder: (context) {
          return _showReportMessageBottomSheet(context, author, post);
        });
  }

  Widget _showReportMessageBottomSheet(
      BuildContext context, UserModel author, PostsModel post) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Color.fromRGBO(0, 0, 0, 0.001),
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.1,
            maxChildSize: 1.0,
            builder: (_, controller) {
              return StatefulBuilder(builder: (context, setState) {
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
                    color: QuickHelp.isDarkMode(context)
                        ? kContentColorLightTheme
                        : Colors.white,
                    child: Column(
                      children: [
                        ContainerCorner(
                          color: kGreyColor1,
                          width: 50,
                          marginTop: 5,
                          borderRadius: 50,
                          marginBottom: 10,
                        ),
                        TextWithTap(
                          "feed.report_".tr(),
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          marginBottom: 50,
                        ),
                        Column(
                          children: List.generate(
                              QuickHelp.getReportCodeMessageList().length,
                              (index) {
                            String code =
                                QuickHelp.getReportCodeMessageList()[index];

                            return TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                print("Message: " +
                                    QuickHelp.getReportMessage(code));
                                Navigator.of(context).pop();
                                _saveReport(context,
                                    QuickHelp.getReportMessage(code), post);
                              },
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                  Divider(
                                    height: 1.0,
                                  )
                                ],
                              ),
                            );
                          }),
                        ),
                        ContainerCorner(
                          marginTop: 30,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: TextWithTap(
                              "cancel".tr().toUpperCase(),
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
              });
            },
          ),
        ),
      ),
    );
  }

  _saveReport(BuildContext context, String reason, PostsModel post) async {
    QuickHelp.showLoadingDialog(context);

    currentUser?.setReportedPostIDs = post.objectId;
    currentUser?.setReportedPostReason = reason;

    ParseResponse response = await currentUser!.save();
    if (response.success) {
      QuickHelp.hideLoadingDialog(context);
      //setState(() {});
    } else {
      QuickHelp.hideLoadingDialog(context);
    }

    ParseResponse parseResponse = await QuickActions.report(
        type: ReportModel.reportTypePost,
        message: reason,
        accuser: currentUser!,
        accused: post.getAuthor!,
        postsModel: post);

    if (parseResponse.success) {
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "feed.post_report_success_title"
            .tr(namedArgs: {"name": post.getAuthor!.getFullName!}),
        message: "feed.post_report_success_message".tr(),
        isError: false,
      );
    } else {
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "error".tr(),
        message: "try_again_later".tr(),
      );
    }
  }

  _deletePost(BuildContext context, PostsModel post) {
    QuickHelp.goBackToPreviousPage(context);

    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: "feed.delete_post_alert".tr(),
      message: "feed.delete_post_message".tr(),
      cancelButtonText: "no".tr(),
      confirmButtonText: "feed.yes_delete".tr(),
      onPressed: () => _confirmDeletePost(context, post),
    );
  }

  _suspendUser(BuildContext context, UserModel user) {
    QuickHelp.goBackToPreviousPage(context);

    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: "feed.suspend_user_alert".tr(),
      message: "feed.suspend_user_message".tr(),
      cancelButtonText: "no".tr(),
      confirmButtonText: "feed.yes_suspend".tr(),
      onPressed: () => _confirmSuspendUser(context, user),
    );
  }

  _confirmSuspendUser(BuildContext context, UserModel userModel) async {
    QuickHelp.goBackToPreviousPage(context);

    QuickHelp.showLoadingDialog(context);

    userModel.setActivationStatus = true;
    ParseResponse parseResponse =
        await QuickCloudCode.suspendUSer(objectId: userModel.objectId!);
    if (parseResponse.success) {
      QuickHelp.goBackToPreviousPage(context);

      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "suspended".tr(),
        message: "feed.user_suspended".tr(),
        user: userModel,
        isError: null,
      );
    } else {
      QuickHelp.goBackToPreviousPage(context);

      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "error".tr(),
        message: "feed.user_not_suspended".tr(),
        user: userModel,
        isError: true,
      );
    }
  }

  _confirmDeletePost(BuildContext context, PostsModel postsModel) async {
    QuickHelp.goBackToPreviousPage(context);

    QuickHelp.showLoadingDialog(context);

    ParseResponse parseResponse = await postsModel.delete();
    if (parseResponse.success) {
      QuickHelp.goBackToPreviousPage(context);

      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "deleted".tr(),
        message: "feed.post_deleted".tr(),
        user: postsModel.getAuthor,
        isError: null,
      );
    } else {
      QuickHelp.goBackToPreviousPage(context);

      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "error".tr(),
        message: "feed.post_not_deleted".tr(),
        user: postsModel.getAuthor,
        isError: true,
      );
    }
  }

  bool showPost(PostsModel post) {
    if (post.getExclusive!) {
      if (post.getAuthorId == currentUser!.objectId) {
        return true;
      } else if (post.getPaidBy!.contains(currentUser!.objectId)) {
        return true;
      } else if (currentUser!.isAdmin!) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  }

  void followOrUnfollow() async {
    if (currentUser!.getFollowing!.contains(postModel!.getAuthor!.objectId)) {
      currentUser!.removeFollowing = postModel!.getAuthor!.objectId!;

      following = false;
    } else {
      currentUser!.setFollowing = postModel!.getAuthor!.objectId!;

      following = true;
    }

    await currentUser!.save();

    ParseResponse parseResponse = await QuickCloudCode.followUser(
        author: currentUser!, receiver: postModel!.getAuthor!);

    if (parseResponse.success) {
      QuickActions.createOrDeleteNotification(currentUser!,
          postModel!.getAuthor!, NotificationsModel.notificationTypeFollowers);
    }
  }

  void showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useRootNavigator: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: new BoxDecoration(
          color: Colors.white,
          borderRadius: new BorderRadius.only(
            topLeft: const Radius.circular(25.0),
            topRight: const Radius.circular(25.0),
          ),
        ),
        child: Column(
          children: [
            TextWithTap(
              "feed.reels_video_comments".tr(),
              fontWeight: FontWeight.w900,
              fontSize: 17,
              marginBottom: 20,
              marginTop: 10,
            ),
            Expanded(
              child: liveComments(context),
            ),
            SafeArea(
              child: Form(
                key: key,
                child: SingleChildScrollView(
                  //reverse: true,
                  child: AnimatedPadding(
                    padding: MediaQuery.of(context).viewInsets,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.decelerate,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: [
                            Expanded(
                              child: ContainerCorner(
                                borderRadius: 30,
                                color: kGrayColor,
                                marginLeft: 10,
                                marginTop: 10,
                                marginRight: 5,
                                marginBottom: 10,
                                padding:
                                    const EdgeInsets.only(left: 10, right: 10),
                                child: TextFormField(
                                  controller: textEditingController,
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  minLines: 1,
                                  decoration: InputDecoration(
                                      hintText:
                                          "feed.reels_video_comment_here".tr(),
                                      hintStyle:
                                          TextStyle(color: kColorsGrey300),
                                      border: InputBorder.none),
                                ),
                              ),
                            ),
                            ContainerCorner(
                              marginLeft: 10,
                              marginRight: 10,
                              color: kGrayColor,
                              child: ContainerCorner(
                                color: kTransparentColor,
                                marginAll: 8,
                                height: 30,
                                width: 30,
                                child: SvgPicture.asset(
                                  "assets/svg/ic_send_message.svg",
                                  color: Colors.white,
                                  height: 10,
                                  width: 30,
                                ),
                              ),
                              borderRadius: 50,
                              height: 50,
                              width: 50,
                              onTap: () {
                                if (textEditingController.text.isNotEmpty) {
                                  _createComment(context, postModel!,
                                      textEditingController.text);
                                  textEditingController.clear();

                                  if (FocusScope.of(context).hasFocus) {
                                    FocusScope.of(context).unfocus();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget liveComments(BuildContext context) {
    QueryBuilder<CommentsModel> queryBuilder =
        QueryBuilder<CommentsModel>(CommentsModel());
    queryBuilder.whereEqualTo(CommentsModel.keyPostId, postModel!.objectId);

    queryBuilder.includeObject([
      CommentsModel.keyAuthor,
      CommentsModel.keyPost,
    ]);
    queryBuilder.orderByDescending(CommentsModel.keyCreatedAt);

    return GestureDetector(
      onTap: () {
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
        }
      },
      child: ParseLiveListWidget<CommentsModel>(
        query: queryBuilder,
        key: Key(postModel!.objectId!),
        duration: Duration(microseconds: 500),
        lazyLoading: false,
        shrinkWrap: true,
        //primary: true,
        childBuilder: (BuildContext context,
            ParseLiveListElementSnapshot<CommentsModel> snapshot) {
          CommentsModel comment = snapshot.loadedData!;

          return GestureDetector(
            onTap: () {
              if (FocusScope.of(context).hasFocus) {
                FocusScope.of(context).unfocus();
              }

              goToProfile(context, author: comment.getAuthor!);

              //QuickActions.showUserProfile(context, currentUser!, comment.getAuthor!);
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 15, top: 10),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      QuickActions.avatarWidget(comment.getAuthor!,
                          width: 40, height: 40),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWithTap(
                              comment.getAuthor!.getFullName!,
                              marginLeft: 10,
                              marginBottom: 5,
                              fontWeight: FontWeight.bold,
                              //color: kGrayColor,
                              fontSize: 14,
                            ),
                            TextWithTap(
                              comment.getText!,
                              marginLeft: 10,
                              marginRight: 10,
                              fontSize: 14,
                              //color: kGrayColor,
                            ),
                            TextWithTap(
                              QuickHelp.getTimeAgoForFeed(comment.createdAt!),
                              marginLeft: 10,
                              color: kGrayDark,
                              marginTop: 10,
                              fontSize: 11,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  )
                ],
              ),
            ),
          );
        },
        listLoadingElement: QuickHelp.showLoadingAnimation(size: 30),
        queryEmptyElement: QuickActions.noContentFound(context),
      ),
    );
  }

  _createComment(BuildContext context, PostsModel post, String text) async {
    QuickHelp.showLoadingDialog(context);

    CommentsModel comment = CommentsModel();
    comment.setAuthor = currentUser!;
    comment.setText = text;
    comment.setAuthorId = currentUser!.objectId!;
    comment.setPostId = post.objectId!;
    comment.setPost = post;

    await comment.save();

    // Add the comment to the post's comments list
    post.addComment = comment;
    await post.save();

    QuickHelp.hideLoadingDialog(context);

    QuickActions.createOrDeleteNotification(currentUser!, post.getAuthor!,
        NotificationsModel.notificationTypeCommentReels,
        post: post);
  }
}
