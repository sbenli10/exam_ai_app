import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ai_solution.dart';
import '../services/ai_service.dart';

class AiQuestionSolverScreen extends StatefulWidget {
  const AiQuestionSolverScreen({super.key});

  @override
  State<AiQuestionSolverScreen> createState() => _AiQuestionSolverScreenState();
}

class _AiQuestionSolverScreenState extends State<AiQuestionSolverScreen> {
  final AiService _aiService = AiService();
  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  Future<void>? _cameraInitialization;
  XFile? _capturedImage;
  AiSolution? _solution;
  bool _isAnalyzing = false;
  bool _isOpeningMedia = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cameraInitialization = _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('AI Soru Çöz'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderSection(imageSelected: _capturedImage != null),
              const SizedBox(height: 20),
              _buildCameraSection(),
              const SizedBox(height: 18),
              _buildPrimaryActions(),
              if (_isAnalyzing) ...[
                const SizedBox(height: 18),
                const _AnalyzingCard(),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                _ErrorCard(message: _errorMessage!),
              ],
              if (_solution != null) ...[
                const SizedBox(height: 18),
                _SolutionCard(solution: _solution!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soru Önizleme',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: _capturedImage != null
                  ? Image.file(
                      File(_capturedImage!.path),
                      fit: BoxFit.cover,
                    )
                  : FutureBuilder<void>(
                      future: _cameraInitialization,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const _CameraPlaceholder(
                            title: 'Kamera hazırlanıyor',
                            subtitle: 'Soru fotoğrafını çekmek için kamera başlatılıyor.',
                            loading: true,
                          );
                        }

                        if (snapshot.hasError || _cameraController == null) {
                          return const _CameraPlaceholder(
                            title: 'Kamera açılamadı',
                            subtitle: 'Galeri seçeneğini kullanarak soru görseli ekleyebilirsin.',
                          );
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_cameraController!),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.42),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'Canlı kamera önizlemesi. Fotoğraf Çek butonu bu görüntüyü kaydeder.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isAnalyzing || _isOpeningMedia ? null : _captureWithSystemCamera,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text(
              'Fotoğraf Çek',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isAnalyzing || _isOpeningMedia ? null : _pickFromGallery,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD9DFEF)),
                  foregroundColor: const Color(0xFF334155),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeriden Seç'),
              ),
            ),
            if (_capturedImage != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing || _isOpeningMedia ? null : _analyzeCurrentImage,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFBFC8FF)),
                    foregroundColor: const Color(0xFF4054C8),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AI ile Çöz'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _cameraController = controller;
    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);
  }

  Future<void> _captureQuestion() async {
    if (_isOpeningMedia) {
      return;
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      setState(() {
        _errorMessage = 'Kamera hazır değil. Birkaç saniye sonra tekrar deneyin.';
      });
      return;
    }

    try {
      setState(() {
        _isOpeningMedia = true;
      });
      final image = await controller.takePicture();
      setState(() {
        _capturedImage = image;
        _solution = null;
        _errorMessage = null;
      });
      await _analyzeCurrentImage();
    } catch (error) {
      setState(() {
        _errorMessage = 'Fotoğraf çekilirken hata oluştu: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningMedia = false;
        });
      }
    }
  }

  Future<void> _captureWithSystemCamera() async {
    if (_isOpeningMedia) {
      return;
    }

    try {
      setState(() {
        _isOpeningMedia = true;
        _errorMessage = null;
      });

      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _capturedImage = image;
        _solution = null;
      });

      await _analyzeCurrentImage();
    } catch (error) {
      setState(() {
        _errorMessage = 'Kamera açılırken hata oluştu: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningMedia = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isOpeningMedia) {
      return;
    }

    try {
      setState(() {
        _isOpeningMedia = true;
        _errorMessage = null;
      });

      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _capturedImage = image;
        _solution = null;
        _errorMessage = null;
      });
      await _analyzeCurrentImage();
    } catch (error) {
      final message = error.toString().contains('already_active')
          ? 'Galeri seçici zaten açık görünüyor. Emülatörde bu durum sık olur. Ekranı kapatıp tekrar deneyin veya gerçek cihaz kullanın.'
          : 'Görsel seçilirken hata oluştu: $error';
      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningMedia = false;
        });
      }
    }
  }

  Future<void> _analyzeCurrentImage() async {
    final image = _capturedImage;
    if (image == null) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _solution = null;
      _errorMessage = null;
    });

    try {
      final bytes = await image.readAsBytes();
      final solution = await _aiService.analyzeQuestionImage(
        imageBytes: bytes,
        mimeType: _guessMimeType(image.path),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _solution = solution;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'AI analizi başarısız oldu: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.imageSelected,
  });

  final bool imageSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D3A8C), Color(0xFF5A6BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'AI Vision Solver',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'AI Soru Çöz',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sorunun fotoğrafını çek ve çözümü öğren.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.90),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const _HeroMiniCard(
                icon: Icons.camera_alt_rounded,
                label: 'Fotoğraf çek',
              ),
              const SizedBox(width: 12),
              _HeroMiniCard(
                icon: imageSelected ? Icons.check_circle_rounded : Icons.auto_awesome_rounded,
                label: imageSelected ? 'Analize hazır' : 'AI çözüm üret',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMiniCard extends StatelessWidget {
  const _HeroMiniCard({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({
    required this.title,
    required this.subtitle,
    this.loading = false,
  });

  final String title;
  final String subtitle;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const CircularProgressIndicator(color: Colors.white)
              else
                const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
                  size: 44,
                ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.75),
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'AI soruyu analiz ediyor...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF991B1B),
              height: 1.5,
            ),
      ),
    );
  }
}

class _SolutionCard extends StatelessWidget {
  const _SolutionCard({
    required this.solution,
  });

  final AiSolution solution;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF4054C8),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Çözüm',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoSection(
            title: 'Sorunun Konusu',
            child: Text(
              solution.topic,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          _InfoSection(
            title: 'Çözüm Adımları',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < solution.steps.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Color(0xFF4054C8),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          solution.steps[i],
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF334155),
                                height: 1.6,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (i != solution.steps.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _InfoSection(
            title: 'Sonuç',
            child: Text(
              solution.result,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    height: 1.55,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
