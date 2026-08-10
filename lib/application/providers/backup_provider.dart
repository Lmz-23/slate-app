import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/backup/backup_codec.dart';
import '../../data/backup/backup_file_store.dart';
import '../../data/backup/backup_service.dart';
import 'category_provider.dart';
import 'notification_providers.dart';
import 'player_provider.dart';
import 'quest_provider.dart';
import 'settings_provider.dart';
import 'streak_provider.dart';
import 'task_provider.dart';

/// Caja auxiliar `app_meta` (flags de una sola vez: notification_prompted,
/// ai_thematic_notice_shown, etc.). main() la abre y la sobrescribe aquí.
final appMetaBoxProvider = Provider<Box<dynamic>>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

/// Almacén de archivos. Por defecto usa path_provider; en tests se sobrescribe
/// con un directorio temporal.
final backupFileStoreProvider = Provider<BackupFileStore>((ref) {
  return BackupFileStore();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    tasksBox: ref.watch(tasksBoxProvider),
    categoriesBox: ref.watch(categoriesBoxProvider),
    streaksBox: ref.watch(streaksBoxProvider),
    badgesBox: ref.watch(badgesBoxProvider),
    settingsBox: ref.watch(settingsBoxProvider),
    thematicCache: ref.watch(thematicTextCacheProvider),
    appMetaBox: ref.watch(appMetaBoxProvider),
    // F4: las cajas del Jugador (F2) y del Sistema (F3) entran en el roundtrip.
    playerProgressBox: ref.watch(playerProgressBoxProvider),
    companionStateBox: ref.watch(companionStateBoxProvider),
    fileStore: ref.watch(backupFileStoreProvider),
  );
});

final backupControllerProvider =
    StateNotifierProvider<BackupController, BackupState>((ref) {
  return BackupController(ref.watch(backupServiceProvider), ref);
});

/// Estado de las operaciones de backup para la UI (Ajustes → Datos).
class BackupState {
  const BackupState({
    this.busy = false,
    this.message,
    this.filePath,
  });

  final bool busy;

  /// Mensaje del último resultado (éxito o error), apto para snackbar/UI.
  final String? message;

  /// Ruta del último archivo exportado.
  final String? filePath;

  BackupState copyWith({
    bool? busy,
    String? message,
    String? filePath,
    bool clearMessage = false,
  }) {
    return BackupState(
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      filePath: filePath ?? this.filePath,
    );
  }
}

class BackupController extends StateNotifier<BackupState> {
  BackupController(this._service, this._ref) : super(const BackupState());

  final BackupService _service;
  final Ref _ref;

  /// Exporta el estado actual a un archivo JSON.
  ///
  /// Devuelve el resultado si todo fue bien, o `null` y deja el mensaje de
  /// error en [BackupState.message]. El share sheet NO se abre aquí: la UI es
  /// quien decide cómo presentar la ruta (share_plus es un plugin de
  /// plataforma y mantener el controller puro facilita los tests).
  Future<BackupResult?> exportData() async {
    state = state.copyWith(busy: true, message: null, clearMessage: true);
    try {
      final result = await _service.exportData();
      state = state.copyWith(
        busy: false,
        message: 'Copia exportada (${result.taskCount} tareas, '
            '${result.categoryCount} categorías, ${result.badgeCount} insignias).',
        filePath: result.filePath,
      );
      return result;
    } on BackupException catch (e) {
      state = state.copyWith(busy: false, message: e.message);
      return null;
    } catch (e) {
      debugPrint('BackupController: error exportando: $e');
      state = state.copyWith(
        busy: false,
        message: 'Error inesperado al exportar los datos.',
      );
      return null;
    }
  }

  /// Importa un backup desde la ruta de un archivo (la UI ya pidió
  /// confirmación antes de llamar). Tras escribir las cajas, refresca TODOS
  /// los notifiers para que los providers reflejen el estado restaurado.
  Future<BackupResult?> importData(String path) async {
    state = state.copyWith(busy: true, message: null, clearMessage: true);
    try {
      final result = await _service.importFromPath(path);

      // Recarga completa: los providers deben reflejar el estado restaurado.
      _ref.read(tasksProvider.notifier).refresh();
      _ref.read(categoriesProvider.notifier).refresh();
      _ref.read(streakProvider.notifier).refresh();
      _ref.read(badgesProvider.notifier).refresh();
      _ref.read(settingsProvider.notifier).refresh();
      // F4: el perfil de Jugador (XP/nivel) y el estado del Sistema (quest)
      // también se restauran si el backup los incluía. Se usa `invalidate`
      // (rebuilt perezoso en la siguiente lectura) en lugar de `refresh` porque
      // estos providers no siempre están materializados (p. ej. en tests que
      // no sobrescriben sus cajas) y `invalidate` es inofensivo si el provider
      // nunca se leyó.
      _ref.invalidate(playerProvider);
      _ref.invalidate(questProvider);

      state = state.copyWith(
        busy: false,
        message: 'Datos restaurados: ${result.taskCount} tareas, '
            '${result.categoryCount} categorías, ${result.badgeCount} insignias '
            '(exportados el ${_formatDate(result.exportedAt)}).',
        filePath: null,
      );
      return result;
    } on BackupException catch (e) {
      state = state.copyWith(busy: false, message: e.message);
      return null;
    } catch (e) {
      debugPrint('BackupController: error importando: $e');
      state = state.copyWith(
        busy: false,
        message: 'Error inesperado al importar los datos. '
            'Los datos actuales no fueron modificados.',
      );
      return null;
    }
  }

  /// Limpia el mensaje mostrado (p. ej. al abrir otra sección).
  void clearMessage() => state = state.copyWith(message: null, clearMessage: true);

  String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}