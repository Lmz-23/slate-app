import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_schedule_calculator.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/application/services/timezone_service.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';

/// Fake CON REGISTRO del contrato de bajo nivel: cuenta las programaciones y
/// cancelaciones reales (a diferencia de los fakes no-op de otros tests) para
/// verificar el contrato de rendimiento del guardado de series recurrentes.
class _RecordingScheduler implements ReminderScheduler {
  int scheduleCalls = 0;
  final scheduledIds = <int>{};
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
  }) async {
    scheduleCalls++;
    scheduledIds.add(id);
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls++;
    scheduledIds.remove(id);
  }
}

void main() {
  late Directory tempDir;
  late TasksBox tasksBox;
  late SettingsBox settingsBox;
  late _RecordingScheduler scheduler;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_recurring_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();
    scheduler = _RecordingScheduler();
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
        ],
      );

  /// Espera a que drene la cadena asíncrona de la sincronización de
  /// recordatorios de las ocurrencias (lanzada con `unawaited` desde
  /// `addTask`).
  Future<void> settle() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('guardado de serie recurrente - recordatorios acotados (RAF)', () {
    test('crear una tarea DIARIA mantiene las ~365 instancias en BD pero NO '
        'programa una notificación por cada una', () async {
      // Relativo a "ahora" para no depender del reloj: hoy a las 23:59 (y las
      // ocurrencias de los días siguientes) quedan en el futuro y son
      // candidatas a recordatorio.
      final now = TimezoneService.nowInTimezone(settingsBox.getSettings().timezone);
      final today = DateTime(now.year, now.month, now.day);

      final container = createContainer();
      addTearDown(container.dispose);

      final mainId = await container.read(tasksProvider.notifier).addTask(
            title: 'Diaria',
            scheduledDate: today,
            scheduledTime: DateTime(today.year, today.month, today.day, 23, 59),
            recurrenceIndex: RecurrenceType.daily.index,
          );
      // La sincronización de ocurrencias es en segundo plano: se espera.
      await settle();

      // La generación de instancias en BD sigue intacta (parte del producto).
      final occurrences = container
          .read(tasksProvider)
          .where((t) => t.parentTaskId == mainId)
          .toList();
      expect(occurrences.length, 365,
          reason: 'la serie diaria genera las 365 instancias futuras en BD');

      // EL CONTRATO DE RENDIMIENTO: programar ~365 notificaciones nativas
      // secuenciales era el cuello de botella (8-12 s). Tras el fix solo se
      // programan la raíz + la VENTANA de ocurrencias.
      expect(scheduler.scheduleCalls, lessThan(30),
          reason: 'nunca ~365: solo raíz + próximas '
              '${ReminderScheduleCalculator.recurringReminderHorizonDays} '
              'ocurrencias entran en el scheduler');
    });

    test('tarea ÚNICA con horario: su recordatorio se programa '
        'normalmente (sin horizonte)', () async {
      final now = TimezoneService.nowInTimezone(settingsBox.getSettings().timezone);
      final today = DateTime(now.year, now.month, now.day);

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(tasksProvider.notifier).addTask(
            title: 'Única',
            scheduledDate: today,
            scheduledTime: DateTime(today.year, today.month, today.day, 23, 59),
          );
      await settle();

      expect(scheduler.scheduleCalls, 1,
          reason: 'una tarea única con horario programa su único recordatorio');
    });
  });

  group('deleteTaskAndRecurring - cancelación SELECTIVA de recordatorios', () {
    test('borrar una serie DIARIA elimina las 366 instancias de BD pero '
        'cancela SOLO la raíz + las ocurrencias del horizonte (≤12)', () async {
      final now = TimezoneService.nowInTimezone(settingsBox.getSettings().timezone);
      final today = DateTime(now.year, now.month, now.day);

      final container = createContainer();
      addTearDown(container.dispose);

      final mainId = await container.read(tasksProvider.notifier).addTask(
            title: 'Diaria a borrar',
            scheduledDate: today,
            scheduledTime: DateTime(today.year, today.month, today.day, 23, 59),
            recurrenceIndex: RecurrenceType.daily.index,
          );
      await settle();

      // Precondición: la serie completa vive en BD (raíz + 365 ocurrencias).
      expect(tasksBox.getAll().length, 366);

      final cancelsBefore = scheduler.cancelCalls;
      await container.read(tasksProvider.notifier).deleteTaskAndRecurring(mainId);
      final cancelDelta = scheduler.cancelCalls - cancelsBefore;

      // El borrado de BD sigue siendo COMPLETO (el usuario espera que la
      // serie desaparezca entera).
      expect(tasksBox.getAll(), isEmpty,
          reason: 'la serie desaparece al completo de la BD');
      expect(container.read(tasksProvider), isEmpty);

      // CONTRATO DE RENDIMIENTO: antes eran ~365 × 2 round trips nativos
      // (cancelar notificaciones que nunca existieron). Ahora solo la raíz
      // (siempre tiene recordatorio) + las ocurrencias cuya notificación
      // entró en el horizonte de recordatorios.
      expect(cancelDelta, greaterThan(0),
          reason: 'la raíz siempre se cancela');
      expect(cancelDelta, lessThanOrEqualTo(12),
          reason: 'nunca ~365: solo raíz + próximas '
              '${ReminderScheduleCalculator.recurringReminderHorizonDays} '
              'ocurrencias tenían notificación programada');
    });

    test('borrar desde UNA OCURRENCIA hija sube a la raíz y aplica la misma '
        'cancelación selectiva', () async {
      final now = TimezoneService.nowInTimezone(settingsBox.getSettings().timezone);
      final today = DateTime(now.year, now.month, now.day);

      final container = createContainer();
      addTearDown(container.dispose);

      final mainId = await container.read(tasksProvider.notifier).addTask(
            title: 'Diaria desde hija',
            scheduledDate: today,
            scheduledTime: DateTime(today.year, today.month, today.day, 23, 59),
            recurrenceIndex: RecurrenceType.daily.index,
          );
      await settle();

      final child = container
          .read(tasksProvider)
          .firstWhere((t) => t.parentTaskId == mainId && !t.isSubtask);

      final cancelsBefore = scheduler.cancelCalls;
      await container
          .read(tasksProvider.notifier)
          .deleteTaskAndRecurring(child.id);
      final cancelDelta = scheduler.cancelCalls - cancelsBefore;

      expect(tasksBox.getAll(), isEmpty,
          reason: 'borrar desde una hija borra la serie completa');
      expect(cancelDelta, lessThanOrEqualTo(12));
    });
  });
}