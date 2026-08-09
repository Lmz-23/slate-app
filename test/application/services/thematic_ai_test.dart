import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/services/ai_service.dart';
import 'package:slate_app/application/services/reminder_schedule_calculator.dart';
import 'package:slate_app/application/services/thematic_texts_catalog.dart';
import 'package:slate_app/application/services/thematic_texts_generator.dart';
import 'package:slate_app/application/services/thematic_texts_resolver.dart';
import 'package:slate_app/data/hive/boxes/thematic_text_cache_box.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/entities/user_settings.dart';

/// Fake de AIService: "tiene" API key y devuelve un resultado controlado.
class FakeAIService extends AIService {
  final ThematicTextAIResult? result;
  int generateCalls = 0;

  FakeAIService({this.result});

  @override
  bool get canUseAI => true;

  @override
  Future<ThematicTextAIResult?> generateThematicText({
    required String eventType,
    required String titleContext,
  }) async {
    generateCalls++;
    return result;
  }
}

Task _task(String id, String title) {
  return Task(
    id: id,
    title: title,
    scheduledDate: DateTime(2026, 1, 15),
    createdAt: DateTime(2026, 1, 15),
  );
}

void main() {
  late Directory tempDir;
  late ThematicTextCache cache;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_thematic_ai_test');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    cache = ThematicTextCache();
    await cache.init();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('thematic_texts_cache');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('ThematicTextsGenerator', () {
    test('genera, guarda en caché y NO rellama a la IA si ya existe', () async {
      final fake = FakeAIService(
        result: ThematicTextAIResult(
          title: 'Título IA',
          body: 'Cuerpo generado por IA',
        ),
      );
      final generator = ThematicTextsGenerator(aiService: fake, cache: cache);
      final task = _task('abc', 'Mi tarea');

      await generator.ensureTaskVariant(task);
      expect(fake.generateCalls, 1);
      final entry = cache.get(ThematicTextsCatalog.taskCacheKey(task));
      expect(entry, isNotNull);
      expect(entry!.title, 'Título IA');
      expect(entry.body, 'Cuerpo generado por IA');

      await generator.ensureTaskVariant(task);
      expect(fake.generateCalls, 1, reason: 'idempotente: no regenera');
    });

    test('si la IA devuelve null (sin red/error), NO escribe caché', () async {
      final fake = FakeAIService(result: null);
      final generator = ThematicTextsGenerator(aiService: fake, cache: cache);
      final task = _task('b', 'Otra tarea');

      await generator.ensureTaskVariant(task);
      expect(fake.generateCalls, 1);
      expect(
        cache.get(ThematicTextsCatalog.taskCacheKey(task)),
        isNull,
        reason: 'el catálogo local es el fallback',
      );
    });

    test('ensureSummaryVariants genera los 3 textos globales', () async {
      final fake = FakeAIService(
        result: ThematicTextAIResult(title: 'T', body: 'C'),
      );
      final generator = ThematicTextsGenerator(aiService: fake, cache: cache);

      await generator.ensureSummaryVariants();
      expect(fake.generateCalls, 3);
      expect(cache.get('summary|morning'), isNotNull);
      expect(cache.get('summary|evening'), isNotNull);
      expect(cache.get('summary|closure'), isNotNull);
    });
  });

  group('ThematicTextsResolver', () {
    test('tema OFF -> null (el llamador usa los textos canónicos)', () {
      const resolver = ThematicTextsResolver();
      final task = _task('a', 'Mi tarea');

      expect(
        resolver.resolveTaskReminder(task, const UserSettings()),
        isNull,
      );
      expect(
        resolver.resolveMorningSummary(2, const UserSettings()),
        isNull,
      );
      expect(
        resolver.resolveEveningSummary(1, const UserSettings()),
        isNull,
      );
      expect(
        resolver.resolveDayClosure(
          DayClosureStats(
            jornada: DateTime(2026, 1, 14),
            total: 3,
            completed: 1,
          ),
          const UserSettings(),
        ),
        isNull,
      );
    });

    test('tema ON sin caché -> catálogo local', () {
      const resolver = ThematicTextsResolver();
      const settings = UserSettings(slateSystemTheme: true);
      final task = _task('a', 'Mi tarea');

      final reminder = resolver.resolveTaskReminder(task, settings);
      expect(reminder, isNotNull);
      expect(reminder!.title, contains('Daily Quest'));

      final morning = resolver.resolveMorningSummary(2, settings);
      expect(morning!.body, contains('2 misiones'));
    });

    test('tema ON con caché -> texto generado con IA', () async {
      final fake = FakeAIService(
        result: ThematicTextAIResult(
          title: 'Quest IA',
          body: 'Texto IA',
        ),
      );
      final generator = ThematicTextsGenerator(aiService: fake, cache: cache);
      final task = _task('a', 'Mi tarea');
      await generator.ensureTaskVariant(task);

      final resolver = ThematicTextsResolver(cache: cache);
      final text = resolver.resolveTaskReminder(
        task,
        const UserSettings(slateSystemTheme: true),
      );
      expect(text, isNotNull);
      expect(text!.title, 'Quest IA');
      expect(text.body, 'Texto IA');
    });

    test('tema ON + toggle OFF: la CACHÉ local se sigue usando (decisión '
        'Hallazgo 6)', () async {
      final fake = FakeAIService(
        result: ThematicTextAIResult(
          title: 'Título IA',
          body: 'Cuerpo IA',
        ),
      );
      final generator = ThematicTextsGenerator(aiService: fake, cache: cache);
      final task = _task('c', 'Mi tarea');
      await generator.ensureTaskVariant(task);

      // DECISIÓN documentada: tras desactivar "Textos con IA", las variantes
      // cacheadas (locales, ya generadas con el opt-in activo) se siguen
      // usando. El toggle solo detiene el ENVÍO de títulos a la IA; nunca se
      // reenvía nada al resolver.
      final resolver = ThematicTextsResolver(cache: cache);
      final text = resolver.resolveTaskReminder(
        task,
        const UserSettings(
          slateSystemTheme: true,
          useAIThematicTexts: false,
        ),
      );
      expect(text, isNotNull);
      expect(text!.title, 'Título IA');
      expect(text.body, 'Cuerpo IA');
    });

    test('el resolver es de SOLO LECTURA: resolver no dispara ni escribe '
        'generación', () async {
      // Hallazgo 1: el resolver ya no tiene referencia al generador; la
      // generación ocurre únicamente en el guardado (TasksNotifier). Este
      // test documenta el contrato: resolver devuelve catálogo local con caché
      // vacía y NO deja ninguna entrada nueva en la caché.
      final resolver = ThematicTextsResolver(cache: cache);
      final task = _task('d', 'Mi tarea');

      final text = resolver.resolveTaskReminder(
        task,
        const UserSettings(
          slateSystemTheme: true,
          useAIThematicTexts: true,
        ),
      );
      expect(text, isNotNull);
      expect(text!.title, contains('Daily Quest'));
      expect(
        cache.get(ThematicTextsCatalog.taskCacheKey(task)),
        isNull,
        reason: 'resolver no escribe caché: la generación no vive en este path',
      );
    });
  });
}