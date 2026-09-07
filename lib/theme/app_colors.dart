import 'package:flutter/material.dart';

/// Semantic color tokens for light and dark Stikk surfaces.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentDim,
    required this.accentSoft,
    required this.accentOn,
    required this.border,
    required this.navBar,
    required this.navInactive,
    required this.shadow,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentDim;
  final Color accentSoft;
  final Color accentOn;
  final Color border;
  final Color navBar;
  final Color navInactive;
  final Color shadow;
  final Color success;

  static const light = AppColors(
    background: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF1F4),
    textPrimary: Color(0xFF111318),
    textSecondary: Color(0xFF5C6370),
    textTertiary: Color(0xFF9AA1AD),
    accent: Color(0xFF00C48C),
    accentDim: Color(0xFF00A877),
    accentSoft: Color(0xFFD7F7EB),
    accentOn: Color(0xFFFFFFFF),
    border: Color(0xFFE4E7EC),
    navBar: Color(0xFFFFFFFF),
    navInactive: Color(0xFF8B929E),
    shadow: Color(0x1A111318),
    success: Color(0xFF12B76A),
  );

  static const dark = AppColors(
    background: Color(0xFF0B0E12),
    surface: Color(0xFF151A21),
    surfaceMuted: Color(0xFF1C232C),
    textPrimary: Color(0xFFF4F6F8),
    textSecondary: Color(0xFFA8B0BD),
    textTertiary: Color(0xFF6B7380),
    accent: Color(0xFF1EE0A0),
    accentDim: Color(0xFF12C48C),
    accentSoft: Color(0xFF16382C),
    accentOn: Color(0xFF052016),
    border: Color(0xFF2A323C),
    navBar: Color(0xFF12171D),
    navInactive: Color(0xFF7A8492),
    shadow: Color(0x66000000),
    success: Color(0xFF32D583),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentDim,
    Color? accentSoft,
    Color? accentOn,
    Color? border,
    Color? navBar,
    Color? navInactive,
    Color? shadow,
    Color? success,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentDim: accentDim ?? this.accentDim,
      accentSoft: accentSoft ?? this.accentSoft,
      accentOn: accentOn ?? this.accentOn,
      border: border ?? this.border,
      navBar: navBar ?? this.navBar,
      navInactive: navInactive ?? this.navInactive,
      shadow: shadow ?? this.shadow,
      success: success ?? this.success,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentOn: Color.lerp(accentOn, other.accentOn, t)!,
      border: Color.lerp(border, other.border, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.of(this);
}
