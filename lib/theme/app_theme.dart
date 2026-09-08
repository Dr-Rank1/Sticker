import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds Material 3 [ThemeData] for light and dark modes.
///
/// Both themes share the same type scale and component shapes so the
/// UI stays consistent when the OS appearance changes.
class AppTheme {
  AppTheme._();

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  /// Lower bound for system font scaling so compact layouts stay usable.
  static const double minTextScale = 0.85;

  /// Upper bound so large accessibility fonts do not clip chrome.
  static const double maxTextScale = 1.6;

  static TextScaler textScalerOf(BuildContext context) {
    return MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: minTextScale, maxScaleFactor: maxTextScale);
  }

  static double scaled(BuildContext context, double size) {
    return textScalerOf(context).scale(size);
  }

  /// Clamps [MediaQuery.textScalerOf] so Material text styles grow without
  /// overflowing fixed chrome such as the custom bottom bar.
  static Widget appBuilder(BuildContext context, Widget? child) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: textScalerOf(context)),
      child: child ?? const SizedBox.shrink(),
    );
  }

  static ThemeData get light => _build(Brightness.light, AppColors.light);

  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final isDark = brightness == Brightness.dark;
    final textTheme = _textTheme(colors);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.accentOn,
      secondary: colors.accentDim,
      onSecondary: colors.accentOn,
      tertiary: colors.success,
      onTertiary: colors.accentOn,
      error: const Color(0xFFE5484D),
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.border,
      shadow: colors.shadow,
      scrim: Colors.black,
      inverseSurface: isDark ? AppColors.light.surface : AppColors.dark.surface,
      onInverseSurface: isDark
          ? AppColors.light.textPrimary
          : AppColors.dark.textPrimary,
      inversePrimary: colors.accentDim,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.border,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.navBar,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.navBar,
              ),
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: colors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceMuted,
        selectedColor: colors.accentSoft,
        disabledColor: colors.surfaceMuted,
        labelStyle: textTheme.labelLarge!,
        secondaryLabelStyle: textTheme.labelLarge!.copyWith(
          color: colors.accentDim,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.accent,
          foregroundColor: colors.accentOn,
          disabledBackgroundColor: colors.surfaceMuted,
          disabledForegroundColor: colors.textTertiary,
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.accent,
          foregroundColor: colors.accentOn,
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.surface,
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.accentOn,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? colors.surfaceMuted : colors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? colors.textPrimary : colors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.navBar,
        indicatorColor: colors.accentSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.accent : colors.navInactive,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.accent : colors.navInactive,
            size: 24,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        hintStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.surfaceMuted,
      ),
    );
  }

  static TextTheme _textTheme(AppColors colors) {
    final base = GoogleFonts.plusJakartaSansTextTheme();

    TextStyle style(
      TextStyle? source, {
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.25,
      double letterSpacing = -0.3,
    }) {
      return (source ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return base.copyWith(
      displaySmall: style(
        base.displaySmall,
        size: 34,
        weight: FontWeight.w800,
        color: colors.textPrimary,
        letterSpacing: -1.2,
      ),
      headlineMedium: style(
        base.headlineMedium,
        size: 28,
        weight: FontWeight.w800,
        color: colors.textPrimary,
        letterSpacing: -0.8,
      ),
      headlineSmall: style(
        base.headlineSmall,
        size: 22,
        weight: FontWeight.w700,
        color: colors.textPrimary,
        letterSpacing: -0.4,
      ),
      titleLarge: style(
        base.titleLarge,
        size: 18,
        weight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleMedium: style(
        base.titleMedium,
        size: 16,
        weight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: -0.2,
      ),
      titleSmall: style(
        base.titleSmall,
        size: 14,
        weight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: 0,
      ),
      bodyLarge: style(
        base.bodyLarge,
        size: 16,
        weight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodyMedium: style(
        base.bodyMedium,
        size: 14,
        weight: FontWeight.w500,
        color: colors.textSecondary,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodySmall: style(
        base.bodySmall,
        size: 12,
        weight: FontWeight.w500,
        color: colors.textTertiary,
        height: 1.4,
        letterSpacing: 0,
      ),
      labelLarge: style(
        base.labelLarge,
        size: 14,
        weight: FontWeight.w700,
        color: colors.textPrimary,
        letterSpacing: 0,
      ),
      labelMedium: style(
        base.labelMedium,
        size: 12,
        weight: FontWeight.w600,
        color: colors.textSecondary,
        letterSpacing: 0.1,
      ),
      labelSmall: style(
        base.labelSmall,
        size: 11,
        weight: FontWeight.w600,
        color: colors.navInactive,
        letterSpacing: 0.1,
      ),
    );
  }
}
