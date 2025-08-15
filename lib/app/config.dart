import 'dart:ui';

class Config {
  static const String packageNameAndroid = "com.nazcloak.joytox";
  static const String packageNameiOS = "com.nazcloak.joytox";
  static const String iosAppStoreId = "";
  static final String appName = "Joytox";
  static final String appVersion = "1.0.0";
  static final String companyName = "Joytox, inc";
  static final String appOrCompanyUrl = "https://app.joytox.com";
  static final String initialCountry = 'PK'; // Pakistan

  static final String serverUrl = "https://parseapi.back4app.com";
  static final String liveQueryUrl = "wss://joytoxnc.b4a.io";
  static final String appId = "PnMuNwicMbmply3g2zADyUCVuwC10apyb6E2lx21";
  static final String clientKey = "uVuyaNglVAc07KyQhnnrNoUjlAaEcnsRpzx7C0QK";

  //OneSignal
  static final String oneSignalAppId = "";

  // Firebase Cloud Messaging
  static final String pushGcm = "732846852135";
  static final String webPushCertificate =
      "BOcDBhPvYrRB0CCAsyXN5mMbL_b8wj2w5AnpqthaDSrksblAfvvsLwjzGbYnmwyRCmiPnVGDUuQodau-Cv7xU74";

  // User support objectId
  static final String supportId = "";

  // Play Store and App Store public keys
  static final String publicGoogleSdkKey = "goog_YTmsSipPYVrTXUvjfxcswbjbuRE";
  static final String publicIosSdkKey = "";

  // Languages
  static String defaultLanguage = "en"; // English is default language.
  static List<Locale> languages = [
    Locale(defaultLanguage),
    //Locale('pt'),
    //Locale('fr')
  ];

  // Android Admob ad
  static const String admobAndroidOpenAppAd =
      "ca-app-pub-9318890613494690/4325316561";
  static const String admobAndroidHomeBannerAd =
      "ca-app-pub-9318890613494690/8240828077";
  static const String admobAndroidFeedNativeAd =
      "ca-app-pub-9318890613494690/9362338057";
  static const String admobAndroidChatListBannerAd =
      "ca-app-pub-9318890613494690/6736174716";
  static const String admobAndroidLiveBannerAd =
      "ca-app-pub-9318890613494690/7959371442";
  static const String admobAndroidFeedBannerAd =
      "ca-app-pub-9318890613494690/9362338057";

  // iOS Admob ad
  static const String admobIOSOpenAppAd =
      "ca-app-pub-1084112649181796/6328973508";
  static const String admobIOSHomeBannerAd =
      "ca-app-pub-1084112649181796/1185447057";
  static const String admobIOSFeedNativeAd =
      "ca-app-pub-1084112649181796/7224203806";
  static const String admobIOSChatListBannerAd =
      "ca-app-pub-1084112649181796/5811376758";
  static const String admobIOSLiveBannerAd =
      "ca-app-pub-1084112649181796/8093979063";
  static const String admobIOSFeedBannerAd =
      "ca-app-pub-1084112649181796/6907075815";

  // Web links for help, privacy policy and terms of use.
  static final String helpCenterUrl = "https://joytox.com/help";
  static final String privacyPolicyUrl = "https://joytox.com/privacy";
  static final String termsOfUseUrl = "https://joytox.com/terms";
  static final String termsOfUseInAppUrl = "https://joytox.com/terms";
  static final String dataSafetyUrl = "https://joytox.com/help";
  static final String openSourceUrl = "https://joytox.com/";
  static final String instructionsUrl = "https://joytox.com/";
  static final String cashOutUrl = "https://joytox.com/cashout";
  static final String supportUrl = "https://joytox.com/support";
  static final String liveAgreementUrl = "https://joytox.com/agreement/live";
  static final String userAgreementUrl = "https://joytox.com/agreement/user";

  // Google Play and Apple Pay In-app Purchases IDs
  static final String credit100 = "joytox.100.credits";
  static final String credit200 = "joytox.200.credits";
  static final String credit500 = "joytox.500.credits";
  static final String credit1000 = "joytox.1000.credits";
  static final String credit2100 = "joytox.2100.credits";
  static final String credit5250 = "joytox.5250.credits";
  static final String credit10500 = "joytox.10500.credits";
}
