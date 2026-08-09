import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../application/services/ai_service.dart';
import '../../../application/providers/settings_provider.dart';
import '../../../domain/entities/user_settings.dart';

class BadgeCustomizationScreen extends ConsumerStatefulWidget {
  const BadgeCustomizationScreen({super.key});

  @override
  ConsumerState<BadgeCustomizationScreen> createState() => _BadgeCustomizationScreenState();
}

class _BadgeCustomizationScreenState extends ConsumerState<BadgeCustomizationScreen> {
  final AIService _aiService = AIService();
  final ImagePicker _imagePicker = ImagePicker();

  // Badge definitions (days milestone -> default name)
  static const Map<String, int> _badgeMilestones = {
    'streak3': 3,
    'streak7': 7,
    'streak14': 14,
    'streak21': 21,
    'streak30': 30,
    'streak60': 60,
    'streak90': 90,
    'streak180': 180,
    'streak365': 365,
  };

  static const Map<String, String> _defaultBadgeNames = {
    'streak3': 'Primer Paso',
    'streak7': 'Semana Perfecta',
    'streak14': 'Quincena',
    'streak21': 'Hábito Formado',
    'streak30': 'Mes de Hierro',
    'streak60': 'Doble Mes',
    'streak90': 'Trimestre',
    'streak180': 'Medio Año',
    'streak365': 'Leyenda',
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final customConfigs = settings.customBadgeConfigs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar Insignias'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personalización con IA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Sube imágenes o describe tu estilo para personalizar los nombres e iconos de tus insignias.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Insignias de Racha',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._badgeMilestones.entries.map((entry) {
              final badgeType = entry.key;
              final days = entry.value;
              final defaultName = _defaultBadgeNames[badgeType] ?? 'Insignia $days';

              // Find custom config if exists
              final customConfig = customConfigs
                  .where((c) => c.badgeType == badgeType)
                  .firstOrNull;

              return _buildBadgeCard(
                badgeType: badgeType,
                days: days,
                defaultName: defaultName,
                customConfig: customConfig,
              );
            }),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                'Las insignias se desbloquean al alcanzar cada milestone',
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
    );
  }

  Widget _buildBadgeCard({
    required String badgeType,
    required int days,
    required String defaultName,
    CustomBadgeConfig? customConfig,
  }) {
    final isCustomized = customConfig != null;
    final displayName = isCustomized ? customConfig!.customName : defaultName;
    final iconName = isCustomized ? customConfig.iconName : 'star';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: isCustomized
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
            : null,
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(
            _getIconData(iconName),
            color: AppColors.primary,
          ),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            fontWeight: isCustomized ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '$days días',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: isCustomized
            ? Icon(Icons.edit, color: AppColors.primary, size: 20)
            : Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: () => _showCustomizationDialog(
          badgeType: badgeType,
          days: days,
          defaultName: defaultName,
          customConfig: customConfig,
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    const iconMap = {
      'star': Icons.star,
      'fire': Icons.local_fire_department,
      'lightning': Icons.bolt,
      'flower': Icons.local_florist,
      'shield': Icons.shield,
      'trophy': Icons.emoji_events,
      'crown': Icons.workspace_premium,
      'diamond': Icons.diamond,
      'rocket': Icons.rocket_launch,
      'sword': Icons.sports_martial_arts,
      'medal': Icons.military_tech,
      'award': Icons.verified,
      'flame': Icons.whatshot,
      'bolt': Icons.bolt,
      'zap': Icons.flash_on,
      'moon': Icons.nightlight_round,
      'sun': Icons.wb_sunny,
      'heart': Icons.favorite,
      'bell': Icons.notifications,
      'bellSlash': Icons.notifications_off,
      'bellOff': Icons.notifications_off,
      'volume': Icons.volume_up,
      'volume2': Icons.volume_down,
      'volumeX': Icons.volume_off,
      'alarm': Icons.alarm,
      'clock': Icons.access_time,
      'hourglass': Icons.hourglass_empty,
    };
    return iconMap[iconName] ?? Icons.star;
  }

  void _showCustomizationDialog({
    required String badgeType,
    required int days,
    required String defaultName,
    CustomBadgeConfig? customConfig,
  }) {
    final TextEditingController textController = TextEditingController(
      text: customConfig?.customName ?? '',
    );
    final List<String> selectedImages = [];
    bool isLoading = false;
    String? generatedName;
    String? generatedIcon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(
                            _getIconData(generatedIcon ?? 'star'),
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                generatedName ?? defaultName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Insignia de $days días',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Imágenes de referencia (opcional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final image = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (image != null) {
                                setModalState(() {
                                  selectedImages.add(image.path);
                                });
                              }
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                border: Border.all(
                                  color: AppColors.surfaceLight,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          ...selectedImages.map((path) {
                            return Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(left: AppSpacing.sm),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                image: DecorationImage(
                                  image: FileImage(File(path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    selectedImages.remove(path);
                                  });
                                },
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Descripción de estilo (opcional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        hintText: 'Ej: estilo épico, minimalista, gaming...',
                        hintStyle: TextStyle(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setModalState(() {
                                  isLoading = true;
                                });

                                try {
                                  final result = await _aiService.analyzeBadgeCustomization(
                                    badgeType: badgeType,
                                    daysRequired: days,
                                    imagePaths: selectedImages.isNotEmpty
                                        ? selectedImages
                                        : null,
                                    textDescription: textController.text.isNotEmpty
                                        ? textController.text
                                        : null,
                                  );

                                  setModalState(() {
                                    generatedName = result.name;
                                    generatedIcon = result.icon;
                                    isLoading = false;
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    isLoading = false;
                                  });
                                }
                              },
                        icon: isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : Icon(Icons.auto_awesome),
                        label: Text(
                          isLoading ? 'Generando...' : 'Generar con IA',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                      ),
                    ),
                    if (generatedName != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Sugerencia generada',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: BorderSide(color: AppColors.surfaceLight),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: generatedName != null
                                ? () {
                                    final config = CustomBadgeConfig(
                                      badgeType: badgeType,
                                      customName: generatedName!,
                                      iconName: generatedIcon ?? 'star',
                                      daysRequired: days,
                                    );
                                    ref.read(settingsProvider.notifier).updateCustomBadgeConfig(config);
                                    Navigator.pop(context);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.surfaceLight,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                            ),
                            child: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
