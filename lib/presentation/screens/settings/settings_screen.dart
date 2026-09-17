import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/slate_shapes.dart';
import '../../../core/theme/slate_theme_context.dart';
import '../../../domain/enums/app_theme_mode.dart';
import '../../../application/providers/settings_provider.dart';
import '../../../application/services/timezone_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final slate = context.slate;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajustes',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: slate.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                context,
                title: 'Usuario',
                children: [
                  _buildTextField(
                    context,
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
                context,
                title: 'Ubicación y Zona Horaria',
                children: [
                  _buildSwitchTile(
                    context,
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
                  Divider(height: 1, color: slate.outline),
                  _buildListTile(
                    context,
                    icon: Icons.public,
                    title: 'Zona horaria',
                    subtitle: TimezoneService.getDisplayName(settings.timezone),
                    onTap: () => _showTimezonePicker(context, ref, settings.timezone),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                context,
                title: 'Preferencias',
                children: [
                  _buildListTile(
                    context,
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
                  Divider(height: 1, color: slate.outline),
                  _buildSwitchTile(
                    context,
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
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                context,
                title: 'Recordatorios',
                children: [
                  _buildInfoBox(
                    context,
                    text: 'Por defecto te avisamos justo a la hora de la tarea '
                        '(margen 0). Puedes adelantar el aviso eligiendo un margen.',
                  ),
                  Divider(height: 1, color: slate.outline),
                  _buildListTile(
                    context,
                    icon: Icons.timer_outlined,
                    title: 'Margen de aviso',
                    subtitle: _formatLeadTime(settings.notificationLeadTimeMinutes),
                    onTap: () => _showLeadTimePicker(context, ref, settings.notificationLeadTimeMinutes),
                  ),
                  Divider(height: 1, color: slate.outline),
                  _buildSwitchTile(
                    context,
                    icon: Icons.summarize_outlined,
                    title: 'Resumen diario',
                    subtitle: 'Recibe 2 resúmenes al día con tus pendientes',
                    value: settings.dailyReminderEnabled,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateDailyReminderEnabled(value);
                    },
                  ),
                  Divider(height: 1, color: slate.outline),
                  _buildListTile(
                    context,
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
                  Divider(height: 1, color: slate.outline),
                  _buildListTile(
                    context,
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
                  Divider(height: 1, color: slate.outline),
                  _buildSwitchTile(
                    context,
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
                context,
                title: 'Apariencia',
                children: [
                  _buildListTile(
                    context,
                    icon: Icons.palette_outlined,
                    title: 'Tema',
                    subtitle: settings.themeMode.displayName,
                    onTap: () => _showThemePicker(context, ref, settings.themeMode),
                  ),
                  Divider(height: 1, color: slate.outline),
                  _buildSwitchTile(
                    context,
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
                context,
                title: 'Gestión',
                children: [
                  _buildListTile(
                    context,
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
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: slate.textTertiary,
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

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final slate = context.slate;
    final shapes = context.slateShapes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: slate.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: slate.surface,
            borderRadius: BorderRadius.circular(SlateShapes.radiusMedium),
            boxShadow: shapes.tileShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    final slate = context.slate;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: slate.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              color: slate.textPrimary,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final slate = context.slate;
    return ListTile(
      leading: Icon(icon, size: 20, color: slate.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: slate.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12.5,
          color: slate.textSecondary,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: slate.textTertiary),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final slate = context.slate;
    return ListTile(
      leading: Icon(icon, size: 20, color: slate.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: slate.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12.5,
          color: slate.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: slate.accent,
        inactiveTrackColor: slate.surfaceAlt,
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
    final slate = context.slate;
    showModalBottomSheet(
      context: context,
      backgroundColor: slate.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final slate = context.slate;
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: slate.textPrimary,
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
                          color: isSelected ? slate.accent : slate.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: slate.accent)
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

  Widget _buildInfoBox(BuildContext context, {required String text}) {
    final slate = context.slate;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: slate.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: slate.textSecondary,
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

    if (!context.mounted) return;
    final slate = context.slate;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: slate.background.withValues(alpha: 0.6),
      builder: (context) => AlertDialog(
        backgroundColor: slate.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        ),
        title: Text(
          'Textos con IA',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: slate.textPrimary,
          ),
        ),
        content: Text(
          'Al activar esta opción, los títulos de tus tareas se envían a un '
          'servicio externo de IA (Google Gemini) para generar los textos de '
          'las notificaciones.\n\n'
          'Los textos generados se guardan en tu dispositivo.\n\n'
          'Si estás sin conexión o desactivas esta opción, se usan textos '
          'locales y no se envía nada.',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            color: slate.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Entendido',
              style: TextStyle(color: slate.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeadTimePicker(BuildContext context, WidgetRef ref, int current) {
    const options = [0, 5, 10, 15, 30, 60];
    final slate = context.slate;
    showModalBottomSheet(
      context: context,
      backgroundColor: slate.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Margen de aviso',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.slate.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final slate = context.slate;
                    final minutes = options[index];
                    final isSelected = minutes == current;
                    return ListTile(
                      title: Text(
                        _formatLeadTime(minutes),
                        style: TextStyle(
                          color: isSelected ? slate.accent : slate.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        minutes == 0
                            ? 'Avísame justo a la hora de la tarea'
                            : 'Avísame $minutes min antes de la tarea',
                        style: TextStyle(
                          fontSize: 13,
                          color: slate.textSecondary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: slate.accent)
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
    final slate = context.slate;
    showModalBottomSheet(
      context: context,
      backgroundColor: slate.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 200,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Tema',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.slate.textPrimary,
                  ),
                ),
              ),
              ...AppThemeMode.values.map((mode) {
                final slate = context.slate;
                final isSelected = mode == currentMode;
                return ListTile(
                  leading: Icon(
                    mode == AppThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: isSelected ? slate.accent : slate.textSecondary,
                  ),
                  title: Text(
                    mode.displayName,
                    style: TextStyle(
                      color: isSelected ? slate.accent : slate.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: slate.accent)
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

  void _showTimezonePicker(BuildContext context, WidgetRef ref, String currentTimezone) {
    final timezones = TimezoneService.sortedTimezones;
    final slate = context.slate;

    showModalBottomSheet(
      context: context,
      backgroundColor: slate.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Zona horaria',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.slate.textPrimary,
                  ),
                ),
              ),
              Divider(color: context.slate.outline),
              Expanded(
                child: ListView.builder(
                  itemCount: timezones.length,
                  itemBuilder: (context, index) {
                    final slate = context.slate;
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
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: slate.accent,
                              ),
                            ),
                          ),
                        ListTile(
                          title: Text(
                            TimezoneService.getDisplayName(tz),
                            style: TextStyle(
                              color: isSelected ? slate.accent : slate.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            tz,
                            style: TextStyle(
                              fontSize: 12,
                              color: slate.textTertiary,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check, color: slate.accent)
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
