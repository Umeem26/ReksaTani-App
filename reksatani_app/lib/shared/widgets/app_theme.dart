import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Selaras dengan LoginScreen color palette
  static const Color hijauTua   = Color(0xFF019241);
  static const Color hijauMuda  = Color(0xFF00AE3F);
  static const Color hijauSoft  = Color(0xFFE8F5E9);
  static const Color kuning     = Color(0xFFF59E0B);
  static const Color merah      = Color(0xFFEF4444);
  static const Color biru       = Color(0xFF3B82F6);
  static const Color bgPage     = Color(0xFFF5F7FA);
  static const Color bgCard     = Color(0xFFFFFFFF);
  static const Color border     = Color(0xFFE2E8F0);
  static const Color textPrimary= Color(0xFF061621);
  static const Color textSecond = Color(0xFF7B8B9A);
  static const Color textHint   = Color(0xFFCBD5E1);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF019241), Color(0xFF00AE3F)],
  );

  static BoxDecoration cardDecoration({double radius = 16}) => BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      );
}