import 'package:trace/models/UserModel.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';

import '../app/setup.dart';

class PostsModel extends ParseObject implements ParseCloneable {
  static const String keyTableName = 'Posts';

  PostsModel() : super(keyTableName);

  PostsModel.clone() : this();

  @override
  PostsModel clone(Map<String, dynamic> map) =>
      PostsModel.clone()..fromJson(map);

  static const String keyAuthor = 'Author';
  static const String keyVideo = 'video';
  static const String keyLikes = 'likes';
  static const String keySaves = 'saves';
  static const String keyComments = 'comments';
  static const String keyViews = 'views';
  static const String keyDescription = 'description';
  static const String keyCreatedAt = 'createdAt';
  static const String postTypeVideo = 'video';

  static String keyObjectId = "objectId";
  static String keyAuthorName = "Author.name";
  static String keyAuthorId = "AuthorId";

  static String postTypeImage = "image";
  static String postTypeAudio = "audio";

  static String keyLastLikeAuthor = "LastLikeAuthor";
  static String keyLastDiamondAuthor = "LastDiamondAuthor";

  static String keyText = "text";
  static String keyImage = "image";
  static String keyVideoThumbnail = "thumbnail";
  static String keyShare = "share";
  static String keyDiamonds = "diamonds";
  static String keyPaidUsers = "paidBy";
  static String keyPaidAmount = "paidAmount";

  static String keyExclusive = "exclusive";
  static String keyPostType = "type";

  static String keyViewers = "viewers";

  static String keyImagesList = "list_of_images";
  static String keyNumberOfPictures = "numer_of_pictures";

  static String keyTargetPeopleID = "target_people_ids";
  static String keyTargetPeople = "target_people";

  static String keyTextColor = "text_color";
  static String keyBackgroundColor = "background_color";

  UserModel? get getAuthor => get<UserModel>(keyAuthor);
  set setAuthor(UserModel author) => set<UserModel>(keyAuthor, author);

  ParseFileBase? get getVideo => get<ParseFileBase>(keyVideo);
  set setVideo(ParseFileBase video) => set<ParseFileBase>(keyVideo, video);

  List<String> get getLikes =>
      get<List<dynamic>>(keyLikes)?.cast<String>() ?? [];
  set setLikes(String like) => setAddUnique(keyLikes, like);
  set removeLike(String like) => setRemove(keyLikes, like);

  List<String> get getSaves =>
      get<List<dynamic>>(keySaves)?.cast<String>() ?? [];
  set setSaves(String save) => setAddUnique(keySaves, save);
  set removeSave(String save) => setRemove(keySaves, save);

  List<ParseObject> get getComments =>
      get<List<dynamic>>(keyComments)?.cast<ParseObject>() ?? [];
  set setComments(List<ParseObject> comments) =>
      set<List<ParseObject>>(keyComments, comments);

  int get getViews => get<int>(keyViews) ?? 0;
  set setViews(int views) => set<int>(keyViews, views);

  String get getDescription => get<String>(keyDescription) ?? '';
  set setDescription(String description) =>
      set<String>(keyDescription, description);

  String? get getTextColors => get<String>(keyTextColor);
  set setTextColors(String textColor) => set<String>(keyTextColor, textColor);

  String? get getBackgroundColor => get<String>(keyBackgroundColor);
  set setBackgroundColor(String backgroundColor) =>
      set<String>(keyBackgroundColor, backgroundColor);

  List<dynamic>? get getTargetPeople {
    List<dynamic> usersList = [];

    List<dynamic>? users = get<List<dynamic>>(keyTargetPeople);
    if (users != null && users.length > 0) {
      return users;
    } else {
      return usersList;
    }
  }

  set setTargetPeople(List<UserModel> usersId) =>
      setAddAll(keyTargetPeople, usersId);

  List<dynamic>? get getTargetPeopleID {
    List<dynamic> ids = [];

    List<dynamic>? usersId = get<List<dynamic>>(keyTargetPeopleID);
    if (usersId != null && usersId.length > 0) {
      return usersId;
    } else {
      return ids;
    }
  }

  set setTargetPeopleID(List<dynamic> usersId) =>
      setAddAll(keyTargetPeopleID, usersId);

  int get getNumberOfPictures {
    int? number = get(keyNumberOfPictures);
    if (number != null) {
      return number;
    } else {
      return 0;
    }
  }

  set setNumberOfPictures(int numberOfPictures) =>
      set(keyNumberOfPictures, numberOfPictures);

  List<dynamic>? get getImagesList {
    List<dynamic> save = [];

    List<dynamic>? images = get<List<dynamic>>(keyImagesList);
    if (images != null && images.length > 0) {
      return images;
    } else {
      return save;
    }
  }

