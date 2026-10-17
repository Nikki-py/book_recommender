import 'package:flutter/foundation.dart';

/// Where the Python backend is running.
///
/// By default the Android emulator uses 10.0.2.2 (its name for your Mac) and
/// everything else (iOS simulator, Chrome) uses localhost. Override it for a
/// real phone on your Wi-Fi:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
const String _override = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_override.isNotEmpty) return _override;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
  return 'http://localhost:8000';
}
