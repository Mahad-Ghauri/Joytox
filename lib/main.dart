// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:trace/app/setup.dart';
import 'package:trace/auth/dispache_screen.dart';
import 'package:trace/auth/forgot_screen.dart';
import 'package:trace/auth/responsive_welcome_screen.dart';
import 'package:trace/home/reels/reels_home_screen.dart';
import 'package:trace/home/message/message_list_screen.dart';
import 'package:trace/home/coins/refill_coins_screen.dart';
import 'package:trace/auth/welcome_screen.dart';
import 'package:trace/home/leaders/leaders_screen.dart';
import 'package:trace/home/live/live_preview.dart';
import 'package:trace/home/menu/blocked_users_screen.dart';
import 'package:trace/home/menu/get_money_screen.dart';
import 'package:trace/home/menu/settings_screen.dart';
import 'package:trace/home/menu/statistics_screen.dart';
import 'package:trace/home/message/message_screen.dart';
import 'package:trace/home/profile/profile_edit.dart';
import 'package:trace/home/profile/profile_screen.dart';
import 'package:trace/home/profile/profile_menu_screen.dart';
import 'package:trace/home/profile/user_profile_screen.dart';
import 'package:trace/home/web/web_url_screen.dart';
import 'package:trace/models/CallsModel.dart';
import 'package:trace/models/CommentsModel.dart';
import 'package:trace/models/GiftsModel.dart';
import 'package:trace/models/GiftsSentModel.dart';
import 'package:trace/models/HashtagsModel.dart';
import 'package:trace/models/InvitedUsersModel.dart';
import 'package:trace/models/LeadersModel.dart';
import 'package:trace/models/MessageModel.dart';
import 'package:trace/models/NotificationsModel.dart';
import 'package:trace/models/PictureModel.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/ReportModel.dart';
import 'package:trace/models/WithdrawModel.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/utils/colors.dart';
import 'package:trace/utils/theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'controllers/feed_controller.dart';
import 'home/a_shorts/shorts_cached_controller.dart';
import 'home/responsive_home_screen.dart';
import 'home/feed/create_pictures_post_screen.dart';
import 'home/feed/create_video_post_screen.dart';
import 'home/feed/video_player_screen.dart';
import 'home/feed/visualize_multiple_pictures_screen.dart';
import 'home/leaders/select_country.dart';
import 'home/menu/withdraw_history_screen.dart';
import 'home/official_announcement/official_announcement_screen.dart';
import 'home/report/report_screen.dart';
import 'models/AgencyInvitationModel.dart';
import 'models/HostModel.dart';
import 'models/ObtainedItemsModel.dart';
import 'models/CoinsTransactionsModel.dart';
import 'models/FanClubMembersModel.dart';
import 'models/FanClubModel.dart';
import 'models/GiftReceivedModel.dart';
import 'models/GiftSendersGlobalModel.dart';
import 'models/GiftSendersModel.dart';
import 'models/LiveViewersModel.dart';
import 'models/MedalsModel.dart';
import 'models/NewPaymentMethodResquestModel.dart';
import 'models/OfficialAnnouncementModel.dart';
import 'models/PCoinsTransactionsModel.dart';
import 'models/PaymentsModel.dart';
import 'models/PointsTransactionsModel.dart';
import 'models/PostReactionsModel.dart';
import 'models/ReplyModel.dart';
import 'models/StoriesAuthorsModel.dart';
import 'models/StoriesModel.dart';
import 'models/VisitsModel.dart';
import 'app/config.dart';

import 'home/feed/comment_post_screen.dart';
import 'home/location_screen.dart';
import 'home/menu/referral_program_screen.dart';
import 'home/notifications/notifications_screen.dart';
import 'models/LiveMessagesModel.dart';
import 'models/LiveStreamingModel.dart';
import 'models/MessageListModel.dart';
import 'package:get_storage/get_storage.dart';
import 'package:trace/models/VideoInteractionModel.dart';
import 'package:trace/views/video_creation_page.dart';
import 'package:trace/views/video_editor_screen.dart';
import 'package:trace/services/posts_service.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

