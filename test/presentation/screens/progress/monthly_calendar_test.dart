import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/providers/now_provider.dart';
import 'package:slate_app/application/providers/visible_month_provider.dart';
import 'package:slate_app/core/constants/app_colors.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';
import 'package:slate_app/domain/enums/task_priority.dart';
import 'package:slate_app/presentation/screens/stats/widgets/monthly_calendar.dart';

/// "Hoy" fijo para los tests: 10 de marzo de 2026.
final _testNow = DateTime(2026, 3, 10, 12, 0);

/// Notifier del mes visible con estado inicial fijo, para que los tests no
/// dependan del reloj real ni del timing del stream de `nowProvider`.
class _FixedVisibleMonthNotifier extends VisibleMonthNotifier {
  _FixedVisibleMonthNotifier(this.initialMonth);

  final DateTime initialMonth;

  @override
  DateTime build() => initialMonth;
}

/// Construye el calendario dentro de un `ProviderContainer` controlado.
///
/// `nowProvider` se sobreescribe con [nowProvider] fijo y `visibleMonthProvider`
/// con un notifier que inicia en `visibleMonth`. El stream de `nowProvider` se
/// espera antes de montar el árbol para que `nowProvider.value` esté disponible
/// de forma síncrona (evita fallbacks a `DateTime.now()`).
Future<void> _pumpCalendar(
  WidgetTester tester, {
  required DateTime visibleMonth,
  required List<Task> tasks,
}) async {
  final container = ProviderContainer(
    overrides: [
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_testNow)),
      visibleMonthProvider.overrideWith(
        () => _FixedVisibleMonthNotifier(DateTime(visibleMonth.year, visibleMonth.month)),
      ),
    ],
  );
  addTearDown(container.dispose);

  await container.read(nowProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          // En producción el calendario vive dentro de un SingleChildScrollView
          // (StatsScreen); replicarlo evita overflow en la superficie 800x600
          // de los tests cuando el mes tiene 5 filas de celdas.
          body: SingleChildScrollView(
            child: MonthlyCalendar(tasks: tasks),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

String _monthLabel(int year, int month) {
  const months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  return '${months[month - 1]} $year';
}

Task _task(String id, DateTime scheduledDate, {bool completed = false}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: scheduledDate,
    isCompleted: completed,
    priority: TaskPriority.normal,
    recurrence: RecurrenceType.none,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Cuenta los marcadores circulares (punto 6x6) dibujados bajo cada día.
int _markerCount(WidgetTester tester) {
  return tester
      .widgetList(find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final decoration = w.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            w.constraints?.maxWidth == 6;
      }))
      .length;
}

void main() {
  group('MonthlyCalendar - navegación entre meses', () {
    testWidgets('flecha anterior cambia al mes previo y la siguiente al mes siguiente',
        (tester) async {
      await _pumpCalendar(tester, visibleMonth: DateTime(2026, 3), tasks: []);

      expect(find.text(_monthLabel(2026, 3)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(find.text(_monthLabel(2026, 2)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text(_monthLabel(2026, 3)), findsOneWidget);
    });

    testWidgets('no se puede pasar del mes actual (C1a)', (tester) async {
      await _pumpCalendar(tester, visibleMonth: DateTime(2026, 3), tasks: []);

      // En el mes actual la flecha siguiente está deshabilitada.
      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(nextButton.onPressed, isNull);

      // Desde el mes anterior se puede volver al mes actual, pero no pasar de él.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(find.text(_monthLabel(2026, 2)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text(_monthLabel(2026, 3)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text(_monthLabel(2026, 3)), findsOneWidget,
          reason: 'la navegación hacia adelante se detiene en el mes actual');
    });

    testWidgets('botón "Hoy" vuelve al mes actual (C3a)', (tester) async {
      await _pumpCalendar(tester, visibleMonth: DateTime(2026, 3), tasks: []);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(find.text(_monthLabel(2026, 2)), findsOneWidget);

      await tester.tap(find.text('Hoy'));
      await tester.pump();
      expect(find.text(_monthLabel(2026, 3)), findsOneWidget);
    });
  });

  group('MonthlyCalendar - resaltado de "hoy"', () {
    testWidgets('solo resalta el día actual (día+mes+año) en el mes actual',
        (tester) async {
      await _pumpCalendar(tester, visibleMonth: DateTime(2026, 3), tasks: []);

      // Día 10 de marzo de 2026 (hoy): texto en negrita y color primario.
      final todayText = tester.widget<Text>(find.text('10'));
      expect(todayText.style?.fontWeight, FontWeight.bold);
      expect(todayText.style?.color, AppColors.primary);

      // Otro día del mismo mes NO está resaltado.
      final otherText = tester.widget<Text>(find.text('11'));
      expect(otherText.style?.fontWeight, isNot(FontWeight.bold));
      expect(otherText.style?.color, isNot(AppColors.primary));
    });

    testWidgets('no resalta ningún día al navegar a otro mes (evita bug latente)',
        (tester) async {
      await _pumpCalendar(tester, visibleMonth: DateTime(2026, 2), tasks: []);

      final febText = tester.widget<Text>(find.text('10'));
      expect(febText.style?.fontWeight, isNot(FontWeight.bold),
          reason: 'el día 10 de febrero NO es hoy');
      expect(febText.style?.color, isNot(AppColors.primary));
    });
  });

  group('MonthlyCalendar - marcado de días con tareas', () {
    testWidgets('marca los días del mes visible y no los de otros meses',
        (tester) async {
      final marchTask = _task('a', DateTime(2026, 3, 5), completed: true);
      final februaryTask = _task('b', DateTime(2026, 2, 20), completed: true);

      // En marzo solo la tarea de marzo debe marcar un día.
      await _pumpCalendar(
        tester,
        visibleMonth: DateTime(2026, 3),
        tasks: [marchTask, februaryTask],
      );
      expect(_markerCount(tester), 1,
          reason: 'la tarea de febrero no debe marcar días en marzo');

      // En febrero solo la tarea de febrero debe marcar un día.
      await _pumpCalendar(
        tester,
        visibleMonth: DateTime(2026, 2),
        tasks: [marchTask, februaryTask],
      );
      expect(_markerCount(tester), 1,
          reason: 'la tarea de marzo no debe marcar días en febrero');
    });

    testWidgets('un día completado en otro mes no aparece en el mes actual',
        (tester) async {
      final februaryCompleted = _task('c', DateTime(2026, 2, 20), completed: true);

      await _pumpCalendar(
        tester,
        visibleMonth: DateTime(2026, 3),
        tasks: [februaryCompleted],
      );
      expect(_markerCount(tester), 0,
          reason: 'el día 20 de febrero completado no debe marcar marzo');
    });
  });

  group('VisibleMonthNotifier - lógica de estado', () {
    test('inicializa en el mes actual y respeta los límites C1a/C3a', () async {
      final container = ProviderContainer(
        overrides: [
          nowProvider.overrideWith((ref) => Stream<DateTime>.value(_testNow)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(nowProvider.future);

      final notifier = container.read(visibleMonthProvider.notifier);

      expect(container.read(visibleMonthProvider), DateTime(2026, 3));

      // Hacia atrás libre.
      notifier.goToPreviousMonth();
      expect(container.read(visibleMonthProvider), DateTime(2026, 2));
      notifier.goToPreviousMonth();
      notifier.goToPreviousMonth();
      notifier.goToPreviousMonth();
      expect(container.read(visibleMonthProvider), DateTime(2025, 11));

      // Hacia adelante hasta el mes actual, no más allá.
      notifier.goToNextMonth();
      expect(container.read(visibleMonthProvider), DateTime(2025, 12));
      notifier.goToNextMonth();
      expect(container.read(visibleMonthProvider), DateTime(2026, 1));
      notifier.goToNextMonth();
      expect(container.read(visibleMonthProvider), DateTime(2026, 2));
      notifier.goToNextMonth();
      expect(container.read(visibleMonthProvider), DateTime(2026, 3));
      notifier.goToNextMonth();
      expect(container.read(visibleMonthProvider), DateTime(2026, 3),
          reason: 'no puede pasar del mes actual');
      expect(notifier.canGoToNextMonth, isFalse);

      // "Hoy" vuelve al mes actual desde cualquier mes.
      notifier.goToPreviousMonth();
      expect(container.read(visibleMonthProvider), DateTime(2026, 2));
      notifier.goToToday();
      expect(container.read(visibleMonthProvider), DateTime(2026, 3));
    });
  });
}
