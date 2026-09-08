import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_providers.dart';
import 'services/fcm_setup_service.dart';
import 'services/services_providers.dart';

/// Root application widget.
///
/// Upgraded to a [ConsumerStatefulWidget] to watch [authStateProvider] and
/// drive the FCM setup lifecycle:
/// - Calls [FcmSetupService.initialize] when a user signs in.
/// - Calls [FcmSetupService.teardown] when the user signs out.
///
/// Also assigns [FcmSetupService.scaffoldMessengerKey] to
/// [MaterialApp.scaffoldMessengerKey] so that the service can show foreground
/// notification [SnackBar]s without a [BuildContext].
class DebitSyncApp extends ConsumerStatefulWidget {
  const DebitSyncApp({super.key});

  @override
  ConsumerState<DebitSyncApp> createState() => _DebitSyncAppState();
}

class _DebitSyncAppState extends ConsumerState<DebitSyncApp> {
  /// The UID of the last user we initialized FCM for.
  /// Prevents re-initializing on spurious auth stream emissions.
  String? _fcmInitializedUid;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToAuth());
  }

  void _listenToAuth() {
    ref.listenManual(
      authStateProvider,
      (_, next) async {
        final fcmService = ref.read(fcmSetupServiceProvider);
        final user = next.valueOrNull;

        if (user != null && user.uid != _fcmInitializedUid) {
          // New sign-in (or app restart with cached auth).
          _fcmInitializedUid = user.uid;
          await fcmService.initialize(user.uid);
        } else if (user == null && _fcmInitializedUid != null) {
          // Sign-out — clean up tokens and subscriptions.
          await fcmService.teardown(_fcmInitializedUid!);
          _fcmInitializedUid = null;
        }
      },
      fireImmediately: true, // Handle the current auth state on first build.
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Debit Sync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Global key enables SnackBars from FcmSetupService without BuildContext.
      scaffoldMessengerKey: FcmSetupService.scaffoldMessengerKey,
    );
  }
}
