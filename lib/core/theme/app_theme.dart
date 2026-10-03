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
      brightness: Brightness.light,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: QubeXCoreColors.qubexOffWhite,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: QubeXCoreColors.qubexBlack,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w700,
          fontSize: 20,
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
          borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
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
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
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
        hintStyle: const TextStyle(color: QubeXCoreColors.qubexGray),
        labelStyle: const TextStyle(color: QubeXCoreColors.qubexDarkGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: QubeXCoreColors.primaryBlue,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QubeXCoreColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: QubeXCoreColors.errorRed,
            width: 2,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: QubeXCoreColors.qubexBlack,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
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
          color: QubeXCoreColors.qubexBlack,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
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
        labelStyle: const TextStyle(color: QubeXCoreColors.qubexBlack),
        side: const BorderSide(color: Color(0xFFD6D6D6)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w800,
          fontSize: 32,
        ),
        headlineMedium: const TextStyle(
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        headlineSmall: const TextStyle(
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        titleLarge: const TextStyle(
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        titleMedium: const TextStyle(
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: const TextStyle(
          color: QubeXCoreColors.qubexDarkGray,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        bodyLarge: const TextStyle(
          color: QubeXCoreColors.qubexBlack,
          fontSize: 16,
          height: 1.35,
        ),
        bodyMedium: const TextStyle(
          color: QubeXCoreColors.qubexBlack,
          fontSize: 14,
          height: 1.35,
        ),
        bodySmall: const TextStyle(
          color: QubeXCoreColors.qubexDarkGray,
          fontSize: 12,
        ),
        labelLarge: const TextStyle(
          color: QubeXCoreColors.qubexBlack,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = light();
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(
        primary: QubeXCoreColors.primaryBlue,
        onPrimary: Colors.white,
        secondary: QubeXCoreColors.primaryDark,
        onSecondary: Colors.white,
        error: QubeXCoreColors.errorRed,
        onError: Colors.white,
        surface: Color(0xFF1C1C1E),
        onSurface: Colors.white,
        onSurfaceVariant: QubeXCoreColors.qubexGray,
        outline: QubeXCoreColors.qubexDarkGray,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        titleTextStyle:
            base.textTheme.titleLarge?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: const Color(0xFF1C1C1E),
        indicatorColor: const Color(0xFF003366),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFF2C2C2E)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFF2C2C2E),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QubeXCoreColors.qubexDarkGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: QubeXCoreColors.primaryBlue,
            width: 2,
          ),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}

abstract final class MoneyTextStyle {
  static TextStyle moneyStyle(BuildContext context, {Color? color}) {
    final base = Theme.of(context).textTheme.titleMedium;
    return (base ?? const TextStyle()).copyWith(
      color: color ?? QubeXCoreColors.qubexBlack,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle moneyLarge(BuildContext context, {Color? color}) {
    final base = Theme.of(context).textTheme.headlineMedium;
    return (base ?? const TextStyle()).copyWith(
      color: color ?? QubeXCoreColors.qubexBlack,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w800,
    );
  }
}
