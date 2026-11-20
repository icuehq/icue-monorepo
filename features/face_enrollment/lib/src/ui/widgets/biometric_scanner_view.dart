import 'dart:io';

import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:flutter/material.dart';

class BiometricScannerView extends StatelessWidget {
  const BiometricScannerView({
    super.key,
    required this.localImagePath,
    required this.photoUrl,
    this.imageSource,
    required this.isScanning,
    required this.scanAnimation,
    required this.size,
  });
  final String? localImagePath;
  final String? photoUrl;
  final String? imageSource;
  final bool isScanning;
  final Animation<double> scanAnimation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isScanning ? context.scheme.primary : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned.fill(
              child:
                  (imageSource == 'Camera' || imageSource == 'Gallery') &&
                      localImagePath != null
                  ? Image.file(File(localImagePath!), fit: BoxFit.cover)
                  : (photoUrl != null && photoUrl!.isNotEmpty
                        ? Image.network(
                            photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Icon(
                                    Icons.face_unlock_rounded,
                                    size: 140,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                          )
                        : Center(
                            child: Icon(
                              Icons.face_unlock_rounded,
                              size: 140,
                              color: Colors.grey.shade300,
                            ),
                          )),
            ),

            // Overlay grid/mesh pattern to look high-tech
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(painter: GridPainter()),
              ),
            ),

            // Active Laser Scan line animation
            if (isScanning)
              AnimatedBuilder(
                animation: scanAnimation,
                builder: (context, child) {
                  final offset = scanAnimation.value * size;
                  return Positioned(
                    top: offset,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.scheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: context.scheme.primary.withValues(
                              alpha: 0.8,
                            ),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Scanner corners indicators
            _buildScannerCorner(context, true, true),
            _buildScannerCorner(context, true, false),
            _buildScannerCorner(context, false, true),
            _buildScannerCorner(context, false, false),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCorner(BuildContext context, bool top, bool left) {
    const len = 20.0;
    const thickness = 4.0;
    final color = context.scheme.primary;

    return Positioned(
      top: top ? 12 : null,
      bottom: !top ? 12 : null,
      left: left ? 12 : null,
      right: !left ? 12 : null,
      child: SizedBox(
        width: len,
        height: len,
        child: CustomPaint(
          painter: CornerPainter(
            top: top,
            left: left,
            color: color,
            thickness: thickness,
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;

    const spacing = 20.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CornerPainter extends CustomPainter {
  CornerPainter({
    required this.top,
    required this.left,
    required this.color,
    required this.thickness,
  });
  final bool top;
  final bool left;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
