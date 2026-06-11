import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'application/providers/settings_provider.dart';

class SlateApp extends ConsumerWidget {
  const SlateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

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