// Constantes para o Parse Server
const String kParseApplicationId = "trace-app-id";
const String kParseServerUrl = "https://parseapi.back4app.com/";
const String kParseClientKey = "trace-client-key";
const bool kDebugMode = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

  await Firebase.initializeApp();

  await EasyLocalization.ensureInitialized();

  if (QuickHelp.isMobile()) {
    MobileAds.instance.initialize();
  }

  initPlatformState();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);

  Map<String, ParseObjectConstructor> subClassMap =
      <String, ParseObjectConstructor>{
    PictureModel.keyTableName: () => PictureModel(),
    PostsModel.keyTableName: () => PostsModel(),
    NotificationsModel.keyTableName: () => NotificationsModel(),
    MessageModel.keyTableName: () => MessageModel(),
    MessageListModel.keyTableName: () => MessageListModel(),
    CommentsModel.keyTableName: () => CommentsModel(),
    LeadersModel.keyTableName: () => LeadersModel(),
    GiftsModel.keyTableName: () => GiftsModel(),
    GiftsSentModel.keyTableName: () => GiftsSentModel(),
    LiveStreamingModel.keyTableName: () => LiveStreamingModel(),
    HashTagModel.keyTableName: () => HashTagModel(),
    LiveMessagesModel.keyTableName: () => LiveMessagesModel(),
    WithdrawModel.keyTableName: () => WithdrawModel(),
    PaymentsModel.keyTableName: () => PaymentsModel(),
    InvitedUsersModel.keyTableName: () => InvitedUsersModel(),
    CallsModel.keyTableName: () => CallsModel(),
    GiftsSenderModel.keyTableName: () => GiftsSenderModel(),
    GiftsSenderGlobalModel.keyTableName: () => GiftsSenderGlobalModel(),
    ReportModel.keyTableName: () => ReportModel(),
    LiveViewersModel.keyTableName: () => LiveViewersModel(),
    OfficialAnnouncementModel.keyTableName: () => OfficialAnnouncementModel(),
    VisitsModel.keyTableName: () => VisitsModel(),
    CoinsTransactionsModel.keyTableName: () => CoinsTransactionsModel(),
    PointsTransactionsModel.keyTableName: () => PointsTransactionsModel(),
    PCoinsTransactionsModel.keyTableName: () => PCoinsTransactionsModel(),
    GiftsReceivedModel.keyTableName: () => GiftsReceivedModel(),
    NewPaymentMethodRequest.keyTableName: () => NewPaymentMethodRequest(),
    MedalsModel.keyTableName: () => MedalsModel(),
    FanClubModel.keyTableName: () => FanClubModel(),
    FanClubMembersModel.keyTableName: () => FanClubMembersModel(),
    ObtainedItemsModel.keyTableName: () => ObtainedItemsModel(),
    HostModel.keyTableName: () => HostModel(),
    AgencyInvitationModel.keyTableName: () => AgencyInvitationModel(),
    StoriesAuthorsModel.keyTableName: () => StoriesAuthorsModel(),
    StoriesModel.keyTableName: () => StoriesModel(),
    ReplyModel.keyTableName: () => ReplyModel(),
    PostReactionsModel.keyTableName: () => PostReactionsModel(),
    VideoInteractionModel.keyTableName: () => VideoInteractionModel(),
  };

  await Parse().initialize(
    Config.appId,
    Config.serverUrl,
    clientKey: Config.clientKey,
    liveQueryUrl: Config.liveQueryUrl,
    autoSendSessionId: true,
    appName: Setup.appName,
    appPackageName: Setup.appPackageName,
    appVersion: Setup.appVersion,
    locale: await Devicelocale.currentLocale,
    parseUserConstructor: (username, password, email,
            {client, debug, sessionToken}) =>
        UserModel(username, password, email),
    registeredSubClassMap: subClassMap,
  );

  // Registrar e iniciar serviços essenciais
  final postsService = PostsService();
  Get.put(postsService, permanent: true);
  Get.put(ShortsCachedController());

  ZegoUIKit().initLog().then((value) {
    ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI(
      [ZegoUIKitSignalingPlugin()],
    );
    runApp(
      EasyLocalization(
        supportedLocales: QuickHelp.getLanguages(Setup.languages),
        path: 'assets/translations',
        fallbackLocale: Locale(Setup.languages[0]),
        child: App(),
      ),
    );
  });
}

