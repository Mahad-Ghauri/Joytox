// ignore_for_file: deprecated_member_use
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/home/profile/tab_profile_screen.dart';
import 'package:trace/home/feed/feed_home_screen.dart';
import 'package:trace/models/UserModel.dart';
import 'package:flutter/material.dart';
import '../app/constants.dart';
import 'a_shorts/shorts_cached_view.dart';
import 'live/all_lives_screen.dart';
import 'message/message_list_screen.dart';
import 'controllers/home_controller.dart';

class HomeScreen extends StatefulWidget {
  final UserModel? currentUser;
  final int initialTabIndex;

  const HomeScreen({
    Key? key,
    required this.currentUser,
    this.initialTabIndex = 2,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late HomeController controller;
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = Get.put(HomeController(
      currentUser: widget.currentUser,
      initialTabIndex: widget.initialTabIndex,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller.handleAppLifecycleState(state);
  }

  void _loadAd() {
    if (!controller.isAdLoaded.value && _bannerAd == null) {
      // Criar uma requisição com configurações para evitar duplicação
      final adRequest = AdRequest(
        nonPersonalizedAds: true,
      );

      _bannerAd?.dispose();
      _bannerAd = null;

      try {
        BannerAd(
          adUnitId: Constants.getAdmobHomeBannerUnit(),
          size: AdSize.banner,
          request: adRequest,
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              print("Banner ad carregado com sucesso");
              setState(() {
                _bannerAd = ad as BannerAd;
                controller.isAdLoaded.value = true;
              });
            },
            onAdFailedToLoad: (ad, error) {
              print(
                  "Erro ao carregar banner: ${error.code} - ${error.message}");
              ad.dispose();
              _bannerAd = null;
            },
            onAdClosed: (ad) {
              print("Banner fechado");
              ad.dispose();
              _bannerAd = null;

              // Recarregar após um tempo
              Future.delayed(Duration(minutes: 1), () {
                if (mounted) {
                  _loadAd();
                }
              });
            },
          ),
        ).load();
      } catch (e) {
        print("Exceção ao carregar banner: $e");
      }
    }
  }

  Widget _buildPages() {
    return PageView(
      controller: controller.pageController,
      onPageChanged: controller.onTabChanged,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ShortsCachedView(currentUser: widget.currentUser),
        FeedHomeScreen(currentUser: widget.currentUser),
        AllLivesScreen(currentUser: widget.currentUser),
        MessagesListScreen(currentUser: widget.currentUser),
        TabProfileScreen(currentUser: widget.currentUser),
      ],
    );
  }

  Widget _buildNavItem(IconData? icon, int index) {
    return Obx(() {
      final isSelected = controller.selectedIndex.value == index;
      if (index == 4) {
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: QuickActions.avatarBorder(widget.currentUser!,
              hideAvatarFrame: true),
        );
      }
      if (index == 0) {
        return Container(
          width: 30,
          height: 30,
          child: SvgPicture.asset(
            isSelected
                ? 'assets/svg/video_called.svg'
                : 'assets/svg/video_uncalled.svg',
            colorFilter:
                Theme.of(context).brightness == Brightness.dark && !isSelected
                    ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                    : null,
          ),
        );
      }
      if (index == 2) {
        return Container(
          width: 30,
          height: 30,
          child: Image.asset(
            'assets/images/ic_logo.png',
          ),
        );
      }
      if (index == 3) {
        return Container(
          width: 30,
          height: 30,
          child: SvgPicture.asset(
            isSelected
                ? 'assets/svg/chat_called.svg'
                : 'assets/svg/chat_uncalled.svg',
            colorFilter:
                Theme.of(context).brightness == Brightness.dark && !isSelected
                    ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                    : null,
          ),
        );
      }
      if (index == 1) {
        return Container(
          width: 30,
          height: 30,
          child: SvgPicture.asset(
            isSelected
                ? 'assets/svg/feed_called.svg'
                : 'assets/svg/feed_uncalled.svg',
            colorFilter:
                Theme.of(context).brightness == Brightness.dark && !isSelected
                    ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                    : null,
          ),
        );
      }
      return IconButton(
        icon: Icon(icon!),
        color: isSelected ? Colors.blue : Colors.grey,
        onPressed: () => controller.onTabChanged(index),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildPages(),
          Obx(() => controller.selectedIndex.value != 0 &&
                  controller.isAdLoaded.value &&
                  _bannerAd != null
              ? Positioned(
                  bottom: kBottomNavigationBarHeight,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                )
              : SizedBox.shrink()),
        ],
      ),
      bottomNavigationBar: Obx(() => BottomNavigationBar(
            currentIndex: controller.selectedIndex.value,
            onTap: controller.onTabChanged,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: _buildNavItem(null, 0),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: _buildNavItem(null, 1),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: _buildNavItem(null, 2),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    _buildNavItem(null, 3),
                    if (controller.unreadMessageCount.value > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Badge(
                          label: Text('${controller.unreadMessageCount.value}'),
                          backgroundColor: Colors.red,
                          isLabelVisible: true,
                        ),
                      ),
                  ],
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: _buildNavItem(Icons.person, 4),
                label: '',
              ),
            ],
          )),
    );
  }

  TextEditingController inviteTextController = TextEditingController();
  bool hasNotification = false;
}
