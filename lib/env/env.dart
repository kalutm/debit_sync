import 'dart:convert';

import 'package:flutter/services.dart';

/// Provides access to secure environment configuration bundled in
/// `assets/env/service_account.json`.
///
/// This file is intentionally gitignored. Every developer and CI pipeline
/// must supply it out-of-band before building. The file contains the Firebase
/// service account JSON used by [ClientSideFCMService].
///
/// Usage:
/// ```dart
/// final sa = await Env.loadServiceAccount();
/// final projectId = sa['project_id'] as String;
/// ```
abstract final class Env {
  static const String _serviceAccountAsset = 'assets/env/service_account.json';

  /// Reads and JSON-decodes the service account asset.
  ///
  /// Throws a [FlutterError] if the asset is missing (i.e. not placed before
  /// build time). Throws a [FormatException] if the JSON is malformed.
  static Future<Map<String, dynamic>> loadServiceAccount() async {
    final raw = await rootBundle.loadString(_serviceAccountAsset);
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
