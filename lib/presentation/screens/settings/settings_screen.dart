import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/enums/app_theme_mode.dart';
import '../../../application/providers/settings_provider.dart';
import '../../../application/services/timezone_service.dart';
import 'ai_notification_settings_screen.dart';
import 'badge_customization_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajustes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                title: 'Usuario',
                children: [
                  _buildTextField(
                    label: 'Nombre',
                    value: settings.userName,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateUserName(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                title: 'Ubicación y Zona Horaria',
                children: [
                  _buildSwitchTile(
                    icon: Icons.location_on_outlined,
                    title: 'Detectar zona automáticamente',
                    subtitle: settings.locationPermissionGranted
                        ? 'Usa tu ubicación para detectar la zona horaria'
                        : 'Permite acceder a tu ubicación',
                    value: settings.autoDetectTimezone,
                    onChanged: (value) async {
                      if (value) {
                        final status = await Permission.location.request();
                        if (status.isGranted) {
                          ref.read(settingsProvider.notifier).updateLocationPermissionGranted(true);
                          ref.read(settingsProvider.notifier).updateAutoDetectTimezone(true);
                        } else {
                          ref.read(settingsProvider.notifier).updateAutoDetectTimezone(false);
                        }
                      } else {
                        ref.read(settingsProvider.notifier).updateAutoDetectTimezone(false);
                      }
                    },
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildListTile(
                    icon: Icons.public,
                    title: 'Zona horaria',
                    subtitle: TimezoneService.getDisplayName(settings.timezone),
                    onTap: () => _showTimezonePicker(context, ref, settings.timezone),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                title: 'Preferencias',
                children: [
                  _buildListTile(
                    icon: Icons.access_time,
                    title: 'Hora de reset del día',
                    subtitle: '${settings.dayResetHour}:00 AM',
                    onTap: () => _showHourPicker(context, ref, settings.dayResetHour),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notificaciones',
                    subtitle: 'Recordatorios de tareas',
                    value: settings.notificationsEnabled,
                    onChanged: (value) async {
                      if (value) {
                        final status = await Permission.notification.request();
                        if (status.isGranted) {
                          ref.read(settingsProvider.notifier).updateNotificationsEnabled(true);
                        }
                      } else {
                        ref.read(settingsProvider.notifier).updateNotificationsEnabled(false);
                      }
                    },
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildListTile(
                    icon: Icons.smart_toy_outlined,
                    title: 'Estilo de notificaciones',
                    subtitle: settings.useAINotifications
                        ? 'Configurado con IA'
                        : 'Standard',
                    onTap: () => _showNotificationStylePicker(context, ref, settings),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildListTile(
                    icon: Icons.emoji_events_outlined,
                    title: 'Personalizar insignias',
                    subtitle: '${settings.customBadgeConfigs.length} insignias configuradas',
                    onTap: () => context.push('/badge-customization'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                title: 'Apariencia',
                children: [
                  _buildListTile(
                    icon: Icons.palette_outlined,
                    title: 'Tema',
                    subtitle: settings.themeMode.displayName,
                    onTap: () => _showThemePicker(context, ref, settings.themeMode),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                title: 'Gestión',
                children: [
                  _buildListTile(
                    icon: Icons.category_outlined,
                    title: 'Categorías',
                    subtitle: 'Administrar categorías',
                    onTap: () => context.push('/categories'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(
                  'Slate v1.2.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  void _showHourPicker(BuildContext context, WidgetRef ref, int currentHour) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Hora de reset',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: 24,
                  itemBuilder: (context, index) {
                    final isSelected = index == currentHour;
                    return ListTile(
                      title: Text(
                        '$index:00',
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref.read(settingsProvider.notifier).updateDayResetHour(index);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, AppThemeMode currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Tema',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...AppThemeMode.values.map((mode) {
                final isSelected = mode == currentMode;
                return ListTile(
                  leading: Icon(
                    mode == AppThemeMode.dark
                        ? Icons.dark_mode
                        : mode == AppThemeMode.light
                            ? Icons.light_mode
                            : Icons.brightness_auto,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  title: Text(
                    mode.displayName,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).updateThemeMode(mode);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationStylePicker(BuildContext context, WidgetRef ref, dynamic settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estilo de notificaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildNotificationOption(
                context: context,
                ref: ref,
                title: 'Standard',
                subtitle: 'Sonido, vibración y badge',
                icon: Icons.notifications_active,
                isSelected: !settings.useAINotifications,
                onTap: () {
                  ref.read(settingsProvider.notifier).updateUseAINotifications(false);
                  ref.read(settingsProvider.notifier).applyAINotificationSettings(
                    sound: true,
                    vibration: true,
                    badge: true,
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _buildNotificationOption(
                context: context,
                ref: ref,
                title: 'Configurar con IA',
                subtitle: 'Sube imágenes y texto para personalizar',
                icon: Icons.smart_toy,
                isSelected: settings.useAINotifications,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AINotificationSettingsScreen(),
                    ),
                  );
                },
              ),
              if (settings.useAINotifications) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        settings.notificationSound
                            ? Icons.volume_up
                            : Icons.volume_off,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        settings.notificationVibration
                            ? Icons.vibration
                            : Icons.phonelink_erase,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        settings.notificationBadge
                            ? Icons.notifications
                            : Icons.notifications_off,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Configuración actual',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showTimezonePicker(BuildContext context, WidgetRef ref, String currentTimezone) {
    final timezones = TimezoneService.sortedTimezones;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Zona horaria',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(color: AppColors.surfaceLight),
              Expanded(
                child: ListView.builder(
                  itemCount: timezones.length,
                  itemBuilder: (context, index) {
                    final tz = timezones[index];
                    final isSelected = tz == currentTimezone;
                    final isAmerica = tz.startsWith('America');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tz == 'America/Bogota' || tz == 'Europe/Madrid')
                          Padding(
                            padding: EdgeInsets.only(
                              left: AppSpacing.md,
                              top: AppSpacing.sm,
                            ),
                            child: Text(
                              isAmerica ? 'América' : 'Europa',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ListTile(
                          title: Text(
                            TimezoneService.getDisplayName(tz),
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            tz,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            ref.read(settingsProvider.notifier).updateTimezone(tz);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
