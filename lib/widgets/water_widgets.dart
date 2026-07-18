import 'dart:math';
import 'package:flutter/material.dart';

/// Renders the JJAASS Water Market droplet logo.
class WaterDropletLogo extends StatelessWidget {
  final double size;
  const WaterDropletLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WaterDropletPainter(),
      ),
    );
  }
}

class _WaterDropletPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0284C7), Color(0xFF009CA6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final path = Path();
    // Drop shape: top point at center top, curves down-left and down-right, rounded bottom
    path.moveTo(size.width / 2, size.height * 0.08);
    // Left shoulder / curve
    path.cubicTo(
      size.width * 0.22, size.height * 0.45,
      size.width * 0.08, size.height * 0.65,
      size.width * 0.5, size.height * 0.95,
    );
    // Right shoulder / curve
    path.cubicTo(
      size.width * 0.92, size.height * 0.65,
      size.width * 0.78, size.height * 0.45,
      size.width / 2, size.height * 0.08,
    );
    path.close();

    canvas.drawPath(path, paint);

    // Dynamic inner reflection
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final highlightPath = Path();
    highlightPath.moveTo(size.width * 0.46, size.height * 0.28);
    highlightPath.quadraticBezierTo(
      size.width * 0.25, size.height * 0.48,
      size.width * 0.32, size.height * 0.68,
    );
    highlightPath.quadraticBezierTo(
      size.width * 0.36, size.height * 0.48,
      size.width * 0.46, size.height * 0.28,
    );
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders a 5-gallon blue plastic water jug on top of waves and leaves.
class WaterJugIllustration extends StatelessWidget {
  final double width;
  final double height;
  const WaterJugIllustration({super.key, this.width = 120, this.height = 140});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _WaterJugPainter(),
      ),
    );
  }
}

