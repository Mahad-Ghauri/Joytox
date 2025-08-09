import '../../../models/PostsModel.dart';
import '../../../models/UserModel.dart';

class VideoInfo {
  String? url;
  String? userName;
  String? songName;
  bool? liked;
  DateTime? dateTime;
  List<dynamic>? likes;
  PostsModel? postModel;
  UserModel? currentUser;
  Duration? initialPosition;

  VideoInfo({
    this.url,
    this.userName,
    this.songName,
    this.liked,
    this.dateTime,
    this.likes,
    this.postModel,
    this.currentUser,
    this.initialPosition,
  });
}