  set setImagesList(List<ParseFileBase> imagesList) =>
      setAddAll(keyImagesList, imagesList);

  set removeImageFromList(ParseFileBase image) =>
      setRemove(keyImagesList, image);
  set removeImageListFromList(List<dynamic> imagesList) =>
      setRemoveAll(keyImagesList, imagesList);

  String? get getAuthorId => get<String>(keyAuthorId);

  set setAuthorId(String authorId) => set<String>(keyAuthorId, authorId);

  String? get getText {
    String? existingText = get<String>(keyText);
    if (existingText != null) {
      return existingText;
    } else {
      return "";
    }
  }

  set setText(String text) => set<String>(keyText, text);

  ParseFileBase? get getImage => get<ParseFileBase>(keyImage);

  set setImage(ParseFileBase imageFile) =>
      set<ParseFileBase>(keyImage, imageFile);

  ParseFileBase? get getVideoThumbnail => get<ParseFileBase>(keyVideoThumbnail);

  set setVideoThumbnail(ParseFileBase videoFile) =>
      set<ParseFileBase>(keyVideoThumbnail, videoFile);

  List<dynamic>? get getViewers {
    List<dynamic> save = [];

    List<dynamic>? viewers = get<List<dynamic>>(keyViewers);
    if (viewers != null && viewers.length > 0) {
      return viewers;
    } else {
      return save;
    }
  }

  set setViewer(String authorId) => setAddUnique(keyViewers, authorId);

  UserModel? get getLastLikeAuthor => get<UserModel>(keyLastLikeAuthor);

  set setLastLikeAuthor(UserModel author) =>
      set<UserModel>(keyLastLikeAuthor, author);

  UserModel? get getLastDiamondAuthor => get<UserModel>(keyLastDiamondAuthor);

  set setLastDiamondAuthor(UserModel author) =>
      set<UserModel>(keyLastDiamondAuthor, author);

  //List<dynamic>? get getShares => get<List<dynamic>>(keyShare);

  //set setShares(String shareAuthorId) => setAdd(keyShare, shareAuthorId);

  List<String> get getShares =>
      get<List<dynamic>>(keyShare)?.cast<String>() ?? [];

  set setShares(String shareAuthorId) => setAddUnique(keyShare, shareAuthorId);
  set removeShares(String shareAuthorId) => setRemove(keyShare, shareAuthorId);


  int? get getDiamonds => get<int>(keyDiamonds);

  set addDiamonds(int diamonds) => setIncrement(keyDiamonds, diamonds);

  bool? get getExclusive {
    bool? exclusive = get<bool>(keyExclusive);
    if (exclusive != null) {
      return exclusive;
    } else {
      return false;
    }
  }

  set setExclusive(bool exclusive) => set<bool>(keyExclusive, exclusive);

  String? get getPostId => get<String>(keyObjectId);

  bool? get isVideo {
    String? video = get<String>(keyPostType);
    if (video != null && video == postTypeVideo) {
      return true;
    } else {
      return false;
    }
  }

  int? get getPostType => get<int>(keyPostType);

  set setPostType(String postType) => set<String>(keyPostType, postType);

  List<dynamic>? get getPaidBy {
    List<dynamic> paidIds = [];

    List<dynamic>? payers = get<List<dynamic>>(keyPaidUsers);
    if (payers != null && payers.length > 0) {
      return payers;
    } else {
      return paidIds;
    }
  }

  set setPaidBy(String paidAuthorId) =>
      setAddUnique(keyPaidUsers, paidAuthorId);

  set setPaidAmount(int coins) => set<int>(keyPaidAmount, coins);

  int? get getPaidAmount {
    int? amount = get<int>(keyPaidAmount);
    if (amount != null) {
      return amount;
    } else {
      return Setup.coinsNeededToForExclusivePost;
    }
  }

  bool isLiked(String? userId) {
    if (userId == null) return false;
    return getLikes.contains(userId);
  }

  bool isSaved(String? userId) {
    if (userId == null) return false;
    return getSaves.contains(userId);
  }

  Future<void> toggleLike(String userId) async {
    List<String> likes = getLikes;
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }
    setLikes = likes.join(',');
    await save();
  }

  Future<void> toggleSave(String userId) async {
    List<String> saves = getSaves;
    if (saves.contains(userId)) {
      saves.remove(userId);
    } else {
      saves.add(userId);
    }
    setSaves = saves.join(',');
    await save();
  }

  Future<void> incrementViews() async {
    setViews = getViews + 1;
    await save();
  }

  int get getDownloads => get('downloads') ?? 0;
  set setDownloads(int value) => set('downloads', value);

  Future<void> incrementDownloads() async {
    setDownloads = getDownloads + 1;
    await save();
  }
}
