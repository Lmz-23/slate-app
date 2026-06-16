import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../application/providers/settings_provider.dart';
import '../../../application/services/ai_service.dart';

class AINotificationSettingsScreen extends ConsumerStatefulWidget {
  const AINotificationSettingsScreen({super.key});

  @override
  ConsumerState<AINotificationSettingsScreen> createState() =>
      _AINotificationSettingsScreenState();
}

class _AINotificationSettingsScreenState
    extends ConsumerState<AINotificationSettingsScreen> {
  final _textController = TextEditingController();
  final List<String> _imagePaths = [];
  bool _isAnalyzing = false;
  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _textController.text = settings.notificationTextContext ?? '';
    _imagePaths.addAll(settings.notificationImagePaths);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _imagePaths.addAll(images.map((e) => e.path));
      });
    }
  }

  Future<void> _analyzeContext() async {
    setState(() => _isAnalyzing = true);

    try {
      // Save context first
      await ref.read(settingsProvider.notifier).updateNotificationContext(
            imagePaths: _imagePaths,
            textContext: _textController.text,
          );

      // Call AI service
      final result = await _aiService.analyzeNotificationSettings(
        imagePaths: _imagePaths.isNotEmpty ? _imagePaths : null,
        textDescription: _textController.text.isNotEmpty
            ? _textController.text
            : null,
      );

      // Apply settings
      await ref.read(settingsProvider.notifier).applyAINotificationSettings(
            sound: result.sound,
            vibration: result.vibration,
            badge: result.badge,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración aplicada'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar con IA'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuración actual',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      _buildToggleChip(
                        icon: Icons.volume_up,
                        label: 'Sonido',
                        isOn: settings.notificationSound,
                        onTap: () {
                          ref.read(settingsProvider.notifier)
                              .updateNotificationSound(!settings.notificationSound);
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildToggleChip(
                        icon: Icons.vibration,
                        label: 'Vibración',
                        isOn: settings.notificationVibration,
                        onTap: () {
                          ref.read(settingsProvider.notifier)
                              .updateNotificationVibration(!settings.notificationVibration);
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildToggleChip(
                        icon: Icons.notifications,
                        label: 'Badge',
                        isOn: settings.notificationBadge,
                        onTap: () {
                          ref.read(settingsProvider.notifier)
                              .updateNotificationBadge(!settings.notificationBadge);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Subir imágenes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Sube imágenes de apps o estilos que te gusten',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_imagePaths.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagePaths.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          child: Image.file(
                            File(_imagePaths[index]),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Agregar imágenes'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Descripción de texto (opcional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Describe el estilo de notificaciones que prefieres',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _textController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText:
                    'Ej: Quiero algo minimalista, sin sonido, solo que aparezca el badge...',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyzeContext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: _isAnalyzing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Analizar con IA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text(
                'Powered by Google Gemini',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required IconData icon,
    required String label,
    required bool isOn,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isOn
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: isOn
                ? Border.all(color: AppColors.primary, width: 1)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isOn ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isOn ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
