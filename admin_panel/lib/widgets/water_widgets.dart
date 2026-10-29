import 'dart:math';
import 'package:flutter/material.dart';
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

/// Live Interactive Fleet GPS Route Monitor with Real-Time Telemetry & Vector Roads
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

class _LiveFleetGpsMapWidgetState extends State<LiveFleetGpsMapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale * 1.25).clamp(0.7, 3.0);
      _transformController.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale / 1.25).clamp(0.7, 3.0);
      _transformController.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _resetView() {
    setState(() {
      _currentScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final mapBgColor = widget.satelliteMode
        ? (isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B))
        : (isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9));

    return Container(
      height: 380,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: mapBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Animated Canvas Map with interactive pan and zoom
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.7,
              maxScale: 3.0,
              boundaryMargin: const EdgeInsets.all(100),
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(1000, 500),
                    painter: _FleetLiveMapCanvasPainter(
                      orders: widget.orders,
                      drivers: widget.drivers,
                      selectedOrder: widget.selectedOrder,
                      animProgress: _animController.value,
                      isDark: isDark,
                      satelliteMode: widget.satelliteMode,
                    ),
                  );
                },
              ),
            ),
          ),

          // Map Header Legend & Badge
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.88) : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
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
                    'GPS Live Feed • Ligao City Grid',
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
                      '${widget.orders.where((o) => o.orderStatus == OrderStatus.onDelivery || o.orderStatus == OrderStatus.assigned).length} Active Vehicles',
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
                  icon: Icons.center_focus_strong_rounded,
                  tooltip: 'Reset to Hub',
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
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.94) : Colors.white.withValues(alpha: 0.96),
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
                      child: Icon(
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
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
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

class _FleetLiveMapCanvasPainter extends CustomPainter {
  final List<OrderModel> orders;
  final List<UserModel> drivers;
  final OrderModel? selectedOrder;
  final double animProgress;
  final bool isDark;
  final bool satelliteMode;

  _FleetLiveMapCanvasPainter({
    required this.orders,
    required this.drivers,
    this.selectedOrder,
    required this.animProgress,
    required this.isDark,
    required this.satelliteMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Central Station Hub Coordinate (Center-Left of map)
    final Offset hubCoord = Offset(width * 0.22, height * 0.52);

    // 1. Draw Map Grid Terrain / Land Background
    final landPaint = Paint()
      ..color = satelliteMode
          ? (isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B))
          : (isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), landPaint);

    // 2. Draw Vector Roads & Avenues
    final roadColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final mainRoadColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final roadPaint = Paint()
      ..color = roadColor
      ..strokeWidth = 14.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mainRoadPaint = Paint()
      ..color = mainRoadColor
      ..strokeWidth = 22.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadLinePaint = Paint()
      ..color = (isDark ? Colors.white12 : Colors.white)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Main East-West Highway
    final highwayPath = Path()
      ..moveTo(0, height * 0.52)
      ..lineTo(width, height * 0.52);
    canvas.drawPath(highwayPath, mainRoadPaint);
    canvas.drawPath(highwayPath, roadLinePaint);

    // Secondary Cross Avenues
    final List<Path> roads = [
      Path()..moveTo(width * 0.22, 0)..lineTo(width * 0.22, height),
      Path()..moveTo(width * 0.45, 0)..lineTo(width * 0.45, height),
      Path()..moveTo(width * 0.70, 0)..lineTo(width * 0.70, height),
      Path()..moveTo(width * 0.88, 0)..lineTo(width * 0.88, height),
      Path()..moveTo(0, height * 0.24)..lineTo(width, height * 0.24),
      Path()..moveTo(0, height * 0.78)..lineTo(width, height * 0.78),
      // Diagonal Connector
      Path()..moveTo(width * 0.22, height * 0.52)..lineTo(width * 0.45, height * 0.24),
      Path()..moveTo(width * 0.45, height * 0.52)..lineTo(width * 0.70, height * 0.78),
      Path()..moveTo(width * 0.70, height * 0.52)..lineTo(width * 0.88, height * 0.24),
    ];

    for (var r in roads) {
      canvas.drawPath(r, roadPaint);
      canvas.drawPath(r, roadLinePaint);
    }

    // 3. Draw City Neighborhood Blocks & Landmarks
    final blockPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFEDE9FE).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final blockBorder = Paint()
      ..color = isDark ? Colors.white10 : const Color(0xFFDDD6FE).withValues(alpha: 0.7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final List<Rect> blocks = [
      Rect.fromLTWH(width * 0.05, height * 0.05, width * 0.14, height * 0.16),
      Rect.fromLTWH(width * 0.25, height * 0.05, width * 0.17, height * 0.16),
      Rect.fromLTWH(width * 0.48, height * 0.05, width * 0.19, height * 0.16),
      Rect.fromLTWH(width * 0.73, height * 0.05, width * 0.12, height * 0.16),
      Rect.fromLTWH(width * 0.05, height * 0.58, width * 0.14, height * 0.17),
      Rect.fromLTWH(width * 0.25, height * 0.58, width * 0.17, height * 0.17),
      Rect.fromLTWH(width * 0.48, height * 0.58, width * 0.19, height * 0.17),
      Rect.fromLTWH(width * 0.73, height * 0.58, width * 0.12, height * 0.17),
    ];

    for (var b in blocks) {
      final RRect rr = RRect.fromRectAndRadius(b, const Radius.circular(8));
      canvas.drawRRect(rr, blockPaint);
      canvas.drawRRect(rr, blockBorder);
    }

    // 4. Plot Delivery Destination Pins & Real-Time Driver Routes
    // Generate deterministic coordinate offsets across the city map for each order
    final displayOrders = orders.take(8).toList();

    for (int i = 0; i < displayOrders.length; i++) {
      final o = displayOrders[i];
      final isSelected = selectedOrder?.id == o.id;
      final bool isActive = o.orderStatus == OrderStatus.onDelivery || o.orderStatus == OrderStatus.assigned;
      final bool isCompleted = o.orderStatus == OrderStatus.completed;

      // Deterministic position on grid
      final hash = o.deliveryAddress.hashCode.abs() + i * 37;
      final double destX = width * (0.35 + ((hash % 55) / 100.0));
      final double destY = height * (0.15 + (((hash >> 3) % 70) / 100.0));
      final Offset destCoord = Offset(destX, destY);

      // Interpolate driver vehicle location between Hub and Destination
      final double driverCycleProgress = (animProgress + (i * 0.25)) % 1.0;
      final double transitProgress = isActive ? driverCycleProgress : (isCompleted ? 1.0 : 0.0);

      final Offset driverPos = Offset(
        hubCoord.dx + (destCoord.dx - hubCoord.dx) * transitProgress,
        hubCoord.dy + (destCoord.dy - hubCoord.dy) * transitProgress,
      );

      // Draw Glowing Route Polyline from Hub to Destination
      final routeColor = isSelected
          ? const Color(0xFF0284C7)
          : (isActive ? const Color(0xFF38BDF8) : (isCompleted ? const Color(0xFF10B981) : Colors.amber));

      final routePaint = Paint()
        ..color = routeColor.withValues(alpha: isSelected ? 0.9 : 0.6)
        ..strokeWidth = isSelected ? 4.0 : 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(hubCoord, destCoord, routePaint);

      // Draw Animated Dash Pulse flowing towards destination
      if (isActive) {
        final dashPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = isSelected ? 5.0 : 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final double pulseX = hubCoord.dx + (destCoord.dx - hubCoord.dx) * driverCycleProgress;
        final double pulseY = hubCoord.dy + (destCoord.dy - hubCoord.dy) * driverCycleProgress;
        canvas.drawCircle(Offset(pulseX, pulseY), 4, dashPaint);
      }

      // Draw Customer Delivery Destination Pin
      final pinPaint = Paint()
        ..color = isSelected ? const Color(0xFFF43F5E) : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF6366F1))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(destCoord, isSelected ? 9 : 7, pinPaint);
      canvas.drawCircle(
        destCoord,
        isSelected ? 14 : 11,
        Paint()
          ..color = (isSelected ? const Color(0xFFF43F5E) : const Color(0xFF6366F1)).withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );

      // Destination Label
      final destPainter = TextPainter(
        text: TextSpan(
          text: o.customerName.split(' ').first,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            backgroundColor: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      destPainter.paint(canvas, Offset(destCoord.dx - destPainter.width / 2, destCoord.dy + 12));

      // Draw Animated Moving Driver Vehicle Icon
      if (isActive) {
        final vehiclePaint = Paint()
          ..color = const Color(0xFF0284C7)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(driverPos, isSelected ? 12 : 9, vehiclePaint);
        canvas.drawCircle(
          driverPos,
          isSelected ? 18 : 14,
          Paint()
            ..color = const Color(0xFF0284C7).withValues(alpha: 0.3)
            ..style = PaintingStyle.fill,
        );

        // Driver Name Tag
        final driverLabel = o.driverName != null ? o.driverName!.split(' ').first : 'Rider';
        final driverPainter = TextPainter(
          text: TextSpan(
            text: '🏍️ $driverLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              backgroundColor: Color(0xFF0284C7),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        driverPainter.paint(canvas, Offset(driverPos.dx - driverPainter.width / 2, driverPos.dy - 16));
      }
    }

    // 5. Draw Water Refilling Station Central Hub Beacon
    // Pulsing radar ripple circles
    final rippleRadius = 14 + (animProgress * 22);
    final ripplePaint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: (1.0 - animProgress).clamp(0.0, 1.0) * 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(hubCoord, rippleRadius, ripplePaint);

    // Hub Solid Pin
    final hubPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(hubCoord, 14, hubPaint);

    final hubInner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(hubCoord, 6, hubInner);

    // Hub Text Label
    final hubTextPainter = TextPainter(
      text: const TextSpan(
        text: '💧 JJAASS Central Hub',
        style: TextStyle(
          color: Color(0xFF0284C7),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hubTextPainter.paint(canvas, Offset(hubCoord.dx - hubTextPainter.width / 2, hubCoord.dy + 18));
  }

  @override
  bool shouldRepaint(covariant _FleetLiveMapCanvasPainter oldDelegate) => true;
}
