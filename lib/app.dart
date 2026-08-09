import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'application/providers/settings_provider.dart';
import 'application/providers/notification_providers.dart';

class SlateApp extends ConsumerWidget {
  const SlateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // Mantiene vivo el controlador del recordatorio diario (10:00/19:00):
    // programa el del día al arrancar y reacciona a cambios de tareas,
    // ajustes y cambio de día sin necesidad de que una pantalla lo use.
    ref.watch(dailyReminderControllerProvider);

    return MaterialApp.router(
      title: 'Slate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode.themeMode,
      routerConfig: appRouter,
    );
  }
}