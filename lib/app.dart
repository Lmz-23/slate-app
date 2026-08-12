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
    final dailyReminderController = ref.watch(dailyReminderControllerProvider);

    // La programación inicial se difiere hasta DESPUÉS de la primera frame:
    // `_scheduleEverything` lee `tasksProvider` (→ `getAll()` síncrono) y
    // lanza una ráfaga de `zonedSchedule` (cada uno = 2 round trips nativos en
    // el hilo de plataforma Android, el mismo del Choreographer). Ejecutarla
    // en el build causaba el jank de arranque (Skipped 39/81/252/31 frames).
    // `start()` es idempotente: los rebuilds posteriores de SlateApp son no-op.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      dailyReminderController.start();
    });

    return MaterialApp.router(
      title: 'Slate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode.themeMode,
      routerConfig: appRouter,
    );
  }
}
