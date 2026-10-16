import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

abstract final class QubeXCoreTheme {
  /// Platform-correct page transitions: Android zoom (predictive-back
  /// friendly), iOS Cupertino (interactive back-swipe).
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    },
  );

  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: QubeXCoreColors.primaryBlue,
    onPrimary: Colors.white,
    primaryContainer: QubeXCoreColors.primaryBlue,
    onPrimaryContainer: Colors.white,
    secondary: QubeXCoreColors.primaryDark,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE3EEFF),
    onSecondaryContainer: QubeXCoreColors.primaryDarker,
    tertiary: QubeXCoreColors.successGreen,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE3F5E8),
    onTertiaryContainer: QubeXCoreColors.successGreen,
    error: QubeXCoreColors.errorRed,
    onError: Colors.white,
    errorContainer: Color(0xFFFFE8E8),
    onErrorContainer: QubeXCoreColors.errorRed,
    surface: Colors.white,
    onSurface: QubeXCoreColors.qubexBlack,
    surfaceContainerHighest: QubeXCoreColors.qubexOffWhite,
    surfaceContainerHigh: Color(0xFFF3F3F3),
    surfaceContainerLow: Color(0xFFF7F7F7),
    surfaceContainerLowest: Colors.white,
    surfaceContainer: QubeXCoreColors.qubexOffWhite,
    onSurfaceVariant: QubeXCoreColors.qubexDarkGray,
    outline: QubeXCoreColors.qubexGray,
    outlineVariant: Color(0xFFD6D6D6),
    shadow: Colors.black,
    scrim: Colors.black45,
    inverseSurface: QubeXCoreColors.qubexBlack,
    onInverseSurface: Colors.white,
    inversePrimary: QubeXCoreColors.primaryDark,
    surfaceTint: QubeXCoreColors.primaryBlue,
  );

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.light,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: Colors.white,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      pageTransitionsTheme: _pageTransitions,
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: const StadiumBorder())),
      dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: QubeXCoreColors.qubexBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(),
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: QubeXCoreColors.qubexBlack,
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        iconTheme: const IconThemeData(color: QubeXCoreColors.qubexBlack),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE3EEFF),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? QubeXCoreColors.primaryBlue
                : QubeXCoreColors.qubexDarkGray,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? QubeXCoreColors.primaryBlue
                : QubeXCoreColors.qubexDarkGray,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE6E6E6)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: QubeXCoreColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB3C7E8),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: QubeXCoreColors.primaryBlue,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: QubeXCoreColors.primaryBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: QubeXCoreColors.primaryBlue,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
            fontFamily: 'Inter', color: QubeXCoreColors.qubexGray),
        labelStyle: const TextStyle(
            fontFamily: 'Inter', color: QubeXCoreColors.qubexDarkGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: QubeXCoreColors.primaryBlue,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: QubeXCoreColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: QubeXCoreColors.errorRed,
            width: 2,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : QubeXCoreColors.qubexGray),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? QubeXCoreColors.primaryBlue
                : const Color(0xFFE0E3E8)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: QubeXCoreColors.qubexBlack,
        contentTextStyle: const TextStyle(
            fontFamily: 'Inter', color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE6E6E6),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: QubeXCoreColors.qubexDarkGray,
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: QubeXCoreColors.qubexBlack,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: QubeXCoreColors.qubexDarkGray,
          fontSize: 13,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: QubeXCoreColors.primaryBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFE3EEFF),
        labelStyle: const TextStyle(
            fontFamily: 'Inter', color: QubeXCoreColors.qubexBlack),
        side: const BorderSide(color: Color(0xFFD6D6D6)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w800,
          fontSize: 32,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Inter',
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Inter',
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: const TextStyle(
          fontFamily: 'Inter',
          color: QubeXCoreColors.qubexDarkGray,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'Inter',
          color: QubeXCoreColors.qubexBlack,
          fontSize: 16,
          height: 1.35,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Inter',
          color: QubeXCoreColors.qubexBlack,
          fontSize: 14,
          height: 1.35,
        ),
        bodySmall: const TextStyle(
          fontFamily: 'Inter',
          color: QubeXCoreColors.qubexDarkGray,
          fontSize: 12,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'Inter',
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Dark palette: near-black page background, layered charcoal surfaces,
  /// high-contrast text, and the brand blue accent lifted for legibility.
  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: QubeXCoreColors.primaryBlue,
    onPrimary: Colors.white,
    primaryContainer: QubeXCoreColors.primaryBlue,
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF4C8DFF),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF1E2A3F),
    onSecondaryContainer: Color(0xFFBFD4FF),
    tertiary: Color(0xFF34A853),
    onTertiary: Colors.black,
    tertiaryContainer: Color(0xFF12301F),
    onTertiaryContainer: Color(0xFF9BE0B7),
    error: Color(0xFFEF5350),
    onError: Colors.black,
    errorContainer: Color(0xFF3A1B1B),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: Color(0xFF17171A),
    onSurface: Color(0xFFF9F9F9),
    surfaceContainerHighest: Color(0xFF26262B),
    surfaceContainerHigh: Color(0xFF1E1E22),
    surfaceContainerLow: Color(0xFF141417),
    surfaceContainerLowest: Color(0xFF0D0D0F),
    surfaceContainer: Color(0xFF1E1E22),
    onSurfaceVariant: Color(0xFFA7A7A7),
    outline: Color(0xFF55555A),
    outlineVariant: Color(0xFF2C2C30),
    shadow: Colors.black,
    scrim: Colors.black45,
    inverseSurface: Color(0xFFF9F9F9),
    onInverseSurface: Color(0xFF17171A),
    inversePrimary: Color(0xFF003D99),
    surfaceTint: QubeXCoreColors.primaryBlue,
  );

  static ThemeData dark() {
    const pageBackground = Color(0xFF0D0D0F);
    const accentText = Color(0xFF4C8DFF);
    const border = Color(0xFF2C2C30);

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: pageBackground,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      pageTransitionsTheme: _pageTransitions,
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: const StadiumBorder())),
      dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF17171A),
        foregroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: const Color(0xFFF9F9F9),
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF9F9F9)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF17171A),
        indicatorColor: QubeXCoreColors.primaryBlue.withValues(alpha: 0.28),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accentText : const Color(0xFFA7A7A7),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accentText : const Color(0xFFA7A7A7),
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E22),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: QubeXCoreColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF1E2A44),
          disabledForegroundColor: const Color(0xFF6F7B8F),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentText,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: accentText),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E22),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle:
            const TextStyle(fontFamily: 'Inter', color: Color(0xFF77777C)),
        labelStyle:
            const TextStyle(fontFamily: 'Inter', color: Color(0xFFA7A7A7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF3A3A40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF3A3A40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: QubeXCoreColors.primaryBlue,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFEF5350)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: Color(0xFFEF5350),
            width: 2,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF26262B),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: Color(0xFFA7A7A7),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFA7A7A7),
          fontSize: 13,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: QubeXCoreColors.primaryBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF1E1E22),
        selectedColor: const Color(0xFF1E2A3F),
        labelStyle:
            const TextStyle(fontFamily: 'Inter', color: Color(0xFFF9F9F9)),
        side: const BorderSide(color: Color(0xFF3A3A40)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontWeight: FontWeight.w800,
          fontSize: 32,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFA7A7A7),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontSize: 16,
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontSize: 14,
          height: 1.35,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFA7A7A7),
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFFF9F9F9),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

abstract final class MoneyTextStyle {
  static TextStyle moneyStyle(BuildContext context, {Color? color}) {
    final base = Theme.of(context).textTheme.titleMedium;
    return (base ?? const TextStyle()).copyWith(
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle moneyLarge(BuildContext context, {Color? color}) {
    final base = Theme.of(context).textTheme.headlineMedium;
    return (base ?? const TextStyle()).copyWith(
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w800,
    );
  }
}