Future<void> initPlatformState() async {
  if (Setup.isDebug && !QuickHelp.isWebPlatform()) {
    await Purchases.setLogLevel(LogLevel.verbose);
  }

  PurchasesConfiguration? configuration;

  if (QuickHelp.isAndroidPlatform()) {
    configuration = PurchasesConfiguration(Config.publicGoogleSdkKey);
  } else if (QuickHelp.isIOSPlatform()) {
    configuration = PurchasesConfiguration(Config.publicIosSdkKey);
  }
  if (!QuickHelp.isWebPlatform()) {
    await Purchases.configure(configuration!);
  }
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  UserModel? currentUser;
  bool _initializingFeed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      getCurrentUser();
      //QuickHelp.saveCurrentRoute(route: HomeScreen.route);
      print("AppState: resumed");

      // Pré-carrega o feed quando o app é retomado
      _preloadFeed();
    } else {
      RemoveOnline();
      QuickHelp.saveCurrentRoute(route: "background");
      print("AppState: background / closed");
    }
  }

  @override
  void dispose() {
    RemoveOnline();
    super.dispose();
  }

  getCurrentUser() async {
    try {
      currentUser = await ParseUser.currentUser();
      if (currentUser != null) {
        currentUser!.setLastOnline = DateTime.now();
        currentUser!.setUserStateInApp = UserModel.userOnline;
        ParseACL acl = ParseACL();
        acl.setPublicReadAccess(allowed: true);
        currentUser!.setACL(acl);
        await currentUser!.save();

        // Após obter o usuário atual, pré-carrega o feed
        _preloadFeed();

        return currentUser;
      }
    } catch (e) {
      print("Erro ao obter usuário atual: $e");
    }
    return null;
  }

  // Método para pré-carregar o feed em segundo plano
  void _preloadFeed() {
    if (_initializingFeed || currentUser == null) return;
    _initializingFeed = true;

    try {
      FeedController feedController;
      try {
        feedController = Get.find<FeedController>();
      } catch (e) {
        print("Criando nova instância de FeedController");
        feedController =
            Get.put(FeedController(currentUser: currentUser!), permanent: true);
      }

      try {
        feedController.setCurrentUser(currentUser!);
        print("Pré-carregando feed em segundo plano");
      } catch (e) {
        print("Erro ao definir usuário atual no feed: $e");
      }

      // Define um timeout para garantir que o carregamento seja concluído
      Future.delayed(Duration(seconds: 5), () {
        _initializingFeed = false;
      });
    } catch (e) {
      print("Erro ao pré-carregar feed: $e");
      _initializingFeed = false;
    }
  }

  RemoveOnline() async {
    currentUser = await ParseUser.currentUser();
    if (currentUser != null) {
      currentUser!.setLastOnline = DateTime.now();
      currentUser!.setUserStateInApp = UserModel.userOffline;
      ParseACL acl = ParseACL();
      acl.setPublicReadAccess(allowed: true);
      currentUser!.setACL(acl);
      await currentUser!.save();
    }
  }

  @override
  void initState() {
    //Get.put(ReelsController(currentUser: currentUser));

    getCurrentUser().then((user) {
      if (user != null) {
        print("Usuário atual encontrado: ${user.objectId}");
        try {
          FeedController feedController = Get.find<FeedController>();
          feedController.setCurrentUser(user);
          print("CurrentUser definido no FeedController");
        } catch (e) {
          print("Erro ao definir CurrentUser: $e");
        }
      } else {
        print("Nenhum usuário atual encontrado");
      }
    });

    if (!QuickHelp.isWebPlatform()) {
      Future.delayed(Duration(seconds: 2), () async {
        await FlutterBranchSdk.init(
            enableLogging: true, disableTracking: false);
        //FlutterBranchSdk.validateSDKIntegration();
      });
    }

    WidgetsBinding.instance.addObserver(this);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: Setup.appName,
      debugShowCheckedModeBanner: false,
      theme: lightThemeData(context),
      darkTheme: darkThemeData(context),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      navigatorKey: navigatorKey,
      locale: context.locale,
      getPages: [
        // Video Editor Routes
        GetPage(
          name: '/video-creation',
          page: () => const VideoCreationPage(),
        ),
        GetPage(
          name: '/video-editor',
          page: () => VideoEditorScreen(
            videoPath: Get.arguments as String,
          ),
        ),
      ],
      routes: {
        //Before Login
        WelcomeScreen.route: (_) => WelcomeScreen(),
        ForgotScreen.route: (_) => ForgotScreen(),

        // Home and tabs
        //HomeScreen.route: (_) => HomeScreen(),
        ResponsiveHomeScreen.route: (_) => ResponsiveHomeScreen(),

        NotificationsScreen.route: (_) => NotificationsScreen(),
        LocationScreen.route: (_) => LocationScreen(),
        ReelsHomeScreen.route: (_) => ReelsHomeScreen(),

        //Profile
        ProfileMenuScreen.route: (_) => ProfileMenuScreen(),
        ProfileScreen.route: (_) => ProfileScreen(),
        ProfileEdit.route: (_) => ProfileEdit(),
        UserProfileScreen.route: (_) => UserProfileScreen(),

        //Chat
        MessagesListScreen.route: (_) => MessagesListScreen(),
        MessageScreen.route: (_) => MessageScreen(),

        //Feed
        CommentPostScreen.route: (_) => CommentPostScreen(),
        VisualizeMultiplePicturesScreen.route: (_) =>
            VisualizeMultiplePicturesScreen(),
        CreateVideoPostScreen.route: (_) => CreateVideoPostScreen(),
        CreatePicturesPostScreen.route: (_) => CreatePicturesPostScreen(),
        VideoPlayerScreen.route: (_) => VideoPlayerScreen(),

        //LiveStreaming
        LivePreviewScreen.route: (_) => LivePreviewScreen(),

        //Leaders
        LeadersPage.route: (_) => LeadersPage(),

        SelectCountryScreen.route: (_) => SelectCountryScreen(),

        //Report
        ReportScreen.route: (_) => ReportScreen(),

        // Menu
        StatisticsScreen.route: (_) => StatisticsScreen(),
        ReferralScreen.route: (_) => ReferralScreen(),
        BlockedUsersScreen.route: (_) => BlockedUsersScreen(),
        RefillCoinsScreen.route: (_) => RefillCoinsScreen(),
        GetMoneyScreen.route: (_) => GetMoneyScreen(),
        SettingsScreen.route: (_) => SettingsScreen(),
        WithdrawHistoryScreen.route: (_) => WithdrawHistoryScreen(),

        //Official Announcement
        OfficialAnnouncementScreen.route: (_) => OfficialAnnouncementScreen(),

        // Logged user or not
        QuickHelp.pageTypeTerms: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypeTerms),
        QuickHelp.pageTypePrivacy: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypePrivacy),
        QuickHelp.pageTypeHelpCenter: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypeHelpCenter),
        QuickHelp.pageTypeOpenSource: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypeOpenSource),
        QuickHelp.pageTypeSafety: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypeSafety),
        QuickHelp.pageTypeCommunity: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypeCommunity),
        QuickHelp.pageTypeInstructions: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypeInstructions),
        QuickHelp.pageTypeSupport: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypeSupport),
        QuickHelp.pageTypeCashOut: (_) =>
            WebViewScreen(pageType: QuickHelp.pageTypeCashOut),
      },
      home: FutureBuilder<UserModel?>(
          future: QuickHelp.getUserAwait(),
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return Scaffold(
                  body: QuickHelp.appLoadingLogo(),
                );
              default:
                if (snapshot.hasData) {
                  UserModel? getUser = snapshot.data;
                  if (getUser == null) {
                    return DispacheScreen(
                      currentUser: currentUser,
                    );
                  } else {
                    return DispacheScreen(
                      currentUser: getUser,
                    );
                  }
                } else {
                  logoutUserPurchase();

                  return QuickHelp.isMobile()
                      ? WelcomeScreen()
                      : ResponsiveWelcomeScreen();
                }
            }
          }),
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: [
            child!,

            /// support minimizing
            ZegoUIKitPrebuiltLiveStreamingMiniOverlayPage(
              showLeaveButton: false,
              soundWaveColor: kBlueDark,
              backgroundBuilder: (BuildContext context, Size size,
                  ZegoUIKitUser? user, Map extraInfo) {
                return user != null
                    ? Image.asset(
                        "assets/images/audio_bg_start.png",
                        height: size.height,
                        width: size.width,
                        fit: BoxFit.fill,
                      )
                    : const SizedBox();
              },
              contextQuery: () {
                return navigatorKey.currentState!.context;
              },
            ),
          ],
        );
      },
    );
  }

  logoutUserPurchase() async {
    if (!await Purchases.isAnonymous) {
      await Purchases.logOut().then((value) => print("purchase logout"));
    }
  }
}
