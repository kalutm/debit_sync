import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root application widget.
///
/// A [ConsumerWidget] so it can read the [appRouterProvider] from Riverpod.
/// Builds a [MaterialApp.router] with:
/// - The [GoRouter] instance from [appRouterProvider].
/// - Light and dark themes from [AppTheme].
/// - System-theme-aware brightness switching via [ThemeMode.system].
class DebitSyncApp extends ConsumerWidget {
  const DebitSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'DebitSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
