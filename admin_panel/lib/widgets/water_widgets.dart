import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

/// Renders the JJAASS Water Market logo emblem.
class WaterDropletLogo extends StatelessWidget {
  final double size;
  final bool rounded;
  final bool showShadow;

  const WaterDropletLogo({
    super.key,
    this.size = 64,
    this.rounded = true,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(rounded ? size / 2 : 12),
      child: Image.asset(
        'assets/images/logo_icon.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _WaterDropletPainter(),
          ),
        ),
      ),
    );

    if (showShadow) {
      return Container(
        decoration: BoxDecoration(
          shape: rounded ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: rounded ? null : BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: imageWidget,
      );
    }
    return imageWidget;
  }
}

/// Renders the full horizontal banner logo of JJAASS Water Market.
class JjaassFullLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const JjaassFullLogo({
    super.key,
    this.width,
    this.height = 50,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/images/logo_full.jpg',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WaterDropletLogo(size: height ?? 40),
          const SizedBox(width: 10),
          const Text(
            'JJAASS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1.2,
              color: Color(0xFF0F2B5C),
            ),
          ),
        ],
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }
    return image;
  }
}

class _WaterDropletPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
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
      ..color = Colors.white.withValues(alpha: 0.3)
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
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(Rect.fromLTRB(w * 0.05, h * 0.76, w * 0.95, h * 0.94), ripplePaint);
    canvas.drawOval(Rect.fromLTRB(w * 0.15, h * 0.81, w * 0.85, h * 0.91), ripplePaint);

    // Splash ripples filled
    final splashPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.08)
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
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.41, h * 0.18, w * 0.59, h * 0.24), const Radius.circular(4)),
      capPaint,
    );

    // Ribs on the jug body (horizontal styling lines)
    final ribPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(w * 0.31, h * 0.50), Offset(w * 0.69, h * 0.50), ribPaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.58), Offset(w * 0.70, h * 0.58), ribPaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.66), Offset(w * 0.70, h * 0.66), ribPaint);
    canvas.drawLine(Offset(w * 0.31, h * 0.74), Offset(w * 0.69, h * 0.74), ribPaint);

    // Highlight sheen
    final reflectionPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
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
    // First wave (Logo Deep Navy tint)
    final paint1 = Paint()
      ..color = const Color(0xFF0F2B5C).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.86);
    path1.quadraticBezierTo(
      size.width * 0.25, size.height * 0.80,
      size.width * 0.55, size.height * 0.89,
    );
    path1.quadraticBezierTo(
      size.width * 0.8, size.height * 0.95,
      size.width, size.height * 0.88,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Second wave (Logo Cornflower/Azure Blue tint)
    final paint2 = Paint()
      ..color = const Color(0xFF4788D7).withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.92);
    path2.quadraticBezierTo(
      size.width * 0.35, size.height * 0.97,
      size.width * 0.65, size.height * 0.89,
    );
    path2.quadraticBezierTo(
      size.width * 0.85, size.height * 0.84,
      size.width, size.height * 0.92,
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
/// Renders an interactive, auto-scaling curve/line chart matching live transactions.
class SalesOverviewLineChart extends StatefulWidget {
  final List<double> dataPoints;
  final List<String> labels;
  final int? selectedIndex;
  final ValueChanged<int>? onPointSelected;
  final bool isDark;

  const SalesOverviewLineChart({
    super.key,
    required this.dataPoints,
    this.labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    this.selectedIndex,
    this.onPointSelected,
    this.isDark = false,
  });

  @override
  State<SalesOverviewLineChart> createState() => _SalesOverviewLineChartState();
}

class _SalesOverviewLineChartState extends State<SalesOverviewLineChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final activeIndex = _hoveredIndex ?? widget.selectedIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (widget.dataPoints.isEmpty) return;
            final double width = constraints.maxWidth;
            final double stepX = widget.dataPoints.length > 1
                ? width / (widget.dataPoints.length - 1)
                : width;
            final int tappedIndex = (details.localPosition.dx / stepX).round().clamp(0, widget.dataPoints.length - 1);
            setState(() {
              _hoveredIndex = tappedIndex;
            });
            widget.onPointSelected?.call(tappedIndex);
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _SalesOverviewPainter(
              data: widget.dataPoints,
              labels: widget.labels,
              selectedIndex: activeIndex,
              isDark: widget.isDark,
            ),
          ),
        );
      },
    );
  }
}

