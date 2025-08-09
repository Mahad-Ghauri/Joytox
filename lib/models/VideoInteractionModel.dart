import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/PostsModel.dart';
import 'dart:math' as math;

class VideoInteractionModel extends ParseObject implements ParseCloneable {
  static const String keyTableName = 'VideoInteractions';

  VideoInteractionModel() : super(keyTableName);

  VideoInteractionModel.clone() : this();

  @override
  VideoInteractionModel clone(Map<String, dynamic> map) =>
      VideoInteractionModel.clone()..fromJson(map);

  // Campos principais
  static const String keyUser = 'user';
  static const String keyUserId = 'userId';
  static const String keyVideo = 'video';
  static const String keyVideoId = 'videoId';
  static const String keyCreatedAt = 'createdAt';
  static const String keyUpdatedAt = 'updatedAt';

  // Métricas de interação
  static const String keyWatchTimeSeconds = 'watchTimeSeconds';
  static const String keyWatchPercentage = 'watchPercentage';
  static const String keyCompletedViews = 'completedViews';
  static const String keyRepeatedViews = 'repeatedViews';
  static const String keyLiked = 'liked';
  static const String keyShared = 'shared';
  static const String keyCommented = 'commented';
  static const String keySaved = 'saved';
  static const String keySkipped = 'skipped';
  static const String keySkippedAfterSeconds = 'skippedAfterSeconds';

  // Categorias e tags do vídeo
  static const String keyVideoTags = 'videoTags';
  static const String keyVideoCategory = 'videoCategory';

  // Métricas de recomendação
  static const String keyInteractionScore = 'interactionScore';
  static const String keyRecommendationWeight = 'recommendationWeight';

  // Getters e Setters para User
  UserModel? get getUser => get<UserModel>(keyUser);
  set setUser(UserModel user) => set<UserModel>(keyUser, user);

  String? get getUserId => get<String>(keyUserId);
  set setUserId(String userId) => set<String>(keyUserId, userId);

  // Getters e Setters para Video
  PostsModel? get getVideo => get<PostsModel>(keyVideo);
  set setVideo(PostsModel video) => set<PostsModel>(keyVideo, video);

  String? get getVideoId => get<String>(keyVideoId);
  set setVideoId(String videoId) => set<String>(keyVideoId, videoId);

  // Getters e Setters para métricas de tempo
  int get getWatchTimeSeconds => get<int>(keyWatchTimeSeconds) ?? 0;
  set setWatchTimeSeconds(int seconds) =>
      set<int>(keyWatchTimeSeconds, seconds);
  set incrementWatchTime(int seconds) =>
      setIncrement(keyWatchTimeSeconds, seconds);

  double get getWatchPercentage => get<double>(keyWatchPercentage) ?? 0.0;
  set setWatchPercentage(double percentage) =>
      set<double>(keyWatchPercentage, percentage);

  // Getters e Setters para contagens de visualizações
  int get getCompletedViews => get<int>(keyCompletedViews) ?? 0;
  set setCompletedViews(int count) => set<int>(keyCompletedViews, count);
  set incrementCompletedViews(int count) =>
      setIncrement(keyCompletedViews, count);

  int get getRepeatedViews => get<int>(keyRepeatedViews) ?? 0;
  set setRepeatedViews(int count) => set<int>(keyRepeatedViews, count);
  set incrementRepeatedViews(int count) =>
      setIncrement(keyRepeatedViews, count);

  // Getters e Setters para interações
  bool get getLiked => get<bool>(keyLiked) ?? false;
  set setLiked(bool liked) => set<bool>(keyLiked, liked);

  bool get getShared => get<bool>(keyShared) ?? false;
  set setShared(bool shared) => set<bool>(keyShared, shared);

  bool get getCommented => get<bool>(keyCommented) ?? false;
  set setCommented(bool commented) => set<bool>(keyCommented, commented);

  bool get getSaved => get<bool>(keySaved) ?? false;
  set setSaved(bool saved) => set<bool>(keySaved, saved);

  bool get getSkipped => get<bool>(keySkipped) ?? false;
  set setSkipped(bool skipped) => set<bool>(keySkipped, skipped);

  int get getSkippedAfterSeconds => get<int>(keySkippedAfterSeconds) ?? 0;
  set setSkippedAfterSeconds(int seconds) =>
      set<int>(keySkippedAfterSeconds, seconds);

  // Getters e Setters para categorias e tags
  List<String> get getVideoTags =>
      get<List<dynamic>>(keyVideoTags)?.cast<String>() ?? [];
  set setVideoTags(List<String> tags) => set<List<String>>(keyVideoTags, tags);

  String? get getVideoCategory => get<String>(keyVideoCategory);
  set setVideoCategory(String category) =>
      set<String>(keyVideoCategory, category);

  // Getters e Setters para métricas de recomendação
  double get getInteractionScore => get<double>(keyInteractionScore) ?? 0.0;
  set setInteractionScore(double score) =>
      set<double>(keyInteractionScore, score);

  double get getRecommendationWeight =>
      get<double>(keyRecommendationWeight) ?? 1.0;
  set setRecommendationWeight(double weight) =>
      set<double>(keyRecommendationWeight, weight);

  // Método para calcular a pontuação de interação
  double calculateInteractionScore() {
    double score = 0.0;

    // Pontuação baseada no tempo assistido (peso maior)
    score += getWatchPercentage * 0.40;

    // Visualizações completas e repetidas (indicam forte interesse)
    score += (getCompletedViews > 0) ? 0.15 : 0;
    score +=
        math.min(getRepeatedViews, 5) * 0.05; // Até 25% para repetições (max 5)

    // Interações sociais (like, compartilhamento, etc.)
    if (getLiked == true) score += 0.10;
    if (getShared == true) score += 0.15;
    if (getCommented == true) score += 0.10;
    if (getSaved == true) score += 0.15;

    // Penalidade para vídeos pulados rapidamente
    if (getSkipped && getWatchPercentage < 0.1) {
      score -= 0.20;
    }

    // Normalizar para o intervalo [0, 1]
    score = math.max(0.0, math.min(score, 1.0));

    return score;
  }

  // Atualiza e salva a pontuação
  Future<ParseResponse> updateInteractionScore() async {
    setInteractionScore = calculateInteractionScore();
    return await save();
  }
}
