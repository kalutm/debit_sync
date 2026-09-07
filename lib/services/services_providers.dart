import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_providers.dart';
import 'client_side_fcm_service.dart';
import 'fcm_setup_service.dart';
import 'notification_service.dart';

/// Provides the concrete [NotificationService] implementation.
///
/// Uses [ClientSideFCMService] which dispatches FCM messages directly from
/// the client via the HTTP v1 API with a bundled service account.
///
/// Override in tests with a mock [NotificationService] via [ProviderContainer].
final notificationServiceProvider = Provider<NotificationService>(
  (ref) {
    final service = ClientSideFCMService();
    // Dispose the authenticated HTTP client when the provider is torn down
    // (e.g. on sign-out via ProviderContainer.dispose or override).
    ref.onDispose(service.dispose);
    return service;
  },
  name: 'notificationServiceProvider',
);

/// Provides the [FcmSetupService] responsible for permission requests,
/// device token registration, and foreground message display.
///
/// Scoped to the [ProviderScope] lifetime — a single instance is shared
/// across the app and manages its own internal subscription lifecycle.
final fcmSetupServiceProvider = Provider<FcmSetupService>(
  (ref) => FcmSetupService(
    authRepository: ref.watch(authRepositoryProvider),
  ),
  name: 'fcmSetupServiceProvider',
);
