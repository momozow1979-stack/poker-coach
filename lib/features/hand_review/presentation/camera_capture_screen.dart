import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// アプリ内カメラ。ライブプレビューに撮影ガイド（テーブル全体の枠と、
/// 下部＝自分のハンドゾーンの線）を重ねて撮る。撮影すると画像バイトを
/// [Navigator.pop] で返す（読み取りは呼び出し側で行う）。
///
/// image_picker では OS 標準カメラが起動してオーバーレイを重ねられないため、
/// ガイドを出したいこの用途だけ camera パッケージで自前プレビューにしている。
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'カメラが見つかりませんでした。';
        });
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _initializing = false;
        _error = 'カメラを起動できませんでした。権限を確認してください。';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _setup();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = '撮影に失敗しました。もう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('テーブル全体を撮影'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    final controller = _controller;
    if (_error.isNotEmpty || controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error.isEmpty ? 'カメラを利用できません。' : _error,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(controller)),
        // 撮影ガイド（枠と自分ゾーンの線）。
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _GuideOverlayPainter()),
          ),
        ),
        const Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: Text(
            '中央＝場（右→フロップ・ターン・リバー）',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const Positioned(
          left: 16,
          right: 16,
          bottom: 150,
          child: Text(
            'この線の下＝自分のハンド',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7CC8FF), fontSize: 12),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Center(
            child: GestureDetector(
              onTap: _capture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white70, width: 4),
                ),
                child: _capturing
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 32,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// テーブル全体の破線枠と、下部の「自分のハンド」ゾーンを区切る線を描く。
class _GuideOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 破線の角丸枠（テーブル全体を入れる目安）。
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      const Radius.circular(12),
    );
    _drawDashedRRect(canvas, rect, framePaint);

    // 下部＝自分のハンドゾーンの区切り線（青）。
    final linePaint = Paint()
      ..color = const Color(0xFF7CC8FF)
      ..strokeWidth = 2;
    final y = size.height - 170;
    canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), linePaint);
  }

  void _drawDashedRRect(Canvas canvas, RRect rect, Paint paint) {
    final path = Path()..addRRect(rect);
    const dash = 10.0;
    const gap = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GuideOverlayPainter oldDelegate) => false;
}
