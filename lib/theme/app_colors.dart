import 'package:flutter/material.dart';

class AppColors {
  // --- BRAND COLORS (Tema Utama: Profesional, Kepercayaan, Pertumbuhan) ---
  static const Color primary = Color(0xFF0D9488); // Teal Modern (Utama)
  static const Color primaryLight = Color(0xFF2DD4BF);
  static const Color primaryDark = Color(0xFF0F766E);

  // --- BACKGROUND & SURFACE (Latar Belakang & Kartu) ---
  // Light Mode
  static const Color backgroundLight = Color(0xFFF8FAFC); // Off-white yang nyaman di mata
  static const Color surfaceLight = Color(0xFFFFFFFF); // Putih bersih untuk Card
  // Dark Mode
  static const Color backgroundDark = Color(0xFF0F172A); // Slate sangat gelap (Bukan hitam pekat)
  static const Color surfaceDark = Color(0xFF1E293B); // Slate kebiruan untuk Card

  // --- TEXT COLORS (Tipografi) ---
  static const Color textPrimary = Color(0xFF0F172A); // Hampir hitam (Heading)
  static const Color textSecondary = Color(0xFF64748B); // Abu-abu (Subtitle/Deskripsi)
  
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Hampir putih
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Abu-abu terang

  // --- SEMANTIC COLORS (Status & Peringatan) ---
  static const Color success = Color(0xFF10B981); // Hijau Emerald (Lunas/Naik)
  static const Color warning = Color(0xFFF59E0B); // Amber (Jatuh Tempo)
  static const Color error = Color(0xFFEF4444); // Merah Soft (Hutang Telat/Hapus)
  static const Color info = Color(0xFF3B82F6); // Biru (Informasi)

  // --- BUSINESS UNIT COLORS (Identitas per Bisnis) ---
  static const Color kelapa = Color(0xFFF59E0B); // Amber/Orange
  static const Color galon = Color(0xFF0EA5E9); // Biru Air Laut
  static const Color kontrakan = Color(0xFF8B5CF6); // Ungu Premium
  static const Color glassBorder = Colors.white24;
}