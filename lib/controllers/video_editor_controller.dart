import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_editor/video_editor.dart' as ved;
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

class VideoEditorController extends GetxController {
  // Camera variables
  Rx<CameraController?> cameraController = Rx<CameraController?>(null);
  RxBool isRecording = false.obs;
  RxInt selectedDuration = 15.obs; // Default 15 seconds
  RxInt remainingTime = 0.obs;
  final List<int> availableDurations = [15, 30, 45, 60, 90];
  RxBool isCameraInitialized = false.obs;
  RxBool isCameraPermissionGranted = false.obs;
  RxString errorMessage = ''.obs;
  RxInt currentCameraIndex = 0.obs;
  List<CameraDescription> cameras = [];

  // Editor variables
  Rx<ved.VideoEditorController?> editor = Rx<ved.VideoEditorController?>(null);
  Rx<VideoPlayerController?> previewController =
      Rx<VideoPlayerController?>(null);
  RxString currentFilter = 'normal'.obs;
  RxBool isExporting = false.obs;
  RxString exportText = ''.obs;
  RxBool isMusicAdded = false.obs;
  RxString selectedMusicPath = ''.obs;
  RxBool isPlaying = false.obs;
  RxDouble videoPosition = 0.0.obs;
  RxDouble videoDuration = 0.0.obs;

  VideoPlayerController? get video => previewController.value;

