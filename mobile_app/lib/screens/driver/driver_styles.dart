import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// ============================================================================
/// DRIVER APP DESIGN SYSTEM & CSS-EQUIVALENT STYLES
/// ============================================================================

/// Palette of curated colors matched to the JJAASS Water Market Logo
class DriverColors {
  // Brand
  static const Color navy = AppTheme.navyColor; // 0xFF0F2B5C
  static const Color primary = AppTheme.primaryColor; // 0xFF1D63B8
  static const Color secondary = AppTheme.secondaryColor; // 0xFF4788D7
  static const Color accent = AppTheme.accentColor; // 0xFF0284C7

  // Neutral / High-Readability Layouts
  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;
  static const Color surfaceDark = Colors.white;
  static const Color border = Color(0xFFCBD5E1);
  static const Color borderDark = Color(0xFFCBD5E1);

  // Typography
  static const Color textMain = Color(0xFF0F2B5C);
  static const Color textHeading = Color(0xFF0F2B5C);
  static const Color textMuted = Color(0xFF334155);
  static const Color textSubtle = Color(0xFF475569);

  // Driver Duty & Navigation
  static const Color onlinePrimary = Color(0xFF0F2B5C);
  static const Color onlineSecondary = Color(0xFF1D63B8);
  static const Color offlinePrimary = Color(0xFFDC2626);
  static const Color offlineSecondary = Color(0xFFB91C1C);

  // Status & Performance
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color purple = Color(0xFF7C3AED);
}

/// Spacing, radius and dimensional tokens for Driver UI
class DriverDimensions {
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusPill = 999.0;

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 20.0;
  static const double paddingXLarge = 24.0;

  static const double sidebarWidth = 260.0;
}

/// Gradients used for Driver duty banners, earnings heroes, and action cards
class DriverGradients {
  static const LinearGradient onlineDuty = LinearGradient(
    colors: [DriverColors.onlinePrimary, DriverColors.onlineSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient offlineDuty = LinearGradient(
    colors: [DriverColors.offlinePrimary, DriverColors.offlineSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient earningsHero = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryButton = LinearGradient(
    colors: [DriverColors.navy, DriverColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Box shadow presets
class DriverShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: AppTheme.navyColor.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> duty(bool isOnline) => [
        BoxShadow(
          color: (isOnline ? DriverColors.onlinePrimary : DriverColors.offlinePrimary)
              .withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: AppTheme.navyColor.withValues(alpha: 0.1),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Pre-built BoxDecoration definitions (CSS style classes)
class DriverDecorations {
  /// Standard Container Card (CSS: .driver-card)
  static BoxDecoration card({
    bool isDark = false,
    Color? borderColor,
    Color? backgroundColor,
    double borderRadius = DriverDimensions.radiusLarge,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? DriverColors.border,
        width: 1.2,
      ),
      boxShadow: DriverShadows.soft,
    );
  }

  /// Duty Status Banner (CSS: .duty-banner)
  static BoxDecoration dutyBanner(bool isOnline) {
    return BoxDecoration(
      gradient: isOnline ? DriverGradients.onlineDuty : DriverGradients.offlineDuty,
      borderRadius: BorderRadius.circular(DriverDimensions.radiusLarge),
      boxShadow: DriverShadows.duty(isOnline),
    );
  }

  /// Search Bar in Desktop Header (CSS: .driver-search-box)
  static BoxDecoration searchBar({bool isDark = false}) {
    return BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(DriverDimensions.radiusSmall),
      border: Border.all(color: DriverColors.border),
    );
  }

  /// Status Badge / Pill (CSS: .driver-badge-pill)
  static BoxDecoration statusBadge(Color color, {bool isDark = false}) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(DriverDimensions.radiusPill),
      border: Border.all(
        color: color.withValues(alpha: 0.35),
        width: 1,
      ),
    );
  }

  /// Chat Bubble - AquaBot AI Dispatch (CSS: .driver-chat-bot)
  static BoxDecoration botChatBubble({bool isDark = false}) {
    return BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      border: Border.all(
        color: DriverColors.secondary.withValues(alpha: 0.35),
        width: 1,
      ),
    );
  }

  /// Chat Bubble - Driver (CSS: .driver-chat-user)
  static BoxDecoration driverChatBubble = const BoxDecoration(
    gradient: DriverGradients.primaryButton,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(4),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    ),
  );

  /// Input Field Decoration (CSS: .driver-input)
  static InputDecoration input({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDark = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: DriverColors.textSubtle,
        fontSize: 13.5,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriverDimensions.radiusMedium),
        borderSide: const BorderSide(
          color: DriverColors.border,
          width: 1.2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriverDimensions.radiusMedium),
        borderSide: const BorderSide(
          color: DriverColors.border,
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DriverDimensions.radiusMedium),
        borderSide: const BorderSide(
          color: DriverColors.navy,
          width: 2.0,
        ),
      ),
    );
  }
}

/// Typography and text styles for the Driver UI
class DriverTextStyles {
  static const TextStyle pageTitle = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w900,
    color: DriverColors.textHeading,
    letterSpacing: -0.2,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w800,
    color: DriverColors.textHeading,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: DriverColors.textHeading,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: DriverColors.textMain,
  );

  static const TextStyle statLabel = TextStyle(
    color: DriverColors.textMuted,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle dutyStatusTitle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle dutyStatusSubtitle = TextStyle(
    color: Colors.white70,
    fontSize: 12.5,
  );

  static const TextStyle earningHighlight = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: DriverColors.success,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
  );
}

/// ============================================================================
/// REUSABLE DRIVER UI COMPONENTS (Styled Widgets)
/// ============================================================================

/// Reusable styled card container
class DriverCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool isDark;
  final VoidCallback? onTap;

  const DriverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DriverDimensions.paddingLarge),
    this.margin,
    this.isDark = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: DriverDecorations.card(isDark: isDark),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverDimensions.radiusLarge),
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// Metric statistic card for Driver dashboard
class DriverStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const DriverStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DriverDimensions.paddingLarge),
      decoration: DriverDecorations.card(isDark: isDark),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DriverTextStyles.statLabel),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: DriverTextStyles.statValue,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: DriverColors.textSubtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }
}

/// Status badge pill for Driver UI
class DriverStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const DriverStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: DriverDecorations.statusBadge(color, isDark: isDark),
      child: Text(
        label,
        style: DriverTextStyles.badge.copyWith(color: color),
      ),
    );
  }
}
