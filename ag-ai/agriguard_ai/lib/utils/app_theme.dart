import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Brand palette ──────────────────────────────────────────────────────────────
abstract final class AgriColors {
  static const deepGreen   = Color(0xFF0D3320);
  static const forestGreen = Color(0xFF1B4332);
  static const leafGreen   = Color(0xFF2D6A4F);
  static const meadowGreen = Color(0xFF40916C);
  static const mintGreen   = Color(0xFF52B788);

  static const black       = Color(0xFF000000);
  static const darkSurface = Color(0xFF0F0F0F);
  static const darkCard    = Color(0xFF1A1A1A);
  static const darkDivider = Color(0xFF2A2A2A);
  static const white       = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF5F5F5);
  static const lightCard   = Color(0xFFFFFFFF);

  static const gold    = Color(0xFFD4A017);
  static const danger  = Color(0xFFE53935);
  static const sky     = Color(0xFF1E88E5);

  // Legacy aliases
  static const soilBrown = Color(0xFF212121);
  static const wheatGold = gold;
  static const cream     = lightSurface;
  static const skyBlue   = sky;
  static const dangerRed = danger;
}

// ── Gradient helpers ───────────────────────────────────────────────────────────
const lightHeaderGradient = LinearGradient(
  colors: [AgriColors.forestGreen, AgriColors.leafGreen],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const darkHeaderGradient = LinearGradient(
  colors: [AgriColors.forestGreen, AgriColors.deepGreen],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const accentGradient = LinearGradient(
  colors: [AgriColors.forestGreen, AgriColors.leafGreen],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// ── Light theme — white background, green AppBar, green cards ──────────────────
ThemeData buildLightTheme() {
  const scaffold = AgriColors.lightSurface; // near-white
  const cardBg   = AgriColors.forestGreen;  // green cards
  const onCard   = AgriColors.white;        // white text on cards

  final cs = ColorScheme(
    brightness: Brightness.light,
    primary: AgriColors.forestGreen,
    onPrimary: AgriColors.white,
    primaryContainer: AgriColors.leafGreen,
    onPrimaryContainer: AgriColors.white,
    secondary: AgriColors.leafGreen,
    onSecondary: AgriColors.white,
    secondaryContainer: const Color(0xFFD8F3DC),
    onSecondaryContainer: AgriColors.deepGreen,
    tertiary: AgriColors.gold,
    onTertiary: AgriColors.white,
    surface: scaffold,
    onSurface: AgriColors.black,
    surfaceContainerHighest: AgriColors.white,
    onSurfaceVariant: Colors.grey.shade600,
    error: AgriColors.danger,
    onError: AgriColors.white,
    outline: Colors.grey.shade300,
    shadow: Colors.black12,
    scrim: Colors.black26,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: cs,
    scaffoldBackgroundColor: scaffold,

    appBarTheme: const AppBarTheme(
      backgroundColor: AgriColors.forestGreen,
      foregroundColor: AgriColors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: AgriColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      iconTheme: IconThemeData(color: AgriColors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AgriColors.forestGreen,
        foregroundColor: AgriColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AgriColors.forestGreen,
        side: const BorderSide(color: AgriColors.forestGreen, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AgriColors.forestGreen),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AgriColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriColors.forestGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriColors.danger, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade600),
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIconColor: Colors.grey.shade500,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Green cards with white text
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colors.white10),
      ),
      margin: EdgeInsets.zero,
    ),

    // ListTile inside cards → white text/icons
    listTileTheme: const ListTileThemeData(
      textColor: onCard,
      iconColor: onCard,
    ),

    dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
    iconTheme: const IconThemeData(color: AgriColors.black),

    // Scaffold-level text is dark (readable on white background)
    textTheme: _textTheme(AgriColors.black),

    chipTheme: ChipThemeData(
      backgroundColor: AgriColors.white,
      selectedColor: AgriColors.forestGreen,
      labelStyle: TextStyle(color: Colors.grey.shade800),
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AgriColors.white,
      selectedItemColor: AgriColors.forestGreen,
      unselectedItemColor: Colors.grey.shade400,
      type: BottomNavigationBarType.fixed,
      elevation: 4,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AgriColors.forestGreen : Colors.grey.shade400),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AgriColors.forestGreen.withValues(alpha: 0.4)
              : Colors.grey.shade300),
    ),
  );
}

