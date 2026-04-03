import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../providers/auth_provider.dart';
import '../../services/queue_service.dart';
import '../../services/shop_service.dart';
import '../../providers/shop_provider.dart'; // ← add this

// ============================================================
// qr_scan_screen.dart
// ============================================================
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  MobileScannerController? _scannerController;
  bool _scanned = false;
  String? _detectedShopId;
  Map<String, dynamic>? _shopData;
  bool _loadingShop = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _onQrDetected(String qrValue) async {
    if (_scanned) return;
    setState(() {
      _scanned = true;
      _loadingShop = true;
    });
    _scannerController?.stop();

    try {
      // QR code contains the shop's qr_code field value
      // We need to find the shop by qr_code
      final shopService = ref.read(shopServiceProvider);
      // In a real app, you'd have a method to find shop by QR code
      // For now, if qrValue is a UUID we treat it as shop_id
      final shop = await shopService.getShopById(qrValue);
      if (mounted) {
        setState(() {
          _shopData = shop;
          _loadingShop = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingShop = false;
          _scanned = false;
        });
        _scannerController?.start();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Scan Shop QR'),
        actions: [
          if (_scanned)
            TextButton(
              onPressed: () {
                setState(() {
                  _scanned = false;
                  _shopData = null;
                });
                _scannerController?.start();
              },
              child: const Text('Scan Again', style: TextStyle(color: AppColors.electricBlue)),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera
          if (!_scanned)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull;
                if (barcode?.rawValue != null) {
                  _onQrDetected(barcode!.rawValue!);
                }
              },
            ),

          // Scanner overlay
          if (!_scanned)
            _buildScannerOverlay(),

          // Shop info after scan
          if (_scanned)
            _buildScannedResult(),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        // Dark overlay with cutout
        CustomPaint(
          painter: _ScannerOverlayPainter(),
          size: MediaQuery.of(context).size,
        ),
        // Scan frame
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.electricBlue, width: 2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.electricBlue.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Corner decorations
                    ..._buildCorners(),
                    // Scan line animation
                    _ScanLine(),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Point camera at shop\'s QR code',
                style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'The code is displayed at the counter',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCorners() {
    return [
      Positioned(top: 0, left: 0, child: _Corner(rotate: 0)),
      Positioned(top: 0, right: 0, child: _Corner(rotate: 90)),
      Positioned(bottom: 0, right: 0, child: _Corner(rotate: 180)),
      Positioned(bottom: 0, left: 0, child: _Corner(rotate: 270)),
    ];
  }

  Widget _buildScannedResult() {
    if (_loadingShop) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.electricBlue),
            SizedBox(height: 16),
            Text('Loading shop...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_shopData == null) return const SizedBox();

    final queue = _shopData!['queues'] as Map? ?? {};
    final totalWaiting = (queue['total_waiting'] as int?) ?? 0;
    final isOpen = _shopData!['is_open'] as bool? ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 64)).animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text('Shop Found!', style: AppTextStyles.headlineLarge).animate(delay: 200.ms).fadeIn(),
            const SizedBox(height: 24),
            GlassCard(
              borderRadius: 20,
              borderColor: AppColors.neonGreen.withOpacity(0.3),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        _emoji(_shopData!['category'] ?? ''),
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_shopData!['name'] ?? '', style: AppTextStyles.headlineMedium),
                            Text(_shopData!['address'] ?? '', style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [
                        Text('$totalWaiting', style: AppTextStyles.neonGlow(AppColors.statusWaiting, size: 22)),
                        Text('waiting', style: AppTextStyles.bodySmall),
                      ]),
                      Column(children: [
                        Text(
                          isOpen ? 'OPEN' : 'CLOSED',
                          style: AppTextStyles.neonGlow(
                              isOpen ? AppColors.neonGreen : Colors.red, size: 16),
                        ),
                        Text('status', style: AppTextStyles.bodySmall),
                      ]),
                    ],
                  ),
                ],
              ),
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.15, end: 0),
            const SizedBox(height: 24),
            if (isOpen)
              GradientButton(
                label: 'Join Queue',
                onTap: () => context.pushReplacement('/book/${_shopData!['id']}'),
                colors: AppColors.primaryGradient,
                icon: const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 20),
              ).animate(delay: 500.ms).fadeIn()
            else
              const Text('This shop is currently closed', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  String _emoji(String cat) {
    const map = {'canteen': '🍽️', 'hospital': '🏥', 'bank': '🏦', 'clinic': '🩺', 'salon': '✂️'};
    return map[cat] ?? '🏪';
  }
}

class _Corner extends StatelessWidget {
  final double rotate;
  const _Corner({required this.rotate});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate * 3.14159 / 180,
      child: SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neonGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ScanLine extends StatefulWidget {
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Positioned(
        top: _anim.value * 220,
        left: 0,
        right: 0,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.electricBlue,
                AppColors.neonGreen,
                AppColors.electricBlue,
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.electricBlue.withOpacity(0.6), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final cutoutSize = 240.0;
    final cutoutLeft = (size.width - cutoutSize) / 2;
    final cutoutTop = (size.height - cutoutSize) / 2;
    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutSize, cutoutSize),
      const Radius.circular(20),
    );
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(cutout),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
