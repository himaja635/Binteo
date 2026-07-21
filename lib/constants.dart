import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const Color matrimonyxv2DarkBlue = Color(0xFF1A237E);
  static const Color matrimonyxv2Blue = Color(0xFF5E17EB);
  static const Color matrimonyxv2Yellow = Color(0xFFFFC107);
  static const Color matrimonyxv2LightBlue = Color(0xFFE3F2FD);
}

class AppConstants {
  // Static cached backing field for the base URL. Defaults to production if .env isn't initialized yet.
  static String _baseUrl = "https://binteodemo.of2on.org";

  static String get baseUrl => _baseUrl;

  // Initialize and load base URL dynamically from the root .env!
  static Future<void> initialize() async {
    try {
      final envString = await rootBundle.loadString('.env');
      final lines = envString.split('\n');
      for (var line in lines) {
        line = line.trim();
        // Skip empty lines and comments
        if (line.isEmpty || line.startsWith('#')) continue;
        
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim().replaceAll('"', '').replaceAll("'", "");
          if (key == 'API_BASE_URL') {
            _baseUrl = value;
            break;
          }
        }
      }
    } catch (e) {
      // Degrades gracefully to production default if assets/.env is not loaded
      debugPrint("Could not load assets/.env: $e. Falling back to default URL: $_baseUrl");
    }
  }
}

// Function to get the public download directory path
Future<String> getPublicDownloadPath() async {
  return '/storage/emulated/0/Download';
}