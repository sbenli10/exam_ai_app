import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
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
  XFile? _selectedImage;
  AiSolution? _solution;
  String? _errorMessage;
  bool _isAnalyzing = false;
  bool _isOpeningMedia = false;

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
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AI Soru Çözümü',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _AiHeroCard(),
            const SizedBox(height: 14),
            _PreviewCard(
              image: _selectedImage,
              cameraInitialization: _cameraInitialization,
              cameraController: _cameraController,
            ),
            const SizedBox(height: 14),
            _ActionButtons(
              hasImage: _selectedImage != null,
              isBusy: _isAnalyzing || _isOpeningMedia,
              onCameraTap: _captureWithSystemCamera,
              onGalleryTap: _pickFromGallery,
              onAnalyzeTap: _analyzeCurrentImage,
            ),
            if (_isAnalyzing) ...[
              const SizedBox(height: 14),
              const _AnalyzingCard(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _StatusCard(
                title: 'Bir sorun oluştu',
                message: _errorMessage!,
                color: const Color(0xFFBE123C),
                background: const Color(0xFFFFF1F2),
              ),
            ],
            if (_solution != null) ...[
              const SizedBox(height: 14),
              _SolutionOverviewCard(solution: _solution!),
              const SizedBox(height: 14),
              _SolutionStepsCard(solution: _solution!),
              const SizedBox(height: 14),
              _ResultCard(solution: _solution!),
            ],
          ],
        ),
      ),
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

  Future<void> _captureWithSystemCamera() async {
    if (_isOpeningMedia) return;

    try {
      setState(() {
        _isOpeningMedia = true;
        _errorMessage = null;
      });

      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = image;
        _solution = null;
      });

      await _analyzeCurrentImage();
    } catch (error) {
      setState(() {
        _errorMessage = 'Kamera açılırken bir sorun oluştu. Lütfen tekrar dene.';
      });
    } finally {
      if (mounted) {
        setState(() => _isOpeningMedia = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isOpeningMedia) return;

    try {
      setState(() {
        _isOpeningMedia = true;
        _errorMessage = null;
      });

      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = image;
        _solution = null;
      });

      await _analyzeCurrentImage();
    } catch (error) {
      final raw = error.toString().toLowerCase();
      setState(() {
        _errorMessage = raw.contains('already_active')
            ? 'Galeri zaten açık görünüyor. Pencereyi kapatıp yeniden deneyebilirsin.'
            : 'Görsel seçilirken bir sorun oluştu. Lütfen tekrar dene.';
      });
    } finally {
      if (mounted) {
        setState(() => _isOpeningMedia = false);
      }
    }
  }

  Future<void> _analyzeCurrentImage() async {
    final image = _selectedImage;
    if (image == null) {
      setState(() {
        _errorMessage = 'Önce bir soru fotoğrafı seçmelisin.';
      });
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

      if (!mounted) return;
      setState(() => _solution = solution);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'AI bu soruyu yorumlarken zorlandı. Daha net bir fotoğrafla yeniden deneyebilirsin.';
      });
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class _AiHeroCard extends StatelessWidget {
  const _AiHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.18),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _HeroBadge(),
          SizedBox(height: 14),
          Text(
            'Soruyu fotoğraftan çözdür',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Kamera ile çek, galeriden seç veya ekran görüntüsü yükle. AI çözüm adımlarını öğrenci dostu şekilde anlatsın.',
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(CupertinoIcons.sparkles, size: 14, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'AI destekli çözüm',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.image,
    required this.cameraInitialization,
    required this.cameraController,
  });

  final XFile? image;
  final Future<void>? cameraInitialization;
  final CameraController? cameraController;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soru önizleme alanı',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seçtiğin görsel burada görünür. Fotoğrafın net olması, çözüm kalitesini artırır.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: image != null
                  ? Image.file(File(image!.path), fit: BoxFit.cover)
                  : FutureBuilder<void>(
                      future: cameraInitialization,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const _CameraPlaceholder(
                            title: 'Kamera hazırlanıyor',
                            subtitle: 'Birazdan canlı önizleme burada görünecek.',
                            loading: true,
                          );
                        }

                        if (snapshot.hasError || cameraController == null) {
                          return const _CameraPlaceholder(
                            title: 'Kamera kullanılamadı',
                            subtitle: 'İstersen galeriden görsel seçerek devam edebilirsin.',
                          );
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(cameraController!),
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.42),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'Canlı kamera önizlemesi açık. Fotoğraf çektiğinde soru otomatik analiz edilir.',
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
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.hasImage,
    required this.isBusy,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onAnalyzeTap,
  });

  final bool hasImage;
  final bool isBusy;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onAnalyzeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: isBusy ? null : onCameraTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(CupertinoIcons.camera_fill),
            label: const Text(
              'Fotoğraf çek',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onGalleryTap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFD9DFEF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(CupertinoIcons.photo_on_rectangle),
                label: const Text('Galeriden seç'),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onAnalyzeTap,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFD3FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.sparkles),
                  label: const Text('Yeniden analiz et'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard();

  @override
  Widget build(BuildContext context) {
    return const _StatusCard(
      title: 'AI çözüm hazırlıyor',
      message: 'Fotoğrafındaki soruyu inceliyor, konuyu buluyor ve çözüm adımlarını hazırlıyor.',
      color: Color(0xFF2563EB),
      background: Color(0xFFEFF6FF),
      loading: true,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.message,
    required this.color,
    required this.background,
    this.loading = false,
  });

  final String title;
  final String message;
  final Color color;
  final Color background;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: color,
              ),
            )
          else
            Icon(CupertinoIcons.info_circle_fill, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SolutionOverviewCard extends StatelessWidget {
  const _SolutionOverviewCard({required this.solution});

  final AiSolution solution;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0ECFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI çözüm özeti',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tespit edilen konu',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              solution.topic,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolutionStepsCard extends StatelessWidget {
  const _SolutionStepsCard({required this.solution});

  final AiSolution solution;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Çözüm adımları',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          ...solution.steps.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: entry.key == solution.steps.length - 1 ? 0 : 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0ECFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF334155),
                                height: 1.55,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.solution});

  final AiSolution solution;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sonuç',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            solution.result,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF0F172A),
                  height: 1.6,
                  fontWeight: FontWeight.w700,
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
                  CupertinoIcons.camera,
                  color: Colors.white,
                  size: 44,
                ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.78),
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: child,
    );
  }
}
