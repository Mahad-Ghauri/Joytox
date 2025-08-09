import 'dart:io';

class VideoCache {
  final String videoId;
  final String videoUrl;
  final String localPath;
  final DateTime cachedAt;
  final int fileSize;
  final Map<String, dynamic> metadata;

  VideoCache({
    required this.videoId,
    required this.videoUrl,
    required this.localPath,
    required this.cachedAt,
    required this.fileSize,
    required this.metadata,
  });

  // Verificar se o arquivo existe fisicamente
  bool fileExists() {
    final file = File(localPath);
    return file.existsSync();
  }

  // Criar uma instância a partir de um mapa
  factory VideoCache.fromMap(Map<String, dynamic> map) {
    return VideoCache(
      videoId: map['videoId'] as String,
      videoUrl: map['videoUrl'] as String,
      localPath: map['localPath'] as String,
      cachedAt: DateTime.parse(map['cachedAt'] as String),
      fileSize: map['fileSize'] as int,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map),
    );
  }

  // Converter para mapa para armazenamento
  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'videoUrl': videoUrl,
      'localPath': localPath,
      'cachedAt': cachedAt.toIso8601String(),
      'fileSize': fileSize,
      'metadata': metadata,
    };
  }
}
