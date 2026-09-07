import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../features/auth/repositories/auth_repository.dart';

/// Handles all client-side Firebase Cloud Messaging setup:
/// - Permission requests
/// - Token retrieval and registration
/// - Token refresh subscription
/// - Foreground message display via a global [ScaffoldMessengerState] key
///
/// Lifecycle:
/// - Call [initialize] after a user successfully signs in.
/// - Call [teardown] when the user signs out.
final class FcmSetupService {
  FcmSetupService({required this.authRepository});

  final AuthRepository authRepository;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  /// Global key used to show foreground notification SnackBars from anywhere
  /// in the app without requiring a [BuildContext].
  ///
  /// Must be assigned to [MaterialApp.scaffoldMessengerKey].
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Requests notification permissions, fetches the device token, registers it
  /// against [uid], and subscribes to refresh and foreground message streams.
  ///
  /// Safe to call multiple times — existing subscriptions are cancelled first.
  Future<void> initialize(String uid) async {
    // Cancel any stale subscriptions from a previous session.
    await _cancelSubscriptions();

    // 1. Request permission (iOS prompts natively; Android 13+ also needs this).
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User explicitly denied — we can still receive data-only messages,
      // but we won't be able to show system notifications. Bail gracefully.
      debugPrint('[FcmSetupService] Notification permission denied.');
      return;
    }

    // 2. Retrieve the current device token and register it.
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _registerToken(uid, token);
    }

    // 3. Listen for token refreshes (e.g., app restore, token rotation).
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) => _registerToken(uid, newToken),
      onError: (e) =>
          debugPrint('[FcmSetupService] Token refresh error: $e'),
    );

    // 4. Listen for foreground messages and surface them as SnackBars.
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen(
      _onForegroundMessage,
      onError: (e) =>
          debugPrint('[FcmSetupService] Foreground message error: $e'),
    );

    debugPrint('[FcmSetupService] Initialized for uid=$uid token=$token');
  }

  /// Unregisters [token] from [uid]'s Firestore document and cancels all
  /// active FCM subscriptions.
  ///
  /// Should be called immediately before signing the user out.
  Future<void> teardown(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await authRepository.unregisterFcmToken(uid: uid, token: token);
      }
    } catch (e) {
      debugPrint('[FcmSetupService] Failed to unregister token: $e');
    }

    await _cancelSubscriptions();
    debugPrint('[FcmSetupService] Torn down for uid=$uid');
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _registerToken(String uid, String token) async {
    try {
      await authRepository.registerFcmToken(uid: uid, token: token);
      debugPrint('[FcmSetupService] Registered token for uid=$uid');
    } catch (e) {
      debugPrint('[FcmSetupService] Failed to register token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;

    if (title == null && body == null) return;

    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (body != null) Text(body),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );

    debugPrint('[FcmSetupService] Foreground message: title=$title body=$body');
  }

  Future<void> _cancelSubscriptions() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundMessageSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundMessageSub = null;
  }
}
