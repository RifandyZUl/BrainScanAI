import 'package:flutter/foundation.dart';

class ApiConfig {
  // VPS Hostinger KVM 2
  static const String _vpsUrl = "http://31.97.49.142/api";

  // URL untuk di laptop (Development)
  static const String _localUrl = "http://127.0.0.1:8000";

  static String get baseUrl {
    if (kReleaseMode) {
      return _vpsUrl;
    } else {
      return _localUrl;
    }
  }
}
