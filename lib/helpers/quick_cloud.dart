import 'dart:typed_data';

import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:trace/app/cloud_params.dart';
import 'package:trace/app/setup.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/models/InvitedUsersModel.dart';
import 'package:trace/models/UserModel.dart';

class QuickCloudCode {
  static Future<ParseResponse> restartPKBattle(
      {required String liveChannel, required int times}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.restartPkBattle);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.liveChannel: liveChannel,
      CloudParams.times: times,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> saveHisBattlePoints(
      {required int points, required String liveChannel}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.saveHisBattlePoints);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.points: points,
      CloudParams.liveChannel: liveChannel,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> followUser(
      {required UserModel author, required UserModel receiver}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.followUserParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.author: author.objectId,
      CloudParams.receiver: receiver.objectId,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> unFollowUser(
      {required UserModel author, required UserModel receiver}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.unFollowUserParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.author: author.objectId,
      CloudParams.receiver: receiver.objectId,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> sendGift(
      {required UserModel author, required int credits}) async {
    int diamondsToAdd = QuickHelp.getDiamondsForReceiver(credits);
    print(
        "🎁 [GIFT DEBUG] Sending gift to ${author.getFullName} (${author.objectId})");
    print("🎁 [GIFT DEBUG] Credits: $credits, Diamonds to add: $diamondsToAdd");
    print("🎁 [GIFT DEBUG] Receiver current diamonds: ${author.getDiamonds}");

    ParseCloudFunction function = ParseCloudFunction(CloudParams.sendGiftParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.objectId: author.objectId,
      CloudParams.credits: diamondsToAdd,
    };

    if (author.getInvitedByUser != null &&
        author.getInvitedByUser!.isNotEmpty) {
      sendAgencyDiamonds(
          invitedById: author.getInvitedByUser!,
          credits: QuickHelp.getDiamondsForAgency(diamondsToAdd));
    }

    ParseResponse response = await function.execute(parameters: params);

    print(
        "🎁 [GIFT DEBUG] Cloud function response: success=${response.success}, error=${response.error}");

    // Fallback: If cloud function fails, add diamonds directly to receiver
    if (!response.success) {
      print(
          "🎁 [GIFT DEBUG] Cloud function failed, adding diamonds directly to receiver");
      author.setDiamonds = diamondsToAdd;
      ParseResponse saveResponse = await author.save();
      print(
          "🎁 [GIFT DEBUG] Direct save response: success=${saveResponse.success}");
      if (saveResponse.success) {
        print("🎁 [GIFT DEBUG] Receiver new diamonds: ${author.getDiamonds}");
      }
    }

    return response;
  }

  static sendAgencyDiamonds(
      {required String invitedById, required int credits}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.sendAgencyParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.objectId: invitedById,
      CloudParams.credits: credits,
    };

    QueryBuilder<InvitedUsersModel> queryBuilder =
        QueryBuilder<InvitedUsersModel>(InvitedUsersModel());
    queryBuilder.whereEqualTo(InvitedUsersModel.keyInvitedById, invitedById);
    ParseResponse parseResponse = await queryBuilder.query();

    if (parseResponse.success && parseResponse.results != null) {
      InvitedUsersModel invitedUser =
          parseResponse.results!.first! as InvitedUsersModel;
      invitedUser.addDiamonds = credits;
      await invitedUser.save();
    }

    await function.execute(parameters: params);
  }

  static Future<ParseResponse> verifyPayment(
      {required String productSku, required String purchaseToken}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.verifyPaymentParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.packageName: Setup.appPackageName,
      CloudParams.purchaseToken: purchaseToken,
      CloudParams.productId: productSku,
      CloudParams.platform: QuickHelp.getDeviceOsType(),
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> suspendUSer({required String objectId}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.suspendUserParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.suspendUserId: objectId,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> uploadVideo(
      {required Uint8List parseFile}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.uploadVideoParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.uploadVideoFile: parseFile,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> changePicture(
      {required Uint8List parseFile, UserModel? user}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.changeUserPictureParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.changeUserPictureFile: parseFile,
      CloudParams.userGlobal: user!.objectId,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> addUserToMyFanClub(
      {required String fanId, required UserModel user}) async {
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.addUserToMyFanClubParam);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.fanClubOwnerId: user.objectId,
      CloudParams.fanId: fanId,
    };

    return await function.execute(parameters: params);
  }
}
