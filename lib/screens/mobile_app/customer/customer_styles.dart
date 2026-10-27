import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// ============================================================================
/// CUSTOMER APP DESIGN SYSTEM & CSS-EQUIVALENT STYLES
/// ============================================================================

/// Palette of curated colors specific to Customer Portal & Mobile features
class CustomerColors {
  // Brand
  static const Color primary = AppTheme.primaryColor; // 0xFF0284C7
  static const Color secondary = AppTheme.secondaryColor; // 0xFF38BDF8
  static const Color accent = AppTheme.accentColor; // 0xFF00B4D8

  // Neutral / Layouts
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFF334155);

  // Typography
  static const Color textMain = Color(0xFF0F172A);
  static const Color textHeading = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSubtle = Color(0xFF94A3B8);

  // Status & Actions
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF8B5CF6);

  // GCash Integration
  static const Color gcashBlue = Color(0xFF007DFE);
  static const Color gcashDarkBlue = Color(0xFF0056B3);
}

/// Spacing, radius and dimensional tokens for Customer UI
class CustomerDimensions {
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

/// Gradients used for customer cards, banners, and buttons
class CustomerGradients {
  static const LinearGradient gcashBanner = LinearGradient(
    colors: [CustomerColors.gcashBlue, CustomerColors.gcashDarkBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryButton = LinearGradient(
    colors: [CustomerColors.primary, CustomerColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient loyaltyHero = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleCard = LinearGradient(
    colors: [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Box shadow presets
class CustomerShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> gcash = [
    BoxShadow(
      color: CustomerColors.gcashBlue.withValues(alpha: 0.25),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Pre-built BoxDecoration definitions (CSS style classes)
class CustomerDecorations {
  /// Standard Container Card (CSS: .customer-card)
  static BoxDecoration card({
    bool isDark = false,
    Color? borderColor,
    Color? backgroundColor,
    double borderRadius = CustomerDimensions.radiusLarge,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? (isDark ? CustomerColors.surfaceDark : Colors.white),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? (isDark ? CustomerColors.borderDark : CustomerColors.border),
        width: 1.0,
      ),
      boxShadow: CustomerShadows.soft,
    );
  }

  /// GCash Callout Banner (CSS: .gcash-banner)
  static BoxDecoration gcashBanner = BoxDecoration(
    gradient: CustomerGradients.gcashBanner,
    borderRadius: BorderRadius.circular(CustomerDimensions.radiusMedium + 2),
    boxShadow: CustomerShadows.gcash,
  );

  /// Search Bar in Desktop Header (CSS: .search-input-box)
  static BoxDecoration searchBar({bool isDark = false}) {
    return BoxDecoration(
      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(CustomerDimensions.radiusSmall),
    );
  }

  /// Status Badge / Pill (CSS: .badge-pill)
  static BoxDecoration statusBadge(Color color, {bool isDark = false}) {
    return BoxDecoration(
      color: color.withValues(alpha: isDark ? 0.2 : 0.1),
      borderRadius: BorderRadius.circular(CustomerDimensions.radiusPill),
      border: Border.all(
        color: color.withValues(alpha: isDark ? 0.4 : 0.25),
        width: 1,
      ),
    );
  }

  /// Chat Bubble - AquaBot AI (CSS: .chat-bubble-bot)
  static BoxDecoration botChatBubble({bool isDark = false}) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      border: Border.all(
        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        width: 1,
      ),
    );
  }

  /// Chat Bubble - Customer (CSS: .chat-bubble-user)
  static BoxDecoration userChatBubble = const BoxDecoration(
    gradient: CustomerGradients.primaryButton,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(4),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    ),
  );

  /// Input Field Decoration (CSS: .customer-input)
  static InputDecoration input({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDark = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
        fontSize: 13,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? CustomerColors.surfaceDark : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CustomerDimensions.radiusMedium),
        borderSide: BorderSide(
          color: isDark ? CustomerColors.borderDark : CustomerColors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CustomerDimensions.radiusMedium),
        borderSide: BorderSide(
          color: isDark ? CustomerColors.borderDark : CustomerColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CustomerDimensions.radiusMedium),
        borderSide: const BorderSide(
          color: CustomerColors.primary,
          width: 1.5,
        ),
      ),
    );
  }
}

/// Typography and text styles for the Customer UI
class CustomerTextStyles {
  static const TextStyle pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: CustomerColors.textHeading,
    letterSpacing: -0.2,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: CustomerColors.textHeading,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: CustomerColors.textHeading,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: CustomerColors.textMain,
  );

  static const TextStyle statLabel = TextStyle(
    color: CustomerColors.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: CustomerColors.textHeading,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 12,
    color: CustomerColors.textMuted,
  );

  static const TextStyle price = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: CustomerColors.primary,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );
}

/// ============================================================================
/// REUSABLE CUSTOMER UI COMPONENTS (Styled Widgets)
/// ============================================================================

/// Reusable styled card container
class CustomerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool isDark;
  final VoidCallback? onTap;

  const CustomerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CustomerDimensions.paddingLarge),
    this.margin,
    this.isDark = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: CustomerDecorations.card(isDark: isDark),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CustomerDimensions.radiusLarge),
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// Metric statistic card
class CustomerStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const CustomerStatCard({
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
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: CustomerDecorations.card(isDark: isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: CustomerTextStyles.statLabel.copyWith(
                      color: isDark ? const Color(0xFF94A3B8) : CustomerColors.textMuted,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: CustomerTextStyles.statValue.copyWith(
                      color: isDark ? Colors.white : CustomerColors.textMain,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : CustomerColors.textSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
        ],
      ),
    );
  }
}

/// Pill status badge (e.g., Pending, Processing, Delivering, Completed)
class CustomerStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const CustomerStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: CustomerDecorations.statusBadge(color, isDark: isDark),
      child: Text(
        label,
        style: CustomerTextStyles.badge.copyWith(color: color),
      ),
    );
  }
}
