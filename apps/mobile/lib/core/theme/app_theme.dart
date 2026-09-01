import 'package:flutter/material.dart';

class AppTheme {
  // Palette des couleurs d'accent disponibles
  static const List<Color> accentColors = [
    Color(0xFF4ECDC4), // 0 — Teal/Vert (défaut)
    Color(0xFFE53935), // 1 — Rouge vif
    Color(0xFFFDD835), // 2 — Jaune soleil
    Color(0xFF7C4DFF), // 3 — Violet électrique
    Color(0xFFFF7043), // 4 — Orange corail
  ];

  // Noms des couleurs (pour l'UI)
  static const List<String> accentColorNames = [
    'Teal',
    'Rouge',
    'Jaune',
    'Violet',
    'Orange',
  ];

  // Back-compat (utilisé potentiellement ailleurs)
  static Color get seedColor => accentColors[0];
  static const Color primaryColor = Color(0xFF4ECDC4);
  static const Color secondaryColor = Color(0xFFFF6584);
  static const Color accentColor = Color(0xFF6C63FF);
  static const Color aColor = Color(0xFF3C454B);

  /// Palette "Sonic Noir" — identité visuelle fixe de LKM Player en mode
  /// sombre avec l'accent teal par défaut (valeurs exactes des maquettes,
  /// pas générées via Material You). Les autres accents / le thème clair
  /// restent générés depuis la couleur choisie (voir [_theme]).
  static const ColorScheme _sonicNoirDark = ColorScheme(
    brightness: Brightness.dark,
    surface: Color(0xFF131313),
    onSurface: Color(0xFFE5E2E1),
    surfaceDim: Color(0xFF131313),
    surfaceBright: Color(0xFF3A3939),
    surfaceContainerLowest: Color(0xFF0E0E0E),
    surfaceContainerLow: Color(0xFF1C1B1B),
    surfaceContainer: Color(0xFF201F1F),
    surfaceContainerHigh: Color(0xFF2A2A2A),
    surfaceContainerHighest: Color(0xFF353534),
    onSurfaceVariant: Color(0xFFBCC9C7),
    outline: Color(0xFF869391),
    outlineVariant: Color(0xFF3D4948),
    inverseSurface: Color(0xFFE5E2E1),
    onInverseSurface: Color(0xFF313030),
    surfaceTint: Color(0xFF5DD9D0),
    primary: Color(0xFF6EE9E0),
    onPrimary: Color(0xFF003734),
    primaryContainer: Color(0xFF4ECDC4),
    onPrimaryContainer: Color(0xFF00544F),
    inversePrimary: Color(0xFF006A65),
    secondary: Color(0xFFFFB3B0),
    onSecondary: Color(0xFF68000F),
    secondaryContainer: Color(0xFF901822),
    onSecondaryContainer: Color(0xFFFF9E9B),
    tertiary: Color(0xFFEED65F),
    onTertiary: Color(0xFF393000),
    tertiaryContainer: Color(0xFFD1BA46),
    onTertiaryContainer: Color(0xFF564A00),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
  );

  static ThemeData lightTheme = _theme(brightness: Brightness.light);
  static ThemeData darkTheme = _theme(brightness: Brightness.dark);

  /// Génère un ThemeData avec la couleur d'accent choisie.
  static ThemeData themeFor(Color seed, Brightness brightness) {
    return _theme(brightness: brightness, seedColor: seed);
  }

  static ThemeData _theme(
      {required Brightness brightness, Color? seedColor}) {
    final seed = seedColor ?? accentColors[0];
    final isSonicNoir = brightness == Brightness.dark && seed == accentColors[0];
    final scheme = isSonicNoir
        ? _sonicNoirDark
        : ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    final isDark = brightness == Brightness.dark;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      fontFamily: 'Lexend',
    );

    // Échelle typographique "Sonic Noir" : display-lg / headline-md /
    // title-sm / body-md / label-sm, mappées sur les rôles Material les
    // plus proches pour que tout le reste de l'app (qui lit déjà
    // Theme.of(context).textTheme.xxx) en hérite automatiquement.
    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.64, // display-lg
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.24, // headline-md
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w500, // title-sm
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5, // body-md
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: 1.2,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.6, // label-sm
      ),
    );

    final radius = BorderRadius.circular(18);
    final sheetRadius = BorderRadius.circular(24);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.45 : 0.8),
        thickness: 1,
        space: 1,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
        indicatorColor:
            scheme.secondaryContainer.withValues(alpha: isDark ? 0.55 : 1),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight:
                states.contains(WidgetState.selected) ? FontWeight.w700 : null,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedItemColor: scheme.onSurface,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: const StadiumBorder(),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        showCloseIcon: true,
        closeIconColor: scheme.onInverseSurface.withValues(alpha: 0.85),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: sheetRadius.topLeft),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: sheetRadius),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        dense: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),

      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 4,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
    );
  }
}
