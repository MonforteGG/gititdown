import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color inkBlack = Color(0xFF1A1A1A);
  static const Color brandOrange = Color(0xFFE96A2B);
  static const Color inkGold = Color(0xFFC9A959);
  static const Color paperCream = Color(0xFFFAF8F5);
  static const Color paperWarm = Color(0xFFF5F2ED);
  static const Color warmGray = Color(0xFF6B6560);
  static const Color mutedGray = Color(0xFF9A9590);

  static const Color errorColor = Color(0xFFB33A3A);
  static const Color successColor = Color(0xFF2D6A4F);
  static const Color warningColor = Color(0xFFB8860B);

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const double smallPadding = sm;
  static const double mediumPadding = md;
  static const double largePadding = lg;
  static const double maxContentWidth = 720.0;

  static const double radiusSm = 6.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 20.0;

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: inkBlack.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: brandOrange.withOpacity(0.02),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: inkBlack.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: brandOrange.withOpacity(0.04),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  static TextTheme _buildTextTheme(Color textColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.5,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.3,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.8,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: brandOrange,
      scaffoldBackgroundColor: paperCream,
      colorScheme: const ColorScheme.light(
        primary: brandOrange,
        onPrimary: paperCream,
        secondary: inkGold,
        onSecondary: inkBlack,
        tertiary: warmGray,
        surface: paperWarm,
        onSurface: inkBlack,
        surfaceContainerHighest: Colors.white,
        error: errorColor,
        onError: Colors.white,
        outline: Color(0xFFE0DCD7),
      ),
      textTheme: _buildTextTheme(inkBlack, warmGray),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: paperCream,
        foregroundColor: inkBlack,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: inkBlack,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(
          color: inkBlack,
          size: 22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE8E4DF), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: brandOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: md, vertical: md),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: warmGray,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: mutedGray,
        ),
        prefixIconColor: warmGray,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: brandOrange,
          foregroundColor: paperCream,
          disabledBackgroundColor: mutedGray.withOpacity(0.3),
          disabledForegroundColor: mutedGray,
          padding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandOrange,
          side: const BorderSide(color: brandOrange, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandOrange,
          padding: const EdgeInsets.symmetric(horizontal: md, vertical: sm),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandOrange,
          foregroundColor: paperCream,
          padding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brandOrange,
        foregroundColor: paperCream,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        extendedTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: inkBlack,
          highlightColor: brandOrange.withOpacity(0.1),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return brandOrange;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return paperCream;
            }
            return inkBlack;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: Color(0xFFE0DCD7), width: 1),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E4DF),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: inkBlack,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: paperCream,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: inkBlack,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: warmGray,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: Color(0xFFD0CCC7),
        dragHandleSize: Size(40, 4),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandOrange,
        linearTrackColor: Color(0xFFE8E4DF),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paperWarm,
        selectedColor: brandOrange.withOpacity(0.15),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: inkBlack.withOpacity(0.9),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: paperCream,
        ),
      ),
    );
  }
}
