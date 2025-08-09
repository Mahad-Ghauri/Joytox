// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/home/feed/responsive_feed_screen.dart';
import 'package:trace/ui/container_with_corner.dart';
import 'package:trace/utils/colors.dart';

import '../models/NotificationsModel.dart';
import '../models/UserModel.dart';
import '../ui/text_with_tap.dart';

class ResponsiveHomeScreen extends StatefulWidget {
  static const String route = '/responsive/home';
  UserModel? currentUser;
  ResponsiveHomeScreen({this.currentUser,  super.key});

  @override
  State<ResponsiveHomeScreen> createState() => _ResponsiveHomeScreenState();
}

class _ResponsiveHomeScreenState extends State<ResponsiveHomeScreen> {

  LiveQuery liveQuery = LiveQuery();
  Subscription? subscription;
  int unreadMessageMount = 0;

  late QueryBuilder<NotificationsModel> notificationQueryBuilder;

  getUnreadNotification() async {
    notificationQueryBuilder =
        QueryBuilder<NotificationsModel>(NotificationsModel());
    notificationQueryBuilder.whereEqualTo(
        NotificationsModel.keyReceiver, widget.currentUser!);
    notificationQueryBuilder.whereEqualTo(NotificationsModel.keyRead, false);

    notificationQueryBuilder.whereNotEqualTo(
        NotificationsModel.keyAuthor, widget.currentUser!,
    );

    setupNotificationLiveQuery();

    ParseResponse parseResponse = await notificationQueryBuilder.query();

    if (parseResponse.success || parseResponse.count > 0) {
      unreadMessageMount += parseResponse.count;
      setState(() { });
    }
  }

  setupNotificationLiveQuery() async {
    subscription = await liveQuery.client.subscribe(notificationQueryBuilder);

    print('*** INITIALIZE_Live_query ***');

    subscription!.on(LiveQueryEvent.create,
            (NotificationsModel notification) async {
          print('*** CREATED_Live_query ***');

          if (notification.isRead!) {
            unreadMessageMount--;
          } else {
            unreadMessageMount++;
          }
        });

    subscription!.on(LiveQueryEvent.update,
            (NotificationsModel notification) async {
          print('*** UPDATE_Live_query ***');
          if (notification.isRead!) {
            unreadMessageMount--;
          } else {
            unreadMessageMount++;
          }
        });

    subscription!.on(LiveQueryEvent.enter,
            (NotificationsModel notification) async {
          print('*** ENTER_Live_query ***');
          if (notification.isRead!) {
            unreadMessageMount--;
          } else {
            unreadMessageMount++;
          }
        });

    subscription!.on(LiveQueryEvent.leave,
            (NotificationsModel notification) async {
          print('*** Leave_Live_query ***');
          if (notification.isRead!) {
            unreadMessageMount--;
          } else {
            unreadMessageMount++;
          }
        },
    );
  }


  @override
  void initState() {
    super.initState();
    getUnreadNotification();
  }


  @override
  void dispose() {
    super.dispose();
    if (subscription != null) {
      liveQuery.client.unSubscribe(subscription!);
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    bool isDark = QuickHelp.isDarkMode(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark ? kContentDarkShadow : kGrayWhite,
        leading: IconButton(
          icon: Image.asset(
            "assets/images/ic_logo.png",
            height: 65,
            width: 65,
          ), onPressed: () {},
        ),
        title: IconButton(
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                color: isDark ? Colors.white : kContentDarkShadow,
                size: 20,
              ),
              TextWithTap(
                "search_everything".tr(),
                color: kGrayColor.withOpacity(0.5),
                fontSize: 15,
                marginLeft: 20,
                marginRight: 20,
                onTap: () {},
                ),
            ],
          ), onPressed: () {},
        ),
        actions: [
          ContainerCorner(
            borderWidth: 0,
            borderRadius: 50,
            marginRight: 20,
            height: 45,
            width: 45,
            color: isDark ? kContentColorLightTheme.withOpacity(0.7) : kGrayPro.withOpacity(0.7),
            child: IconButton(
              icon: SvgPicture.asset(
                "assets/svg/ic_messenger_logo.svg",
                height: 20,
                width: 20,
                color: isDark ? Colors.white : Colors.black,
              ), onPressed: () {},
            ),
          ),
          Stack(
            alignment: AlignmentDirectional.topEnd,
            clipBehavior: Clip.none,
            children: [
              ContainerCorner(
                borderWidth: 0,
                borderRadius: 50,
                height: 45,
                width: 45,
                color: isDark ? kContentColorLightTheme.withOpacity(0.7) : kGrayPro.withOpacity(0.7),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications,
                    color: isDark ? Colors.white : Colors.black,
                    size: 25,
                  ), onPressed: () {},
                ),
              ),
              Visibility(
                visible: unreadMessageMount > 0,
                child: ContainerCorner(
                  height: 17,
                  width: 17,
                  color: earnCashColor,
                  borderWidth: 0,
                  borderRadius: 4,
                  child: Center(
                    child: AutoSizeText(
                      "${QuickHelp.convertToK(unreadMessageMount)}",
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                      minFontSize: 5,
                      stepGranularity: 1,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20, left: 20),
            child: QuickActions.avatarWidget(
                widget.currentUser!,
              height: 40,
              width: 40,
            ),
          ),
        ],
      ),
      body: ContainerCorner(
        borderWidth: 0,
        width: size.width,
        height: size.height,
        child: Row(
          children: [
            Flexible(
              flex: 1,
                child: ContainerCorner(
                  borderWidth: 0,
                ),
            ),
            ContainerCorner(
              width: 650,
              child: ResponsiveFeedScreen(
                currentUser: widget.currentUser,
                size: 650,
              ),
            ),
            Flexible(
              flex: 1,
                child: ContainerCorner(
                  borderWidth: 0,
                ),
            ),
          ],
        ),
      ),
    );
  }
}
