import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/data/backup/backup_codec.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/entities/user_settings.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';

/// Fake del contrato de bajo nivel (evita el plugin nativo en `flutter test`).
class _FakeScheduler implements ReminderScheduler {
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
  Future<void> cancel(int id) async {}
}

void main() {
  late Directory tempDir;
  late TasksBox tasksBox;
  late SettingsBox settingsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_monthly_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();
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
            ReminderManager(scheduler: _FakeScheduler()),
          ),
        ],
      );

  /// Crea una tarea mensual y devuelve la lista de ocurrencias generadas
  /// (tareas con parentTaskId == id de la raíz).
  Future<List<Task>> createMonthly(DateTime scheduledDate) async {
    final container = createContainer();
    addTearDown(container.dispose);
    final mainId = await container.read(tasksProvider.notifier).addTask(
          title: 'Mensual',
          scheduledDate: scheduledDate,
          recurrenceIndex: RecurrenceType.monthly.index,
        );
    return container
        .read(tasksProvider)
        .where((t) => t.parentTaskId == mainId)
        .toList();
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  group('F4 recurrencia mensual - generación', () {
    test('31-ene genera el MISMO día del mes siguiente (recorte a feb-28 en '
        'año no bisiesto) y recupera el 31 al volver un mes largo', () async {
      final occurrences = await createMonthly(DateTime(2026, 1, 31));
      final days = occurrences.map((t) => t.scheduledDate).toList();

      expect(days.any((d) => sameDay(d, DateTime(2026, 2, 28))), isTrue,
          reason: 'feb 2026 no tiene 31: cae el último día (28)');
      expect(days.any((d) => sameDay(d, DateTime(2026, 3, 31))), isTrue,
          reason: 'marzo vuelve a tener 31: recupera el día original');
      expect(days.any((d) => sameDay(d, DateTime(2026, 4, 30))), isTrue,
          reason: 'abril recorta a 30');
      expect(days.any((d) => sameDay(d, DateTime(2026, 5, 31))), isTrue);
    });

    test('30-ene: recorte a feb-28 y mantenimiento del 30 en meses largos/cortos',
        () async {
      final occurrences = await createMonthly(DateTime(2026, 1, 30));
      final days = occurrences.map((t) => t.scheduledDate).toList();

      expect(days.any((d) => sameDay(d, DateTime(2026, 2, 28))), isTrue);
      expect(days.any((d) => sameDay(d, DateTime(2026, 3, 30))), isTrue);
      expect(days.any((d) => sameDay(d, DateTime(2026, 4, 30))), isTrue,
          reason: 'abril tiene 30: sin recorte');
    });

    test('31-oct → nov-30 → dic-31 (recorte y recuperación en meses largos)',
        () async {
      final occurrences = await createMonthly(DateTime(2026, 10, 31));
      final days = occurrences.map((t) => t.scheduledDate).toList();

      expect(days.any((d) => sameDay(d, DateTime(2026, 11, 30))), isTrue);
      expect(days.any((d) => sameDay(d, DateTime(2026, 12, 31))), isTrue);
    });

    test('29-feb en bisiesto: 29 en años bisiestos y recorte al 28 en no '
        'bisiestos', () async {
      final occurrences = await createMonthly(DateTime(2024, 2, 29));
      final days = occurrences.map((t) => t.scheduledDate).toList();

      expect(days.any((d) => sameDay(d, DateTime(2024, 3, 29))), isTrue,
          reason: 'el mes siguiente mantiene el 29');
      expect(days.any((d) => sameDay(d, DateTime(2025, 2, 28))), isTrue,
          reason: 'feb 2025 no es bisiesto: recorte al último día (28)');
      // Dentro de la ventana de 365 días no vuelve a haber otro 29-feb.
      expect(days.any((d) => sameDay(d, DateTime(2025, 3, 29))), isFalse,
          reason: 'la ventana termina antes de marzo de 2025');
    });

    test('la ventana de 365 días genera ~12 ocurrencias mensuales (una por mes)',
        () async {
      final occurrences = await createMonthly(DateTime(2026, 1, 31));
      // De feb-2026 a ene-2027 inclusive = 12 meses.
      expect(occurrences.length, 12);
      final months = occurrences
          .map((t) => t.scheduledDate)
          .map((d) => '${d.year}-${d.month}')
          .toSet();
      expect(months, hasLength(12));
    });

    test('las ocurrencias NO se marcan como subtareas (isSubtask == false)',
        () async {
      final occurrences = await createMonthly(DateTime(2026, 1, 31));
      expect(occurrences.every((t) => !t.isSubtask), isTrue);
      expect(occurrences.every((t) => t.recurrence == RecurrenceType.monthly),
          isTrue);
    });
  });

  group('F4 recurrencia mensual - serialización', () {
    test('TaskAdapter: el índice del enum mensual (4) no rompe datos previos '
        'y roundtripea', () async {
      final container = createContainer();
      final mainId = await container.read(tasksProvider.notifier).addTask(
            title: 'Mensual Adapter',
            scheduledDate: DateTime(2026, 1, 31),
            recurrenceIndex: RecurrenceType.monthly.index,
          );
      final occurrences = container
          .read(tasksProvider)
          .where((t) => t.parentTaskId == mainId)
          .toList();
      addTearDown(container.dispose);

      expect(tasksBox.get(mainId)!.recurrence, RecurrenceType.monthly);
      expect(occurrences.first.recurrence, RecurrenceType.monthly);
    });

    test("BackupCodec: 'monthly' se serializa por .name y roundtripea", () {
      final task = Task(
        id: 't-m',
        title: 'Mensual',
        scheduledDate: DateTime(2026, 1, 31),
        recurrence: RecurrenceType.monthly,
        createdAt: DateTime(2026, 1, 31),
      );
      final json = BackupCodec.encode(
        tasks: [task],
        categories: const [],
        streaks: const [],
        badges: const [],
        userSettings: const UserSettings(),
        appMeta: const {},
        thematicTextCache: const {},
      );
      final decoded = BackupCodec.decode(json);

      expect(decoded.tasks.single.recurrence, RecurrenceType.monthly);
      expect(decoded.tasks.single, task);
    });

    test('un backup antiguo con recurrence desconocido cae a none (y un v1 '
        'sin monthly sigue importando)', () {
      // Simula un JSON escrito a mano sin el campo (equivalente a pre-F4).
      final ancient = Task(
        id: 't',
        title: 'Antigua',
        scheduledDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      final json = BackupCodec.encode(
        tasks: [ancient],
        categories: const [],
        streaks: const [],
        badges: const [],
        userSettings: const UserSettings(),
        appMeta: const {},
        thematicTextCache: const {},
      );

      final decoded = BackupCodec.decode(json);
      expect(decoded.tasks.single.recurrence, RecurrenceType.none);
    });
  });
}