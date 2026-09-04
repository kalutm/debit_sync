import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'notification_service.dart';

/// Concrete FCM notification service that dispatches messages directly from
/// the client using the Firebase Cloud Messaging HTTP v1 API.
///
/// Authentication is handled by [googleapis_auth] using a Service Account
/// JSON loaded from the bundled asset `assets/env/service_account.json`.
///
/// ⚠️  SECURITY NOTE: Bundling a service account in a client app is only
/// acceptable in a zero-backend architecture where the app is distributed to
/// trusted, authenticated users. Rotate credentials regularly and restrict the
/// service account's IAM roles to `firebase.messaging.admin` only.
final class ClientSideFCMService implements NotificationService {
  ClientSideFCMService();

  // The OAuth 2.0 scope required to send FCM messages via the v1 API.
  static const List<String> _fcmScopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  static const String _assetPath = 'assets/env/service_account.json';

  /// Lazily cached authenticated HTTP client.
  /// Rebuilt automatically when the access token expires (googleapis_auth
  /// handles token refresh internally within the client lifecycle).
  http.Client? _authenticatedClient;

  /// Lazily cached Firebase project ID extracted from the service account.
  String? _projectId;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Loads the service account JSON from the asset bundle, extracts the
  /// project ID, and returns an authenticated HTTP client scoped to FCM.
  Future<(http.Client, String)> _getAuthenticatedClient() async {
    if (_authenticatedClient != null && _projectId != null) {
      return (_authenticatedClient!, _projectId!);
    }

    final jsonString = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> serviceAccountJson =
        jsonDecode(jsonString) as Map<String, dynamic>;

    final projectId = serviceAccountJson['project_id'] as String?;
    if (projectId == null || projectId.isEmpty) {
      throw const NotificationDispatchException(
        'Service account JSON is missing the "project_id" field.',
      );
    }

    final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    final client = await clientViaServiceAccount(credentials, _fcmScopes);

    _authenticatedClient = client;
    _projectId = projectId;

    return (client, projectId);
  }

  /// Closes the underlying authenticated HTTP client and resets cached state.
  /// Call this during logout or app teardown to release resources.
  void dispose() {
    _authenticatedClient?.close();
    _authenticatedClient = null;
    _projectId = null;
  }

  // ── NotificationService implementation ────────────────────────────────────

  @override
  Future<void> sendNotification({
    required String targetToken,
    required String title,
    required String body,
  }) async {
    late http.Client client;
    late String projectId;

    try {
      (client, projectId) = await _getAuthenticatedClient();
    } catch (e) {
      throw NotificationDispatchException(
        'Failed to obtain an authenticated FCM client.',
        cause: e,
      );
    }

    final endpoint = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
    );

    final payload = jsonEncode({
      'message': {
        'token': targetToken,
        'notification': {
          'title': title,
          'body': body,
        },
        // Data payload for background handling; mirrors the notification fields.
        'data': {
          'title': title,
          'body': body,
        },
        'android': {
          'priority': 'high',
        },
        'apns': {
          'headers': {'apns-priority': '10'},
        },
      },
    });

    final response = await client.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    if (response.statusCode != 200) {
      // Invalidate the cached client in case the token expired mid-session.
      _authenticatedClient = null;
      throw NotificationDispatchException(
        'FCM HTTP v1 request failed with status ${response.statusCode}.',
        cause: response.body,
      );
    }
  }
}
