import 'package:flutter/material.dart';

class UVAColors {
  static const Color primaryOrange = Color(0xFFE57200);
  static const Color primaryNavy = Color(0xFF232F3E);
  static const Color lightOrange = Color(0xFFFF8C42);
  static const Color darkNavy = Color(0xFF1A252F);
  
  // Glass morphism colors
  static const Color glassBg = Color(0x20FFFFFF);
  static const Color glassStroke = Color(0x30FFFFFF);
  
  // Success/Error colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Neutral colors
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);
}

class UVASpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

class UVABorderRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 9999.0;
}

class UVAAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeOutQuart;
}

class UVACardStyles {
  static BoxDecoration glassMorphism({
    Color? backgroundColor,
    double borderRadius = UVABorderRadius.lg,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? UVAColors.glassBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(
        color: UVAColors.glassStroke,
        width: 1,
      ) : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  static BoxDecoration elevatedCard({
    Color? backgroundColor,
    double borderRadius = UVABorderRadius.lg,
    double elevation = 8,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: elevation * 2,
          offset: Offset(0, elevation / 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: elevation,
          offset: Offset(0, elevation / 4),
        ),
      ],
    );
  }
  
  static InputDecoration modernTextField({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool filled = true,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UVABorderRadius.md),
        borderSide: BorderSide(color: UVAColors.grey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UVABorderRadius.md),
        borderSide: BorderSide(color: UVAColors.grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UVABorderRadius.md),
        borderSide: BorderSide(color: UVAColors.primaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UVABorderRadius.md),
        borderSide: BorderSide(color: UVAColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: UVASpacing.md,
        vertical: UVASpacing.md,
      ),
    );
  }
  
  static ButtonStyle primaryButton({
    double borderRadius = UVABorderRadius.md,
    EdgeInsetsGeometry? padding,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: UVAColors.primaryOrange,
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: UVAColors.primaryOrange.withValues(alpha: 0.3),
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: UVASpacing.lg,
        vertical: UVASpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
  
  static ButtonStyle secondaryButton({
    double borderRadius = UVABorderRadius.md,
    EdgeInsetsGeometry? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: UVAColors.glassStroke),
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: UVASpacing.lg,
        vertical: UVASpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// Custom gradient backgrounds
class UVAGradients {
  static const LinearGradient primaryBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      UVAColors.primaryNavy,
      UVAColors.darkNavy,
    ],
    stops: [0.0, 1.0],
  );
  
  static const LinearGradient orangeAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      UVAColors.primaryOrange,
      UVAColors.lightOrange,
    ],
    stops: [0.0, 1.0],
  );
  
  static const LinearGradient glassOverlay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x15FFFFFF),
      Color(0x05FFFFFF),
    ],
    stops: [0.0, 1.0],
  );
}