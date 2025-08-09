import 'package:flutter/material.dart';
import 'package:trace/home/feed/video_watermark_processor.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:io';

class VideoPostEditor extends StatefulWidget {
  final int followerCount;

  const VideoPostEditor({
    Key? key,
    required this.followerCount,
  }) : super(key: key);

  @override
  State<VideoPostEditor> createState() => _VideoPostEditorState();
}

class _VideoPostEditorState extends State<VideoPostEditor> {
  late CameraController _cameraController;
  bool _isRecording = false;
  VideoPlayerController? _videoPlayerController;
  Duration _maxDuration = const Duration(seconds: 15);
  bool _isProcessing = false;
  double _compressionProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setMaxDurationBasedOnFollowers();
    _subscribeToCompressionProgress();
  }

  void _subscribeToCompressionProgress() {
    VideoCompress.compressProgress$.subscribe((progress) {
      setState(() {
        _compressionProgress = progress;
      });
    });
  }

  void _setMaxDurationBasedOnFollowers() {
    if (widget.followerCount > 10000) {
      _maxDuration = const Duration(minutes: 2);
    } else if (widget.followerCount > 5000) {
      _maxDuration = const Duration(minutes: 1);
    } else if (widget.followerCount > 1000) {
      _maxDuration = const Duration(seconds: 30);
    } else {
      _maxDuration = const Duration(seconds: 15);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await _cameraController.initialize();
      setState(() {});
    } catch (e) {
      print('Erro ao inicializar câmera: $e');
    }
  }

  Future<void> _startVideoRecording() async {
    if (!_cameraController.value.isInitialized) return;

    try {
      await _cameraController.startVideoRecording();
      setState(() => _isRecording = true);

      // Parar automaticamente quando atingir o tempo máximo
      Future.delayed(_maxDuration, () {
        if (_isRecording) {
          _stopVideoRecording();
        }
      });
    } catch (e) {
      print('Erro ao iniciar gravação: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_isRecording) return;

    try {
      final XFile video = await _cameraController.stopVideoRecording();
      setState(() => _isRecording = false);
      await _processVideo(video);
    } catch (e) {
      print('Erro ao parar gravação: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: _maxDuration,
    );

    if (video != null) {
      await _processVideo(video);
    }
  }

  Future<void> _processVideo(XFile videoFile) async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Comprimir o vídeo
      final compressedPath =
          await VideoWatermarkProcessor.compressVideo(videoFile.path);

      if (compressedPath == null) {
        throw Exception('Falha ao comprimir o vídeo');
      }

      // Inicializar o player com o vídeo processado
      await _initializeVideoPlayer(compressedPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar o vídeo: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _compressionProgress = 0.0;
      });
    }
  }

  Future<void> _initializeVideoPlayer(String videoPath) async {
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(File(videoPath))
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController?.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Criar Vídeo'),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library),
            onPressed: _pickVideoFromGallery,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _buildPreviewWidget(),
              ),
              _buildDurationInfo(),
              _buildControlButtons(),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _compressionProgress / 100,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processando: ${_compressionProgress.toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewWidget() {
    if (_videoPlayerController?.value.isInitialized ?? false) {
      return AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: VideoPlayer(_videoPlayerController!),
      );
    }

    if (_cameraController.value.isInitialized) {
      return CameraPreview(_cameraController);
    }

    return Center(child: CircularProgressIndicator());
  }

  Widget _buildDurationInfo() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        'Duração máxima: ${_maxDuration.inSeconds} segundos',
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            onPressed:
                _isRecording ? _stopVideoRecording : _startVideoRecording,
            child: Icon(_isRecording ? Icons.stop : Icons.videocam),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    VideoCompress.cancelCompression();
    _cameraController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }
}
