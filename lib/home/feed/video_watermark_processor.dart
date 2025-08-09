import 'package:video_compress/video_compress.dart';

class VideoWatermarkProcessor {
  static Future<String?> compressVideo(String videoPath) async {
    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      return mediaInfo?.path;
    } on Exception catch (e) {
      print('Erro na compressão: $e');
      return null;
    }
  }

  static Future<void> cancelCompression() async {
    await VideoCompress.cancelCompression();
  }

  static ObservableBuilder<double> getCompressProgress() {
    return VideoCompress.compressProgress$;
  }
}
