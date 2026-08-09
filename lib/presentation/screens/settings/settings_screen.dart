import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
                    onTap: () => _showHourPicker(
                      context,
                      ref,
                      settings.dayResetHour,
                      title: 'Hora de reset',
                      onSelect: (hour) =>
                          ref.read(settingsProvider.notifier).updateDayResetHour(hour),
                    ),
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
                title: 'Recordatorios',
                children: [
                  _buildInfoBox(
                    text: 'Por defecto te avisamos justo a la hora de la tarea '
                        '(margen 0). Puedes adelantar el aviso eligiendo un margen.',
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildListTile(
                    icon: Icons.timer_outlined,
                    title: 'Margen de aviso',
                    subtitle: _formatLeadTime(settings.notificationLeadTimeMinutes),
                    onTap: () => _showLeadTimePicker(context, ref, settings.notificationLeadTimeMinutes),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildSwitchTile(
                    icon: Icons.summarize_outlined,
                    title: 'Resumen diario',
                    subtitle: 'Recibe 2 resúmenes al día con tus pendientes',
                    value: settings.dailyReminderEnabled,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateDailyReminderEnabled(value);
                    },
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildListTile(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Resumen de la mañana',
                    subtitle: '${settings.dailyReminderHour1}:00 · si tienes tareas pendientes',
                    onTap: () => _showHourPicker(
                      context,
                      ref,
                      settings.dailyReminderHour1,
                      title: 'Hora del resumen',
                      onSelect: (hour) =>
                          ref.read(settingsProvider.notifier).updateDailyReminderHour1(hour),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildListTile(
                    icon: Icons.nightlight_outlined,
                    title: 'Resumen de la tarde',
                    subtitle: '${settings.dailyReminderHour2}:00 · solo si no completaste nada hoy',
                    onTap: () => _showHourPicker(
                      context,
                      ref,
                      settings.dailyReminderHour2,
                      title: 'Hora del resumen de la tarde',
                      onSelect: (hour) =>
                          ref.read(settingsProvider.notifier).updateDailyReminderHour2(hour),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildSwitchTile(
                    icon: Icons.nightlight_round,
                    title: 'Cierre de jornada',
                    subtitle: 'Resumen de tu día al día siguiente (${settings.dayResetHour}:00)',
                    value: settings.enableDayClosure,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateEnableDayClosure(value);
                    },
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
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildSwitchTile(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Slate System',
                    subtitle: 'Textos temáticos y rangos de nivel en notificaciones e insignias',
                    value: settings.slateSystemTheme,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateSlateSystemTheme(value);
                    },
                  ),
                  const Divider(height: 1, color: AppColors.surfaceLight),
                  _buildSwitchTile(
                    icon: Icons.smart_toy_outlined,
                    title: 'Textos con IA',
                    subtitle: 'Los títulos de tus tareas se envían a Google '
                        'Gemini para generar textos; se guardan en tu '
                        'dispositivo y, sin conexión o si lo desactivas, se '
                        'usan textos locales',
                    value: settings.useAIThematicTexts,
                    onChanged: (value) async {
                      if (value) {
                        // El toggle se activa SIEMPRE (no bloqueante): el
                        // diálogo es solo informativo y se muestra una vez.
                        ref.read(settingsProvider.notifier).updateUseAIThematicTexts(true);
                        await _showAIThematicPrivacyNoticeIfFirstTime(context);
                      } else {
                        ref.read(settingsProvider.notifier).updateUseAIThematicTexts(false);
                      }
                    },
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

  void _showHourPicker(
    BuildContext context,
    WidgetRef ref,
    int currentHour, {
    required String title,
    required void Function(int hour) onSelect,
  }) {
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
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  title,
                  style: const TextStyle(
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
                        onSelect(index);
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

  /// Aviso informativo (P2): por defecto el margen es 0 (aviso a la hora).
  String _formatLeadTime(int minutes) {
    if (minutes == 0) return 'A tiempo (0 min)';
    return '$minutes min antes';
  }

  Widget _buildInfoBox({required String text}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Aviso de privacidad del toggle "Textos con IA" (Hallazgo 2, review
  /// `3142d33`): informa que los títulos de las tareas se envían a Google
  /// Gemini, que los textos generados se guardan en el dispositivo y que hay
  /// fallback local sin conexión o con el toggle desactivado.
  ///
  /// Se muestra UNA sola vez (bandera en la caja auxiliar `app_meta`, el mismo
  /// patrón que `notification_prompted` en `main.dart`). NO es bloqueante: el
  /// toggle ya quedó activado antes de mostrar el diálogo y el usuario solo
  /// debe reconocer la información.
  Future<void> _showAIThematicPrivacyNoticeIfFirstTime(BuildContext context) async {
    final Box<dynamic> metaBox;
    try {
      metaBox = Hive.box('app_meta');
    } catch (_) {
      // La caja auxiliar puede no estar abierta en entornos de test; en ese
      // caso se omite el diálogo sin romper la pantalla.
      return;
    }
    if (metaBox.get('ai_thematic_notice_shown') == true) {
      return;
    }
    await metaBox.put('ai_thematic_notice_shown', true);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Textos con IA',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Al activar esta opción, los títulos de tus tareas se envían a un '
          'servicio externo de IA (Google Gemini) para generar los textos de '
          'las notificaciones.\n\n'
          'Los textos generados se guardan en tu dispositivo.\n\n'
          'Si estás sin conexión o desactivas esta opción, se usan textos '
          'locales y no se envía nada.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Entendido',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeadTimePicker(BuildContext context, WidgetRef ref, int current) {
    const options = [0, 5, 10, 15, 30, 60];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Margen de aviso',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final minutes = options[index];
                    final isSelected = minutes == current;
                    return ListTile(
                      title: Text(
                        _formatLeadTime(minutes),
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        minutes == 0
                            ? 'Avísame justo a la hora de la tarea'
                            : 'Avísame $minutes min antes de la tarea',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref.read(settingsProvider.notifier).updateNotificationLeadTime(minutes);
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
