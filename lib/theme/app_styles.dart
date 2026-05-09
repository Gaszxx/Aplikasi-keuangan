import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppStyles {
  // --- SPACING & SIZING (Aturan Kelipatan 8) ---
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;

  // --- BORDER RADIUS (Kelengkungan Elegan) ---
  static const double radiusS = 8.0;
  static const double radiusM = 16.0;
  static const double radiusL = 24.0;
  static const double radiusXL = 32.0;

  static BorderRadius get cardRadius => BorderRadius.circular(radiusM);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusS);

  // --- BOX SHADOW (Bayangan Kartu Ala iOS/Modern Web) ---
  static List<BoxShadow> softShadow(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF0F172A).withOpacity(0.05), // Bayangan sangat lembut
        blurRadius: 15,
        offset: const Offset(0, 4),
      )
    ];
  }

  // --- INPUT DECORATION (Desain Form Input Global) ---
  static InputDecoration inputDecoration(String label, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textSecondary) : null,
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
  // --- BACKWARD COMPATIBILITY (Untuk login_screen & pin_keypad) ---
  static const TextStyle heading1 = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const TextStyle heading2 = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const TextStyle body = TextStyle(fontSize: 14, color: AppColors.textSecondary);
  
  static final BoxDecoration glassDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.glassBorder),
  );
}
