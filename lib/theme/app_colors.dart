import 'package:flutter/material.dart';

/// App-wide color constants
class AppColors {
  // Primary brand color
  static const Color primary = Color(0xFFC2185B);
  static const Color primaryDark = Color(0xFFAD1457);
  static const Color secondary = Color(0xFFAB47BC);
  
  // Background colors
  static const Color background = Color(0xFFFFF8E7); // Malai white (cream/off-white)
  static const Color surface = Color(0xFFFFFCF5); // Slightly lighter cream
  static const Color card = Color(0xFFFFFFFF); // Pure white for cards
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  
  // Gradient
  static const List<Color> primaryGradient = [primary, primaryDark];
}
