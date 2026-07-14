import 'package:flutter/material.dart';

/// Paleta inspirada no BMO de Adventure Time.
class BmoColors {
  static const bodyGreen = Color(0xFF8BC9A3);         // borda BMO (cabeça)
  static const screenBg = Color(0xFF1E1F23);          // tela interna
  static const screenBgElevated = Color(0xFF26272C);  // cards/painéis
  static const textPrimary = Color(0xFFE8E8E8);       // texto principal
  static const textSecondary = Color(0xFF9A9A9A);     // texto secundário
  static const textMuted = Color(0xFF6A6A6A);         // labels/timestamps
  static const accentGreen = Color(0xFFB8E0C2);       // ativo (cursor, online)
  static const accentYellow = Color(0xFFE8D8A0);      // detalhes
  static const accentBlue = Color(0xFF8FB8E8);        // accents dos cards da
  static const accentRed = Color(0xFFE8938A);         // dashboard (botões coloridos do BMO)
}

class BmoTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // O frame cobre a viewport, mas o scaffold por baixo segue verde:
      // se em algum momento o frame não cobrir 100% (scrollbar, notch),
      // o que vaza por trás é a continuidade do BMO, não preto.
      scaffoldBackgroundColor: BmoColors.bodyGreen,
      colorScheme: const ColorScheme.dark(
        primary: BmoColors.accentGreen,
        secondary: BmoColors.accentYellow,
        surface: BmoColors.screenBg,
        onSurface: BmoColors.textPrimary,
      ),
      textTheme: const TextTheme(
        // Press Start 2P só em headers — pesa demais em corpo de texto
        displayLarge: TextStyle(fontFamily: 'PressStart2P', color: BmoColors.textPrimary),
        displayMedium: TextStyle(fontFamily: 'PressStart2P', color: BmoColors.textPrimary),
        displaySmall: TextStyle(fontFamily: 'PressStart2P', color: BmoColors.textPrimary),
        headlineLarge: TextStyle(fontFamily: 'PressStart2P', color: BmoColors.textPrimary),
        headlineMedium: TextStyle(fontFamily: 'PressStart2P', color: BmoColors.textPrimary),
        headlineSmall: TextStyle(fontFamily: 'PressStart2P', color: BmoColors.textPrimary, fontSize: 14),
        titleLarge: TextStyle(fontFamily: 'PressStart2P', color: BmoColors.textPrimary, fontSize: 12),

        // Inter pro corpo de texto e UI normal
        bodyLarge: TextStyle(fontFamily: 'Inter', color: BmoColors.textPrimary, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontFamily: 'Inter', color: BmoColors.textPrimary, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(fontFamily: 'Inter', color: BmoColors.textSecondary, fontSize: 12),
        labelLarge: TextStyle(fontFamily: 'Inter', color: BmoColors.textPrimary, fontSize: 14),
        labelMedium: TextStyle(fontFamily: 'Inter', color: BmoColors.textPrimary, fontSize: 12),
      ),
    );
  }
}