class _WaterJugPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw water ripples at the bottom (nested ovals/circles)
    final ripplePaint = Paint()
      ..color = const Color(0xFF009CA6).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(Rect.fromLTRB(w * 0.05, h * 0.76, w * 0.95, h * 0.94), ripplePaint);
    canvas.drawOval(Rect.fromLTRB(w * 0.15, h * 0.81, w * 0.85, h * 0.91), ripplePaint);

    // Splash ripples filled
    final splashPaint = Paint()
      ..color = const Color(0xFF009CA6).withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTRB(w * 0.25, h * 0.83, w * 0.75, h * 0.89), splashPaint);

    // Draw leaves on the left/right
    final leafPaint = Paint()
      ..color = const Color(0xFF10B981) // Emerald Green
      ..style = PaintingStyle.fill;

    // Left leaf
    final leftLeaf = Path();
    leftLeaf.moveTo(w * 0.18, h * 0.82);
    leftLeaf.quadraticBezierTo(w * 0.05, h * 0.72, w * 0.1, h * 0.64);
    leftLeaf.quadraticBezierTo(w * 0.22, h * 0.72, w * 0.18, h * 0.82);
    canvas.drawPath(leftLeaf, leafPaint);

    // Right leaf
    final rightLeaf = Path();
    rightLeaf.moveTo(w * 0.82, h * 0.82);
    rightLeaf.quadraticBezierTo(w * 0.95, h * 0.72, w * 0.9, h * 0.64);
    rightLeaf.quadraticBezierTo(w * 0.78, h * 0.72, w * 0.82, h * 0.82);
    canvas.drawPath(rightLeaf, leafPaint);

    // Draw the Water Jug
    final jugPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTRB(w * 0.28, h * 0.25, w * 0.72, h * 0.8))
      ..style = PaintingStyle.fill;

    final jugPath = Path();
    // Cap/Neck at the top
    jugPath.moveTo(w * 0.44, h * 0.24);
    jugPath.lineTo(w * 0.56, h * 0.24);
    jugPath.lineTo(w * 0.56, h * 0.29);
    jugPath.lineTo(w * 0.44, h * 0.29);
    jugPath.close();

    // Neck connection
    jugPath.moveTo(w * 0.46, h * 0.29);
    jugPath.lineTo(w * 0.54, h * 0.29);
    jugPath.lineTo(w * 0.56, h * 0.35);
    jugPath.lineTo(w * 0.44, h * 0.35);
    jugPath.close();

    // Main jug body
    jugPath.moveTo(w * 0.44, h * 0.35);
    // Shoulder left
    jugPath.quadraticBezierTo(w * 0.26, h * 0.37, w * 0.29, h * 0.47);
    // Body left side
    jugPath.lineTo(w * 0.29, h * 0.75);
    // Bottom left corner
    jugPath.quadraticBezierTo(w * 0.29, h * 0.81, w * 0.38, h * 0.81);
    // Bottom side
    jugPath.lineTo(w * 0.62, h * 0.81);
    // Bottom right corner
    jugPath.quadraticBezierTo(w * 0.71, h * 0.81, w * 0.71, h * 0.75);
    // Body right side
    jugPath.lineTo(w * 0.71, h * 0.47);
    // Shoulder right
    jugPath.quadraticBezierTo(w * 0.74, h * 0.37, w * 0.56, h * 0.35);
    jugPath.close();
    canvas.drawPath(jugPath, jugPaint);

    // Cap on top
    final capPaint = Paint()
      ..color = const Color(0xFF009CA6)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.41, h * 0.18, w * 0.59, h * 0.24), const Radius.circular(4)),
      capPaint,
    );

    // Ribs on the jug body (horizontal styling lines)
    final ribPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(w * 0.31, h * 0.50), Offset(w * 0.69, h * 0.50), ribPaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.58), Offset(w * 0.70, h * 0.58), ribPaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.66), Offset(w * 0.70, h * 0.66), ribPaint);
    canvas.drawLine(Offset(w * 0.31, h * 0.74), Offset(w * 0.69, h * 0.74), ribPaint);

    // Highlight sheen
    final reflectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final reflectionPath = Path();
    reflectionPath.moveTo(w * 0.34, h * 0.46);
    reflectionPath.lineTo(w * 0.37, h * 0.46);
    reflectionPath.lineTo(w * 0.37, h * 0.76);
    reflectionPath.lineTo(w * 0.34, h * 0.76);
    reflectionPath.close();
    canvas.drawPath(reflectionPath, reflectionPaint);

    final shoulderHighlight = Path();
    shoulderHighlight.moveTo(w * 0.38, h * 0.38);
    shoulderHighlight.quadraticBezierTo(w * 0.32, h * 0.40, w * 0.34, h * 0.44);
    shoulderHighlight.quadraticBezierTo(w * 0.35, h * 0.42, w * 0.40, h * 0.39);
    shoulderHighlight.close();
    canvas.drawPath(shoulderHighlight, reflectionPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A wrapper widget that paints double overlapping waves at the bottom.
class WaveBackground extends StatelessWidget {
  final Widget child;
  const WaveBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: WaveBackgroundPainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class WaveBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // First wave (lighter soft cyan)
    final paint1 = Paint()
      ..color = const Color(0xFFE0F2F1)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.88);
    path1.quadraticBezierTo(
      size.width * 0.25, size.height * 0.83,
      size.width * 0.55, size.height * 0.91,
    );
    path1.quadraticBezierTo(
      size.width * 0.8, size.height * 0.96,
      size.width, size.height * 0.90,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Second wave (slightly darker teal sheen)
    final paint2 = Paint()
      ..color = const Color(0xFFB2DFDB).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.93);
    path2.quadraticBezierTo(
      size.width * 0.35, size.height * 0.97,
      size.width * 0.65, size.height * 0.90,
    );
    path2.quadraticBezierTo(
      size.width * 0.85, size.height * 0.86,
      size.width, size.height * 0.93,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders a beautiful curve/line chart matching the screenshot.
class SalesOverviewLineChart extends StatelessWidget {
  final List<double> dataPoints;
  const SalesOverviewLineChart({
    super.key,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SalesOverviewPainter(dataPoints),
    );
  }
}

class _SalesOverviewPainter extends CustomPainter {
  final List<double> data;
  _SalesOverviewPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double gridHeight = size.height;
    final double gridWidth = size.width;

    // Draw background grid lines (horizontal)
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final y = gridHeight * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(gridWidth, y), gridPaint);
    }

    final double minVal = data.reduce(min);
    final double maxVal = data.reduce(max);
    final double valRange = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final double stepX = gridWidth / (data.length - 1);

    double getX(int index) => index * stepX;
    double getY(double val) {
      final double normalized = (val - minVal) / valRange;
      // Leave padding top and bottom
      return gridHeight - (normalized * gridHeight * 0.65) - (gridHeight * 0.15);
    }

    final path = Path();
    final fillPath = Path();

    path.moveTo(getX(0), getY(data[0]));
    fillPath.moveTo(getX(0), gridHeight);
    fillPath.lineTo(getX(0), getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      final double prevX = getX(i - 1);
      final double prevY = getY(data[i - 1]);
      final double currX = getX(i);
      final double currY = getY(data[i]);

      // Cubic bezier control points
      final double cpX1 = prevX + (currX - prevX) / 2;
      final double cpY1 = prevY;
      final double cpX2 = prevX + (currX - prevX) / 2;
      final double cpY2 = currY;

      path.cubicTo(cpX1, cpY1, cpX2, cpY2, currX, currY);
      fillPath.cubicTo(cpX1, cpY1, cpX2, cpY2, currX, currY);
    }

    fillPath.lineTo(getX(data.length - 1), gridHeight);
    fillPath.close();

    // Fill paint with cyan gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF009CA6).withOpacity(0.2),
          const Color(0xFF009CA6).withOpacity(0.00),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, gridWidth, gridHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Line paint
    final linePaint = Paint()
      ..color = const Color(0xFF009CA6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw marker dots
    final dotPaint = Paint()
      ..color = const Color(0xFF009CA6)
      ..style = PaintingStyle.fill;

    final dotOuterPaint = Paint()
      ..color = const Color(0xFF009CA6).withOpacity(0.25)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final Offset pt = Offset(getX(i), getY(data[i]));
      canvas.drawCircle(pt, 7, dotOuterPaint);
      canvas.drawCircle(pt, 4, dotPaint);

      // Friday index is i = 4 (Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6)
      if (i == 4) {
        // Highlight Friday with larger outline
        canvas.drawCircle(pt, 11, Paint()
          ..color = const Color(0xFF009CA6).withOpacity(0.12)
          ..style = PaintingStyle.fill);

        // Draw Friday ₱12,450 box popup above the point
        final boxRect = Rect.fromLTWH(pt.dx - 45, pt.dy - 55, 90, 36);
        final boxPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

        // Shadow for the popup box
        final RRect rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(8));
        canvas.drawRRect(rrect, boxPaint);
        canvas.drawRRect(rrect, borderPaint);

        // Text inside popup box
        const textStyleDay = TextStyle(
          color: Colors.grey,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        );
        const textStyleVal = TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        );

        final textPainterDay = TextPainter(
          text: const TextSpan(text: 'Friday', style: textStyleDay),
          textDirection: TextDirection.ltr,
        )..layout();

        final textPainterVal = TextPainter(
          text: const TextSpan(text: '₱12,450', style: textStyleVal),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainterDay.paint(
          canvas,
          Offset(pt.dx - textPainterDay.width / 2, pt.dy - 50),
        );
        textPainterVal.paint(
          canvas,
          Offset(pt.dx - textPainterVal.width / 2, pt.dy - 38),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SalesOverviewPainter oldDelegate) =>
      oldDelegate.data != data;
}

/// Renders a beautiful Order Status donut chart with custom stats.
class OrderStatusDonutChart extends StatelessWidget {
  const OrderStatusDonutChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DonutChartPainter(),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    '128',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 24.0;
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Values:
    // Completed: 53% (teal)
    // On Delivery: 25% (light blue)
    // Pending: 14% (orange/amber)
    // Cancelled: 8% (red/pink)

    final List<double> percentages = [0.53, 0.25, 0.14, 0.08];
    final List<Color> colors = [
      const Color(0xFF009CA6), // Teal
      const Color(0xFF0284C7), // Light Blue
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
    ];

    double startAngle = -pi / 2; // Start at the top

    for (int i = 0; i < percentages.length; i++) {
      final double sweepAngle = 2 * pi * percentages[i];
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square; // flat edges to align segments correctly

      // Draw arc
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