// ── Dark theme — dark background, green cards ──────────────────────────────────
ThemeData buildDarkTheme() {
  const scaffold = AgriColors.darkSurface;
  const cardBg   = AgriColors.forestGreen;
  const onCard   = AgriColors.white;

  final cs = ColorScheme(
    brightness: Brightness.dark,
    primary: AgriColors.mintGreen,
    onPrimary: AgriColors.forestGreen,
    primaryContainer: AgriColors.leafGreen,
    onPrimaryContainer: AgriColors.white,
    secondary: AgriColors.mintGreen,
    onSecondary: AgriColors.forestGreen,
    secondaryContainer: AgriColors.deepGreen,
    onSecondaryContainer: AgriColors.white,
    tertiary: AgriColors.gold,
    onTertiary: AgriColors.white,
    surface: scaffold,
    onSurface: AgriColors.white,
    surfaceContainerHighest: AgriColors.darkCard,
    onSurfaceVariant: Colors.grey.shade400,
    error: AgriColors.danger,
    onError: AgriColors.white,
    outline: AgriColors.darkDivider,
    shadow: Colors.black,
    scrim: Colors.black54,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: cs,
    scaffoldBackgroundColor: scaffold,

    appBarTheme: AppBarTheme(
      backgroundColor: AgriColors.darkCard,
      foregroundColor: AgriColors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      titleTextStyle: const TextStyle(
        color: AgriColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      iconTheme: const IconThemeData(color: AgriColors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AgriColors.mintGreen,
        foregroundColor: AgriColors.forestGreen,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AgriColors.mintGreen,
        side: const BorderSide(color: AgriColors.leafGreen, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AgriColors.mintGreen),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AgriColors.darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriColors.darkDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriColors.darkDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriColors.mintGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriColors.danger, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade400),
      hintStyle: TextStyle(color: Colors.grey.shade600),
      prefixIconColor: Colors.grey.shade400,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AgriColors.leafGreen.withValues(alpha: 0.3)),
      ),
      margin: EdgeInsets.zero,
    ),

    listTileTheme: const ListTileThemeData(
      textColor: onCard,
      iconColor: onCard,
    ),

    dividerTheme: const DividerThemeData(color: AgriColors.darkDivider, thickness: 1),
    iconTheme: const IconThemeData(color: AgriColors.white),
    textTheme: _textTheme(AgriColors.white),

    chipTheme: ChipThemeData(
      backgroundColor: AgriColors.darkCard,
      selectedColor: AgriColors.leafGreen,
      labelStyle: const TextStyle(color: AgriColors.white),
      side: const BorderSide(color: AgriColors.darkDivider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AgriColors.darkCard,
      selectedItemColor: AgriColors.mintGreen,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AgriColors.mintGreen : Colors.white54),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AgriColors.mintGreen.withValues(alpha: 0.4)
              : Colors.white12),
    ),
  );
}

// ── Legacy alias ───────────────────────────────────────────────────────────────
ThemeData buildAgriTheme() => buildLightTheme();

// ── Typography ─────────────────────────────────────────────────────────────────
TextTheme _textTheme(Color base) => TextTheme(
      displayLarge:   TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: base, letterSpacing: -1),
      displayMedium:  TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: base, letterSpacing: -0.5),
      headlineLarge:  TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: base),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: base),
      titleLarge:     TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: base),
      titleMedium:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: base),
      titleSmall:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: base),
      bodyLarge:      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: base),
      bodyMedium:     TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: base),
      bodySmall:      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: base.withValues(alpha: 0.7)),
      labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: base, letterSpacing: 0.3),
      labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: base.withValues(alpha: 0.6)),
    );

// ── GradientHeader widget ──────────────────────────────────────────────────────
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24.0,
  });

  final Widget child;
  final Gradient? gradient;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? (isDark ? darkHeaderGradient : lightHeaderGradient),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}
