import 'dart:typed_data';

import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:trace/app/cloud_params.dart';
import 'package:trace/app/setup.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/models/InvitedUsersModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/LeadersModel.dart';

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
    // Use new atomic cloud function with retry logic
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.addPKPoints);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.points: points,
      CloudParams.liveChannel: liveChannel,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> getBattleState(
      {required String liveChannel}) async {
    // Get current battle state for late joiners
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.getBattleState);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.liveChannel: liveChannel,
    };

    return await function.execute(parameters: params);
  }

  static Future<ParseResponse> initializeBattle(
      {required String myChannel, required String opponentChannel}) async {
    // Initialize battle with bidirectional linking
    ParseCloudFunction function =
        ParseCloudFunction(CloudParams.initializeBattle);
    Map<String, dynamic> params = <String, dynamic>{
      CloudParams.myChannel: myChannel,
      CloudParams.opponentChannel: opponentChannel,
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
    int coinsToAdd = QuickHelp.getCoinsForReceiver(credits);
    print(
        "🎁 [GIFT DEBUG] Sending gift to ${author.getFullName} (${author.objectId})");
    print("🎁 [GIFT DEBUG] Credits: $credits, Coins to add: $coinsToAdd");
    print("🎁 [GIFT DEBUG] Receiver current coins: ${author.getCredits}");

    // Get current user
    ParseUser? currentUser = await ParseUser.currentUser();
    if (currentUser == null) {
      throw Exception("User not logged in");
    }

    ParseCloudFunction function = ParseCloudFunction(CloudParams.sendGiftParam);
    Map<String, dynamic> params = <String, dynamic>{
      'senderId': currentUser.objectId,
      'receiverId': author.objectId,
      'giftId':
          'gift_${DateTime.now().millisecondsSinceEpoch}', // Generate unique gift ID
      'credits': credits,
      'coins': coinsToAdd, // Changed from diamonds to coins
    };

    print("🎁 [GIFT DEBUG] Sending parameters: $params");

    if (author.getInvitedByUser != null &&
        author.getInvitedByUser!.isNotEmpty) {
      sendAgencyDiamonds(
          invitedById: author.getInvitedByUser!,
          credits: QuickHelp.getDiamondsForAgency(coinsToAdd));
    }

    ParseResponse response = await function.execute(parameters: params);

    print(
        "🎁 [GIFT DEBUG] Cloud function response: success=${response.success}, error=${response.error}");

    // If cloud function succeeds, refresh the receiver's data to update UI
    if (response.success) {
      print(
          "🎁 [GIFT DEBUG] Cloud function succeeded, refreshing receiver data");
      try {
        // Fetch the updated user data from the server
        await author.fetch();
        print("🎁 [GIFT DEBUG] Receiver data refreshed successfully");
        print("🎁 [GIFT DEBUG] Receiver new coins: ${author.getCredits}");
      } catch (e) {
        print("🎁 [GIFT DEBUG] Error refreshing receiver data: $e");
      }

      // Update LeadersModel for the sender (gift giver ranking)
      try {
        final leadersQuery = QueryBuilder<LeadersModel>(LeadersModel());
        leadersQuery.whereEqualTo(
            LeadersModel.keyAuthorId, currentUser.objectId);
        final leadersResp = await leadersQuery.query();

        if (leadersResp.success && leadersResp.results != null) {
          final LeadersModel leaders =
              leadersResp.results!.first as LeadersModel;
          leaders.incrementDiamondsQuantity = credits;
          await leaders.save();
        } else {
          // Create new leaders entry for this sender
          final userQuery = QueryBuilder<UserModel>(UserModel.forQuery());
          userQuery.whereEqualTo(UserModel.keyObjectId, currentUser.objectId);
          final userResp = await userQuery.query();

          final LeadersModel leaders = LeadersModel();
          if (userResp.success && userResp.results != null) {
            final user = userResp.results!.first as UserModel;
            leaders.setAuthor = user;
          }
          leaders.setAuthorId = currentUser.objectId!;
          leaders.setCounterDiamondsQuantity = credits;
          await leaders.save();
        }
      } catch (e) {
        print('⚠️ [GIFT DEBUG] Failed to update LeadersModel: $e');
      }
    } else {
      // Fallback: If cloud function fails, add coins directly to receiver
      print(
          "🎁 [GIFT DEBUG] Cloud function failed, adding coins directly to receiver");
      author.addCredit = coinsToAdd;
      ParseResponse saveResponse = await author.save();
      print(
          "🎁 [GIFT DEBUG] Direct save response: success=${saveResponse.success}");
      if (saveResponse.success) {
        print("🎁 [GIFT DEBUG] Receiver new coins: ${author.getCredits}");
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
