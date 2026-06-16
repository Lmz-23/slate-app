import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/weekly/weekly_screen.dart';
import '../screens/stats/stats_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/badge_customization_screen.dart';
import '../screens/settings/ai_notification_settings_screen.dart';
import '../screens/categories/categories_screen.dart';
import '../widgets/common/navigation_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => NavigationShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/weekly',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WeeklyScreen(),
          ),
        ),
        GoRoute(
          path: '/stats',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: StatsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/categories',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: '/badge-customization',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BadgeCustomizationScreen(),
    ),
    GoRoute(
      path: '/ai-notification-settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AINotificationSettingsScreen(),
    ),
  ],
);