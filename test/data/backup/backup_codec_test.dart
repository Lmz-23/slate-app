import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/data/backup/backup_codec.dart';
import 'package:slate_app/domain/entities/badge.dart';
import 'package:slate_app/domain/entities/category.dart';
import 'package:slate_app/domain/entities/streak.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/entities/user_settings.dart';
import 'package:slate_app/domain/enums/app_theme_mode.dart';
import 'package:slate_app/domain/enums/badge_type.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';
import 'package:slate_app/domain/enums/task_priority.dart';

void main() {
  Task sampleTask() => Task(
        id: 't-1',
        title: 'Comprar café',
        notes: 'Granos enteros',
        scheduledTime: DateTime(2026, 8, 9, 8, 0),
        scheduledDate: DateTime(2026, 8, 9),
        isCompleted: true,
        priority: TaskPriority.high,
        recurrence: RecurrenceType.weekly,
        recurrenceDays: const [1, 3],
        categoryId: 'c-1',
        createdAt: DateTime(2026, 8, 1),
        completedAt: DateTime(2026, 8, 9, 9, 0),
        parentTaskId: null,
      );

  Category sampleCategory() =>
      Category(id: 'c-1', name: 'Hogar', colorHex: '#FF5252', createdAt: DateTime(2026, 8, 1));

  Streak sampleStreak() => Streak(
        id: 'main_streak',
        currentStreak: 4,
        longestStreak: 7,
        lastCompletedDate: DateTime.utc(2026, 8, 8),
        updatedAt: DateTime(2026, 8, 9, 10, 0),
      );

  Badge sampleBadge() => Badge(
        id: 'b-1',
        type: BadgeType.streak7,
        name: 'Semana Perfecta',
        iconName: 'fire',
        unlockedAt: DateTime(2026, 8, 7),
        isDisplayed: true,
      );

  UserSettings sampleSettings() => const UserSettings(
        id: 'singleton',
        userName: 'Ada',
        dayResetHour: 6,
        notificationsEnabled: false,
        themeMode: AppThemeMode.light,
        unlockedThemeIds: ['dark', 'neon'],
        timezone: 'Europe/Madrid',
        autoDetectTimezone: true,
        locationPermissionGranted: true,
        useAINotifications: true,
        notificationSound: false,
        notificationVibration: true,
        notificationBadge: false,
        notificationImagePaths: ['/img/a.png'],
        notificationTextContext: 'mi contexto',
        notificationLeadTimeMinutes: 20,
        dailyReminderEnabled: false,
        dailyReminderHour1: 8,
        dailyReminderHour2: 21,
        useAIThematicTexts: true,
        enableDayClosure: true,
      );

  String sampleBackupString() {
    return BackupCodec.encode(
      tasks: [sampleTask()],
      categories: [sampleCategory()],
      streaks: [sampleStreak()],
      badges: [sampleBadge()],
      userSettings: sampleSettings(),
      appMeta: const {'notification_prompted': true, 'quincena_reported': '2026-08'},
      thematicTextCache: const {
        'task_t-1': {'title': 'Café', 'body': 'Cuerpo', 'createdAt': '2026-08-01T00:00:00.000'},
      },
      exportedAt: DateTime(2026, 8, 9, 10, 30),
    );
  }

  group('BackupCodec.encode', () {
    test('genera un JSON válido con schemaVersion 1 y datos esenciales', () {
      final jsonString = sampleBackupString();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['app'], 'slate');
      expect(decoded['schemaVersion'], 1);
      expect(decoded['exportedAt'], isA<String>());
      expect(DateTime.tryParse(decoded['exportedAt'] as String), isNotNull);

      final data = decoded['data'] as Map<String, dynamic>;
      expect(data['tasks'], isA<List>());
      expect((data['tasks'] as List), hasLength(1));
      expect(data['categories'], isA<List>());
      expect(data['streaks'], isA<List>());
      expect(data['badges'], isA<List>());
      expect(data['userSettings'], isA<Map<String, dynamic>>());
      expect(data['appMeta'], isA<Map<String, dynamic>>());
      expect(data['thematicTextCache'], isA<Map<String, dynamic>>());

      final task = (data['tasks'] as List).single as Map<String, dynamic>;
      expect(task['title'], 'Comprar café');
      expect(task['priority'], 'high');
      expect(task['recurrence'], 'weekly');
      expect(task['recurrenceDays'], [1, 3]);
      expect(task['isCompleted'], isTrue);

      final settings = data['userSettings'] as Map<String, dynamic>;
      expect(settings['userName'], 'Ada');
      expect(settings['useAIThematicTexts'], isTrue);
      expect(settings['enableDayClosure'], isTrue);
      // Los campos eliminados del modelo ya no se exportan.
      expect(settings.containsKey('slateSystemTheme'), isFalse);
      expect(settings.containsKey('customBadgeConfigs'), isFalse);
    });

    test('incluye timestamp de exportación', () {
      final jsonString =
          BackupCodec.encode(tasks: [], categories: [], streaks: [], badges: [],
              userSettings: const UserSettings(), appMeta: const {},
              thematicTextCache: const {}, exportedAt: DateTime(2026, 8, 9, 10, 30));
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['exportedAt'], '2026-08-09T10:30:00.000');
    });
  });

  group('BackupCodec.decode (import válido)', () {
    test('roundtrip preserva todas las entidades', () {
      final decoded = BackupCodec.decode(sampleBackupString());

      expect(decoded.schemaVersion, 1);
      expect(decoded.tasks, [sampleTask()]);
      expect(decoded.categories, [sampleCategory()]);
      expect(decoded.streaks, [sampleStreak()]);
      expect(decoded.badges, [sampleBadge()]);
      expect(decoded.userSettings, sampleSettings());
      expect(decoded.appMeta['notification_prompted'], isTrue);
      expect(decoded.thematicTextCache['task_t-1'], isA<Map<String, dynamic>>());
    });

    test('preserva los ajustes (sin los campos eliminados de personalización)',
        () {
      final decoded = BackupCodec.decode(sampleBackupString());
      expect(decoded.userSettings.useAIThematicTexts, isTrue);
      expect(decoded.userSettings.enableDayClosure, isTrue);
      expect(decoded.userSettings.dailyReminderEnabled, isFalse);
      expect(decoded.userSettings.dailyReminderHour1, 8);
    });
  });

  group('BackupCodec.decode (validación de archivos inválidos)', () {
    test('rechaza contenido que no es JSON', () {
      expect(
        () => BackupCodec.decode('esto no es json {'),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('JSON'))),
      );
    });

    test('rechaza un JSON que no pertenece a Slate', () {
      expect(
        () => BackupCodec.decode('{"app": "otra-app", "schemaVersion": 1}'),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('Slate'))),
      );
    });

    test('rechaza schemaVersion no soportado', () {
      // El helper siempre genera schemaVersion 1 (encode lo fija); se
      // reescribe el JSON para simular un backup de una versión futura.
      final jsonString = sampleBackupString().replaceFirst(
        '"schemaVersion": 1',
        '"schemaVersion": 2',
      );
      expect(
        () => BackupCodec.decode(jsonString),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('schemaVersion'))),
      );
    });

    test('rechaza la falta de la sección data', () {
      expect(
        () => BackupCodec.decode('{"app": "slate", "schemaVersion": 1}'),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('data'))),
      );
    });

    test('rechaza secciones con tipo incorrecto (tasks no es lista)', () {
      final bad = jsonDecode(sampleBackupString()) as Map<String, dynamic>;
      (bad['data'] as Map<String, dynamic>)['tasks'] = 'no-lista';
      expect(
        () => BackupCodec.decode(jsonEncode(bad)),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('tasks'))),
      );
    });

    test('rechaza entradas rotas dentro de una sección válida', () {
      final bad = jsonDecode(sampleBackupString()) as Map<String, dynamic>;
      (bad['data'] as Map<String, dynamic>)['tasks'] = [
        {'id': 'x'} // sin title ni fechas obligatorias
      ];
      expect(
        () => BackupCodec.decode(jsonEncode(bad)),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('inválidas'))),
      );
    });

    test('rechaza exportedAt ausente o no parseable', () {
      final bad = jsonDecode(sampleBackupString()) as Map<String, dynamic>;
      bad['exportedAt'] = 'fecha-invalida';
      expect(
        () => BackupCodec.decode(jsonEncode(bad)),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('exportedAt'))),
      );
    });
  });
}