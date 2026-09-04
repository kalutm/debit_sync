/// Abstract contract for push notification dispatch.
///
/// All concrete implementations (e.g. [ClientSideFCMService]) must satisfy
/// this interface. Consumers depend only on this abstraction, keeping the
/// Riverpod provider graph decoupled from the underlying HTTP/auth mechanism.
abstract class NotificationService {
  /// Sends a push notification to a single device identified by [targetToken].
  ///
  /// - [targetToken] — the FCM registration token of the target device.
  /// - [title] — the notification title displayed in the system tray.
  /// - [body]  — the notification body text.
  ///
  /// Throws a [NotificationDispatchException] on unrecoverable failures
  /// (e.g. invalid token, network error after retries).
  Future<void> sendNotification({
    required String targetToken,
    required String title,
    required String body,
  });
}

/// Thrown when a notification could not be dispatched after all retry attempts.
final class NotificationDispatchException implements Exception {
  const NotificationDispatchException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'NotificationDispatchException: $message${cause != null ? ' (cause: $cause)' : ''}';
}