class _SalesOverviewPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int? selectedIndex;
  final bool isDark;

  _SalesOverviewPainter({
    required this.data,
    required this.labels,
    this.selectedIndex,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double gridHeight = size.height;
    final double gridWidth = size.width;

    // Draw background grid lines (horizontal)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = gridHeight * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(gridWidth, y), gridPaint);
    }

    double minVal = data.reduce(min);
    double maxVal = data.reduce(max);
    if (maxVal == minVal) {
      if (maxVal == 0) {
        maxVal = 1000;
        minVal = 0;
      } else {
        maxVal = maxVal * 1.25;
        minVal = minVal * 0.75;
      }
    }
    final double valRange = maxVal - minVal;

    final double stepX = data.length > 1 ? gridWidth / (data.length - 1) : gridWidth;

    double getX(int index) => index * stepX;
    double getY(double val) {
      final double normalized = (val - minVal) / valRange;
      // Keep within comfortable padding bounds
      return gridHeight - (normalized * gridHeight * 0.60) - (gridHeight * 0.15);
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

      // Smooth cubic bezier control points
      final double cpX1 = prevX + (currX - prevX) / 2;
      final double cpY1 = prevY;
      final double cpX2 = prevX + (currX - prevX) / 2;
      final double cpY2 = currY;

      path.cubicTo(cpX1, cpY1, cpX2, cpY2, currX, currY);
      fillPath.cubicTo(cpX1, cpY1, cpX2, cpY2, currX, currY);
    }

    fillPath.lineTo(getX(data.length - 1), gridHeight);
    fillPath.close();

    // Fill paint with cyan/blue gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.22),
          const Color(0xFF0284C7).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, gridWidth, gridHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Line paint
    final linePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw marker dots
    final dotPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;

    final dotOuterPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // Determine which point to highlight (default to peak index or last non-zero)
    int highlightIdx = selectedIndex ?? 0;
    if (selectedIndex == null) {
      double highest = -1;
      for (int i = 0; i < data.length; i++) {
        if (data[i] >= highest) {
          highest = data[i];
          highlightIdx = i;
        }
      }
    }

    for (int i = 0; i < data.length; i++) {
      final Offset pt = Offset(getX(i), getY(data[i]));
      canvas.drawCircle(pt, 6, dotOuterPaint);
      canvas.drawCircle(pt, 3.5, dotPaint);

      if (i == highlightIdx) {
        // Highlight active point
        canvas.drawCircle(
          pt,
          11,
          Paint()
            ..color = const Color(0xFF0284C7).withValues(alpha: 0.2)
            ..style = PaintingStyle.fill,
        );

        // Draw Dynamic Tooltip Box above the point
        final double boxWidth = 92;
        final double boxHeight = 38;
        double boxLeft = (pt.dx - boxWidth / 2).clamp(4.0, gridWidth - boxWidth - 4.0);
        double boxTop = pt.dy - boxHeight - 12;
        if (boxTop < 2) boxTop = pt.dy + 12;

        final boxRect = Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight);
        final boxPaint = Paint()
          ..color = isDark ? const Color(0xFF1E293B) : Colors.white
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = isDark ? Colors.white24 : const Color(0xFFE2E8F0)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

        final RRect rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(8));
        canvas.drawRRect(rrect, boxPaint);
        canvas.drawRRect(rrect, borderPaint);

        // Day label and formatted Revenue
        final String dayText = i < labels.length ? labels[i] : 'Day ${i + 1}';
        final String valText = '₱${data[i].toStringAsFixed(data[i] % 1 == 0 ? 0 : 2)}';

        final textStyleDay = TextStyle(
          color: isDark ? Colors.white60 : Colors.grey.shade600,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        );
        final textStyleVal = TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        );

        final textPainterDay = TextPainter(
          text: TextSpan(text: dayText, style: textStyleDay),
          textDirection: TextDirection.ltr,
        )..layout();

        final textPainterVal = TextPainter(
          text: TextSpan(text: valText, style: textStyleVal),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainterDay.paint(
          canvas,
          Offset(boxLeft + (boxWidth - textPainterDay.width) / 2, boxTop + 4),
        );
        textPainterVal.paint(
          canvas,
          Offset(boxLeft + (boxWidth - textPainterVal.width) / 2, boxTop + 18),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SalesOverviewPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.isDark != isDark;
}

/// Renders a live, real-time Order Status donut chart.
class OrderStatusDonutChart extends StatelessWidget {
  final int completedCount;
  final int onDeliveryCount;
  final int pendingCount;
  final int cancelledCount;
  final bool isDark;

  const OrderStatusDonutChart({
    super.key,
    this.completedCount = 0,
    this.onDeliveryCount = 0,
    this.pendingCount = 0,
    this.cancelledCount = 0,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final int total = completedCount + onDeliveryCount + pendingCount + cancelledCount;

    final double pctCompleted = total > 0 ? completedCount / total : 0.0;
    final double pctOnDelivery = total > 0 ? onDeliveryCount / total : 0.0;
    final double pctPending = total > 0 ? pendingCount / total : 0.0;
    final double pctCancelled = total > 0 ? cancelledCount / total : 0.0;

    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DonutChartPainter(
                  percentages: [pctCompleted, pctOnDelivery, pctPending, pctCancelled],
                  total: total,
                  isDark: isDark,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Total Orders',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade500,
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
  final List<double> percentages;
  final int total;
  final bool isDark;

  _DonutChartPainter({
    required this.percentages,
    required this.total,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 22.0;
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Colors matching theme:
    // Completed: Teal / Sky Blue
    // On Delivery: Bright Blue
    // Pending: Amber / Orange
    // Cancelled: Rose / Red
    final List<Color> colors = [
      const Color(0xFF0284C7), // Completed (Teal/Sky)
      const Color(0xFF38BDF8), // On Delivery (Cyan/Blue)
      const Color(0xFFF59E0B), // Pending (Amber)
      const Color(0xFFEF4444), // Cancelled (Red)
    ];

    if (total == 0) {
      // Draw placeholder empty ring
      final emptyPaint = Paint()
        ..color = (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      canvas.drawArc(rect, 0, 2 * pi, false, emptyPaint);
      return;
    }

    double startAngle = -pi / 2; // Start at the top

    for (int i = 0; i < percentages.length; i++) {
      final double sweepAngle = 2 * pi * percentages[i];
      if (sweepAngle <= 0.001) continue;

      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.percentages != percentages ||
      oldDelegate.total != total ||
      oldDelegate.isDark != isDark;
}

/// Live Interactive Fleet GPS Route Monitor with Real Google Map & Telemetry
class LiveFleetGpsMapWidget extends StatefulWidget {
  final List<OrderModel> orders;
  final List<UserModel> drivers;
  final OrderModel? selectedOrder;
  final ValueChanged<OrderModel>? onSelectOrder;
  final bool isDark;
  final bool satelliteMode;

  const LiveFleetGpsMapWidget({
    super.key,
    required this.orders,
    required this.drivers,
    this.selectedOrder,
    this.onSelectOrder,
    this.isDark = false,
    this.satelliteMode = false,
  });

  @override
  State<LiveFleetGpsMapWidget> createState() => _LiveFleetGpsMapWidgetState();
}

class _LiveFleetGpsMapWidgetState extends State<LiveFleetGpsMapWidget> {
  GoogleMapController? _mapController;

  // JJAASS Water Market HQ in Ligao City, Albay, Philippines
  static const LatLng _stationHQ = LatLng(13.2415, 123.5358);

  LatLng _getOrderCoord(OrderModel order, int index) {
    if (order.latitude != null && order.longitude != null) {
      return LatLng(order.latitude!, order.longitude!);
    }
    // Deterministic offset in Ligao City for orders without raw GPS
    final hash = order.id.hashCode;
    final latOffset = ((hash % 100) / 10000.0) - 0.005 + (index * 0.0018);
    final lngOffset = (((hash >> 4) % 100) / 10000.0) - 0.005 - (index * 0.0016);
    return LatLng(_stationHQ.latitude + latOffset, _stationHQ.longitude + lngOffset);
  }

  LatLng _getDriverCoord(OrderModel order, LatLng destCoord) {
    // Rider midway or near destination if active
    if (order.orderStatus == OrderStatus.onDelivery) {
      return LatLng(
        _stationHQ.latitude + (destCoord.latitude - _stationHQ.latitude) * 0.65,
        _stationHQ.longitude + (destCoord.longitude - _stationHQ.longitude) * 0.65,
      );
    } else if (order.orderStatus == OrderStatus.assigned) {
      return LatLng(
        _stationHQ.latitude + (destCoord.latitude - _stationHQ.latitude) * 0.25,
        _stationHQ.longitude + (destCoord.longitude - _stationHQ.longitude) * 0.25,
      );
    }
    return _stationHQ;
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _resetView() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _stationHQ, zoom: 14.5),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant LiveFleetGpsMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOrder != null && widget.selectedOrder != oldWidget.selectedOrder) {
      final dest = _getOrderCoord(widget.selectedOrder!, 0);
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 15.5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final activeOrders = widget.orders.where((o) => !o.isWalkIn).toList();

    // Build real Google Map Markers
    final Set<Marker> markers = {};
    final Set<Polyline> polylines = {};

    // 1. Water Station Headquarters Pin
    markers.add(
      Marker(
        markerId: const MarkerId('station_hq'),
        position: _stationHQ,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(
          title: '💧 JJAASS Water Market HQ',
          snippet: 'Station Central Hub • Ligao City, Albay',
        ),
      ),
    );

    // 2. Customer Delivery Pins & Active Riders
    for (int i = 0; i < activeOrders.length; i++) {
      final o = activeOrders[i];
      final isSelected = widget.selectedOrder?.id == o.id;
      final destCoord = _getOrderCoord(o, i);
      final driverCoord = _getDriverCoord(o, destCoord);
      final isActive = o.orderStatus == OrderStatus.onDelivery || o.orderStatus == OrderStatus.assigned;
      final isCompleted = o.orderStatus == OrderStatus.completed;

      // Customer Marker
      final double markerHue = isSelected
          ? BitmapDescriptor.hueMagenta
          : (isCompleted
              ? BitmapDescriptor.hueGreen
              : (isActive ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueOrange));

      markers.add(
        Marker(
          markerId: MarkerId('customer_${o.id}'),
          position: destCoord,
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          infoWindow: InfoWindow(
            title: '${o.id} • ${o.customerName}',
            snippet: '${o.deliveryAddress} (${o.orderStatus.displayName})',
            onTap: () => widget.onSelectOrder?.call(o),
          ),
          onTap: () => widget.onSelectOrder?.call(o),
        ),
      );

      // Rider Marker (if active delivery)
      if (isActive && o.driverName != null) {
        markers.add(
          Marker(
            markerId: MarkerId('driver_${o.id}'),
            position: driverCoord,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: '🛵 Rider: ${o.driverName}',
              snippet: 'Dispatched for ${o.id} • Speed ~28 km/h',
            ),
            onTap: () => widget.onSelectOrder?.call(o),
          ),
        );

        // Route Polyline from Station to Driver to Customer
        polylines.add(
          Polyline(
            polylineId: PolylineId('route_${o.id}'),
            points: [_stationHQ, driverCoord, destCoord],
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF38BDF8),
            width: isSelected ? 5 : 3,
            patterns: [PatternItem.dash(15), PatternItem.gap(8)],
          ),
        );
      }
    }

    return Container(
      height: 420,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Authentic Google Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _stationHQ,
                zoom: 14.5,
              ),
              mapType: widget.satelliteMode ? MapType.hybrid : MapType.normal,
              markers: markers,
              polylines: polylines,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),

          // Map Header Legend & Badge
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Google Maps Live Fleet • Ligao City Hub',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${activeOrders.where((o) => o.orderStatus == OrderStatus.onDelivery || o.orderStatus == OrderStatus.assigned).length} Active Dispatches',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Control Floating Action Buttons (Zoom / Center)
          Positioned(
            top: 14,
            right: 14,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  isDark: isDark,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),
                _buildMapButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  isDark: isDark,
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 6),
                _buildMapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Reset to Station Hub',
                  isDark: isDark,
                  onTap: _resetView,
                ),
              ],
            ),
          ),

          // Selected Delivery Telemetry Card (Bottom Drawer on Map)
          if (widget.selectedOrder != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.94)
                      : Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.selectedOrder!.id,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.selectedOrder!.orderStatus.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.selectedOrder!.orderStatus.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: widget.selectedOrder!.orderStatus.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'To: ${widget.selectedOrder!.customerName} • ${widget.selectedOrder!.deliveryAddress}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed_rounded, size: 14, color: Colors.cyan),
                            const SizedBox(width: 4),
                            Text(
                              '28 km/h',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ETA: ~8 mins (${widget.selectedOrder!.distance})',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}
