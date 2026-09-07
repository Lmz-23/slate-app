import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/now_provider.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/task.dart';

/// Fake del contrato de bajo nivel (evita el plugin nativo en `flutter test`).
class _FakeScheduler implements ReminderScheduler {
  int cancelCalls = 0;

  @override
  Future<void> init({required String timezone}) async {}

  @override
  Future<bool> canScheduleExactNotifications() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  }) async {}

  @override
  Future<void> cancel(int id) async {
    cancelCalls++;
  }
}

void main() {
  // Reloj fijo: 11 ago 2026 10:00. Corte de poda = 2026-06-27 (hoy − 45 días).
  final fixedNow = DateTime(2026, 8, 11, 10, 0);
  final today = DateTime(2026, 8, 11);
  final cutoff = DateTime(2026, 6, 27);

  late Directory tempDir;
  late TasksBox tasksBox;
  late SettingsBox settingsBox;
  late _FakeScheduler scheduler;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_prune_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();
    scheduler = _FakeScheduler();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('tasks');
    await Hive.deleteBoxFromDisk('settings');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  ProviderContainer createContainer() => ProviderContainer(
        overrides: [
          tasksBoxProvider.overrideWithValue(tasksBox),
          settingsBoxProvider.overrideWithValue(settingsBox),
          reminderManagerProvider.overrideWithValue(
            ReminderManager(scheduler: scheduler),
          ),
          nowProvider.overrideWith(
            (ref) => Stream<DateTime>.value(fixedNow),
          ),
        ],
      );

  Task pending(String id, DateTime day) => Task(
        id: id,
        title: 'Pendiente $id',
        scheduledDate: day,
        createdAt: day,
      );

  Task completed(String id, DateTime day) => Task(
        id: id,
        title: 'Completada $id',
        scheduledDate: day,
        isCompleted: true,
        completedAt: day.add(const Duration(hours: 12)),
        createdAt: day,
      );

  Task subtaskOf(String id, String parentId, DateTime day) => Task(
        id: id,
        title: 'Subtarea $id',
        scheduledDate: day,
        createdAt: day,
        parentTaskId: parentId,
        isSubtask: true,
      );

  /// Siembra las tareas ANTES de construir el notifier (el estado inicial del
  /// provider lee la caja) y ejecuta la poda con el reloj fijo resuelto.
  Future<void> pruneSeeded(List<Task> tasks) async {
    for (final t in tasks) {
      await tasksBox.add(t);
    }
    final container = createContainer();
    addTearDown(container.dispose);
    // Garantiza que `nowProvider` ya emitió: `pruneOldPending` usa
    // `_ref.read(nowProvider).value` (fallback a reloj real si no emitió).
    await container.read(nowProvider.future);
    final notifier = container.read(tasksProvider.notifier);
    await notifier.pruneOldPending();
  }

  group('pruneOldPending - ventana de retención de 45 días', () {
    test('podada: pendiente pasada MÁS de 45 días (a)', () async {
      await pruneSeeded([pending('old', cutoff.subtract(const Duration(days: 1)))]);

      expect(tasksBox.get('old'), isNull,
          reason: 'una pendiente con scheduledDate < hoy−45 se poda');
    });

    test('NO podada: pendiente pasada DENTRO de los 45 días (b)', () async {
      await pruneSeeded([pending('recent', cutoff.add(const Duration(days: 1)))]);

      expect(tasksBox.get('recent'), isNotNull,
          reason: 'el usuario debe poder consultar pendientes recientes');
    });

    test('NO podada: exactamente en el límite de 45 días (hoy−45)', () async {
      // scheduledDate == hoy−45 NO es anterior al corte → se conserva.
      await pruneSeeded([pending('boundary', cutoff)]);

      expect(tasksBox.get('boundary'), isNotNull,
          reason: 'el corte compara con < estricto; hoy−45 queda dentro');
    });

    test('NO podada: COMPLETADA pasada >45 días protege racha/quest (c)',
        () async {
      await pruneSeeded([
        completed('done', cutoff.subtract(const Duration(days: 10))),
      ]);

      expect(tasksBox.get('done'), isNotNull,
          reason: 'JAMÁS se podan completadas: racha, mejor racha, historial '
              'del calendario y quest dependen de ellas');
    });

    test('NO podada: futura ni de hoy (d/e)', () async {
      await pruneSeeded([
        pending('future', DateTime(2026, 9, 1)),
        pending('today', today),
      ]);

      expect(tasksBox.get('future'), isNotNull);
      expect(tasksBox.get('today'), isNotNull);
    });

    test('subtarea pendiente se poda SOLO si su principal se poda (f/g)',
        () async {
      await pruneSeeded([
        // f) padre pendiente antiguo + subtarea pendiente antigua → ambos se
        //    podan para no dejar huérfanas.
        pending('parent-old', cutoff.subtract(const Duration(days: 5))),
        subtaskOf('sub-old', 'parent-old',
            cutoff.subtract(const Duration(days: 5))),
        // g) padre conservado (reciente) + subtarea antigua → la subtarea NO
        //    se poda (su principal no se podó).
        pending('parent-recent', DateTime(2026, 8, 10)),
        subtaskOf('sub-recent', 'parent-recent',
            cutoff.subtract(const Duration(days: 5))),
      ]);

      // f) Ambos desaparecen juntos (sin huérfanas).
      expect(tasksBox.get('parent-old'), isNull);
      expect(tasksBox.get('sub-old'), isNull);
      // g) El padre conservado mantiene su subtarea (aunque sea antigua): la
      //    poda de una subtarea depende de que su principal se pode.
      expect(tasksBox.get('parent-recent'), isNotNull);
      expect(tasksBox.get('sub-recent'), isNotNull,
          reason: 'una subtarea cuyo padre NO se poda NO se poda');
    });

    test('subtarea COMPLETADA bajo una principal podada NO se toca '
        '(seguridad)', () async {
      await pruneSeeded([
        pending('parent-pruned', cutoff.subtract(const Duration(days: 5))),
        // Subtarea completada del padre podado: NUNCA se poda (historial).
        completed('sub-done', cutoff.subtract(const Duration(days: 5)))
            .copyWith(parentTaskId: 'parent-pruned', isSubtask: true),
      ]);

      expect(tasksBox.get('parent-pruned'), isNull);
      expect(tasksBox.get('sub-done'), isNotNull,
          reason: 'una subtarea completada NO se toca, aunque su padre se pode');
    });

    test('la poda es idempotente por sesión: una segunda llamada no borra '
        'ni cancela nada nuevo', () async {
      await tasksBox.add(pending('old', cutoff.subtract(const Duration(days: 1))));
      final container = createContainer();
      addTearDown(container.dispose);
      await container.read(nowProvider.future);
      final notifier = container.read(tasksProvider.notifier);

      await notifier.pruneOldPending();
      expect(tasksBox.get('old'), isNull);
      final cancelsAfterFirst = scheduler.cancelCalls;
      expect(cancelsAfterFirst, greaterThan(0),
          reason: 'la primera poda cancela su recordatorio residual');

      await notifier.pruneOldPending();
      expect(scheduler.cancelCalls, cancelsAfterFirst,
          reason: 'el flag _pruned evita re-ejecutar la poda en la sesión');
    });
  });
}