  String get formattedRemainingTime {
    int minutes = remainingTime.value ~/ 60;
    int seconds = remainingTime.value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPosition {
    final duration =
        Duration(milliseconds: (videoPosition.value * 1000).round());
    return _formatDuration(duration);
  }

  String get formattedDuration {
    final duration =
        Duration(milliseconds: (videoDuration.value * 1000).round());
    return _formatDuration(duration);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void onInit() {
    super.onInit();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (status.isGranted && micStatus.isGranted) {
      isCameraPermissionGranted.value = true;
      await _loadCameras();
      await initializeCamera();
    } else {
      isCameraPermissionGranted.value = false;
      errorMessage.value =
          'Permissões de câmera e microfone são necessárias para gravar vídeos';
      Get.snackbar(
        'Permissão Necessária',
        'Por favor, conceda as permissões de câmera e microfone para continuar',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadCameras() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage.value = 'Nenhuma câmera encontrada';
      }
    } catch (e) {
      errorMessage.value = 'Erro ao carregar câmeras: $e';
      print('Error loading cameras: $e');
    }
  }

  Future<void> initializeCamera() async {
    if (cameras.isEmpty) return;

    try {
      if (cameraController.value != null) {
        await cameraController.value!.dispose();
      }

      cameraController.value = CameraController(
        cameras[currentCameraIndex.value],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController.value!.initialize();
      isCameraInitialized.value = true;
      update();
    } catch (e) {
      errorMessage.value = 'Erro ao inicializar câmera: $e';
      print('Error initializing camera: $e');
    }
  }

  Future<void> flipCamera() async {
    if (cameraController.value == null ||
        !isCameraInitialized.value ||
        isRecording.value) return;

    try {
      isCameraInitialized.value = false;
      currentCameraIndex.value =
          (currentCameraIndex.value + 1) % cameras.length;

      final previousController = cameraController.value;

      cameraController.value = CameraController(
        cameras[currentCameraIndex.value],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController.value!.initialize();
      isCameraInitialized.value = true;

      await previousController?.dispose();
      update();
    } catch (e) {
      print('Error flipping camera: $e');
      errorMessage.value = 'Erro ao trocar câmera: $e';
    }
  }

  void setRecordingDuration(int duration) {
    if (!isRecording.value) {
      selectedDuration.value = duration;
      remainingTime.value = duration;
    }
  }

  void _startTimer() {
    remainingTime.value = selectedDuration.value;
    Future.doWhile(() async {
      if (!isRecording.value || remainingTime.value <= 0) return false;
      await Future.delayed(const Duration(seconds: 1));
      remainingTime.value--;
      if (remainingTime.value <= 0) {
        final String? videoPath = await stopRecording();
        if (videoPath != null) {
          Get.toNamed('/video-editor', arguments: videoPath);
        }
        return false;
      }
      return true;
    });
  }

  Future<void> startRecording() async {
    if (cameraController.value == null ||
        !isCameraInitialized.value ||
        isRecording.value) return;

    try {
      await cameraController.value!.startVideoRecording();
      isRecording.value = true;
      _startTimer();
    } catch (e) {
      errorMessage.value = 'Erro ao iniciar gravação: $e';
      print('Error starting recording: $e');
    }
  }

  Future<String?> stopRecording() async {
    if (cameraController.value == null || !isRecording.value) return null;

    try {
      final XFile video = await cameraController.value!.stopVideoRecording();
      isRecording.value = false;
      remainingTime.value = 0;
      return video.path;
    } catch (e) {
      errorMessage.value = 'Erro ao parar gravação: $e';
      print('Error stopping recording: $e');
      return null;
    }
  }

  Future<void> initializeEditor(String videoPath) async {
    try {
      final File file = File(videoPath);
      errorMessage.value = '';

      // Reset state
      isPlaying.value = false;
      videoPosition.value = 0;
      videoDuration.value = 0;

      // Initialize editor first
      editor.value = ved.VideoEditorController.file(
        file,
        minDuration: const Duration(seconds: 1),
        maxDuration: const Duration(seconds: 90),
      );
      await editor.value?.initialize();

      // Initialize video preview
      if (previewController.value != null) {
        await previewController.value!.dispose();
      }

      previewController.value = VideoPlayerController.file(file);
      await previewController.value!.initialize();

      if (!previewController.value!.value.hasError) {
        await previewController.value!.setLooping(true);
        videoDuration.value =
            previewController.value!.value.duration.inMilliseconds / 1000;

        // Add listener with null check
        previewController.value!.addListener(_videoListener);

        // Start playing
        await previewController.value!.play();
        isPlaying.value = true;
      }
    } catch (e) {
      print('Error in initializeEditor: $e');
      errorMessage.value = 'Erro ao inicializar editor: $e';
    }
  }

  void _videoListener() {
    try {
      if (previewController.value != null &&
          previewController.value!.value.isInitialized &&
          !previewController.value!.value.hasError) {
        videoPosition.value =
            previewController.value!.value.position.inMilliseconds / 1000;
        isPlaying.value = previewController.value!.value.isPlaying;
      }
    } catch (e) {
      print('Error in video listener: $e');
    }
  }

  void togglePlayPause() {
    if (previewController.value == null) {
      print('Video player is null');
      return;
    }

    try {
      if (previewController.value!.value.isPlaying) {
        previewController.value!.pause();
        isPlaying.value = false;
      } else {
        previewController.value!.play();
        isPlaying.value = true;
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
      errorMessage.value = 'Erro ao controlar reprodução';
    }
  }

  void seekTo(double position) {
    if (previewController.value == null ||
        previewController.value!.value.hasError) {
      print('Video player not ready or has error');
      return;
    }

    try {
      final duration = Duration(milliseconds: (position * 1000).round());
      previewController.value!.seekTo(duration);
    } catch (e) {
      print('Error seeking video: $e');
      errorMessage.value = 'Erro ao navegar no vídeo';
    }
  }

  void setFilter(String filterName) {
    currentFilter.value = filterName;
    if (previewController.value != null) {
      // Reinicialize o player com o filtro
      final currentPosition = previewController.value!.value.position;
      final wasPlaying = previewController.value!.value.isPlaying;

      previewController.value!.pause();
      update(); // Força a reconstrução do widget com o novo filtro

      previewController.value!.seekTo(currentPosition);
      if (wasPlaying) {
        previewController.value!.play();
      }
    }
  }

  Future<void> addMusic() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        selectedMusicPath.value = result.files.single.path!;
        isMusicAdded.value = true;
        Get.snackbar(
          'Sucesso',
          'Música adicionada com sucesso',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error picking music: $e');
      Get.snackbar(
        'Erro',
        'Erro ao selecionar música',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<String?> exportVideo() async {
    if (editor.value == null) return null;

    isExporting.value = true;
    exportText.value = 'Preparando vídeo...';

    try {
      final String dir = (await getTemporaryDirectory()).path;
      final String outputPath = '$dir/edited_video.mp4';

      // Implement export logic here
      // This will depend on your specific requirements for combining
      // filters, music, and text overlays

      isExporting.value = false;
      return outputPath;
    } catch (e) {
      print('Error exporting video: $e');
      isExporting.value = false;
      return null;
    }
  }

  @override
  void onClose() {
    try {
      if (previewController.value != null) {
        previewController.value!.removeListener(_videoListener);
        previewController.value!.pause();
        previewController.value!.dispose();
      }
      editor.value?.dispose();
    } catch (e) {
      print('Error disposing controllers: $e');
    }
    super.onClose();
  }
}
