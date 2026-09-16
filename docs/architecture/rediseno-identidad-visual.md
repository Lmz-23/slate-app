---
fecha: 2026-09-15
etapa: Architecture
---

# Arquitectura — Rediseño visual de identidad de slate-app

## Objetivo Arquitectónico

Definir la estructura que permita: (a) sustituir la identidad visual índigo-sobre-negro por la paleta cálida sobria del handoff en toda la app y en ambos modos (claro/oscuro), (b) reestructurar la presentación de la gamificación sin tocar su lógica de dominio, y (c) hacerlo de forma incremental, sin migraciones de datos y sin bloquear las pantallas que aún no tienen definición visual.

## Hallazgos del código actual que condicionan el diseño

1. El theming actual no es sensible al brillo a nivel de widget. AppColors (lib/core/constants/app_colors.dart) declara pares de constantes separadas (background/backgroundLight, textPrimary/textPrimaryLight, etc.) y los widgets referencian directamente las variantes oscuras (AppColors.card, AppColors.textPrimary, AppColors.surface) sin consultar Theme.of(context). Ejemplos: slate_card.dart, home_screen.dart, task_tile.dart, weekly_screen.dart, settings_screen.dart. Consecuencia: el modo claro hoy está roto de facto. El rediseño no puede resolverse cambiando los valores de AppColors.
2. Superficie de migración: 288 referencias a AppColors. en 20 archivos (todas en presentation/ salvo app_theme.dart). Mayores focos: app_theme.dart (49), settings_screen.dart (49), task_form_sheet.dart (37), task_tile.dart (29), weekly_screen.dart (19), categories_screen.dart (17), player_card.dart (14), streak_display.dart (13).
3. La fuente declarada no existe. AppTypography.fontFamily = 'Inter' pero pubspec.yaml no tiene sección fonts: ni google_fonts. Hoy se renderiza Roboto. Adoptar Nunito será la primera vez que la familia declarada sea real → cambio de métricas de texto en toda la app.
4. activeDays no es accesible desde el estado persistido. StreakCalculator.calculate() lo produce, pero la entidad Streak (y su adapter Hive) solo persiste currentStreak/longestStreak/lastCompletedDate/updatedAt. La fila "Esta semana" (RF3.3) no puede leerse de streakProvider tal como está.
5. El lenguaje RPG no vive solo en widgets. ThematicTextsCatalog está en application/services y alimenta la UI y los textos de notificaciones (reminder_manager.dart, notification_providers.dart) y el generador/caché de variantes con IA (thematic_texts_generator.dart, ThematicTextCache en Hive). Cambiar el tono de la copy tiene alcance fuera de presentation/.
6. Existen tests de widget acoplados a la gamificación actual: test/presentation/widgets/quest_card_test.dart, test/presentation/screens/stats/player_card_test.dart, badge_vault_test.dart, monthly_calendar_test.dart, widget_test.dart.
7. home_widget está declarado en pubspec.yaml y AndroidManifest.xml pero no se usa desde Dart: no hay widget nativo de home screen que restilizar. Riesgo descartado.
8. Navegación (app_router.dart + navigation_shell.dart): 4 rutas planas bajo un ShellRoute, índice resuelto por prefijo de path. BottomNavigationBar ya se estiliza desde ThemeData.

## Arquitectura Propuesta

### Decisión A1 — Sistema de design tokens basado en ThemeExtension (reemplaza a AppColors)

Nuevo módulo en lib/core/theme/:
```
lib/core/theme/
  tokens/slate_palette.dart      // valores crudos del handoff (hex), light + dark
  slate_colors.dart              // ThemeExtension<SlateColors> — tokens SEMÁNTICOS
  slate_typography.dart          // ThemeExtension o builder de TextTheme (Nunito)
  slate_shapes.dart              // radios, sombras y elevaciones por modo
  slate_theme_context.dart       // extension BuildContext => context.slate / context.slateText
  app_theme.dart                 // fábrica única que ensambla ThemeData claro y oscuro
```

- slate_palette.dart: constantes literales del handoff. Claro: #FCF1E4, #FFFBF3, #4A3325, #8C6F58, #C0A98F, #E8734F, #7FAE7A, #C15A4E, #E3A94A, #5C87C4, más borde de indicador vacío #E3D5C4, fondo de píldora de contador #F3DEC4. Oscuro: #241812, #34241B, #FBEEE0, #C9A88D, #8F7460, #E8734F, #8FC088, #E07362, más #402C21 (track de barra y píldora) y #F0A868 (acento de día actual en fila semanal, distinto del coral en oscuro).
- SlateColors extends ThemeExtension<SlateColors>: campos background, surface, surfaceAlt, outline, textPrimary, textSecondary, textTertiary, accent, onAccent, success, onSuccess, todayAccent, priorityHigh, priorityMedium, danger. Dos instancias const: SlateColors.light y SlateColors.dark.
- Acceso: SlateColors.of(context) = Theme.of(context).extension<SlateColors>() ?? SlateColors.dark. El fallback no es opcional: sin él, pumpWidget de test o BuildContext con ThemeData ajeno crashearía. Azúcar sintáctico: context.slate.textPrimary.
- app_theme.dart pasa a ser una fábrica: ThemeData _build(SlateColors c, SlateTypography t, Brightness b) y dos static final (lightTheme, darkTheme) que la invocan.
- Destino de AppColors: se elimina al final de la migración. No se deja como fachada deprecada. Sobrevive fromHex (usado para Category.colorHex), trasladado a core/utils/color_utils.dart.
- AppSpacing se conserva y se amplía con radios del mockup: 20, 18, 14, 10. Sombras en slate_shapes.dart, nullable por modo (oscuro sin sombras, claro con sombras específicas incl. FAB).

Alternativas evaluadas y rechazadas: editar AppColors in situ (deja modo claro roto); AppColors sensible al brillo vía InheritedWidget/Riverpod (mezcla estado con presentación); Riverpod provider de tokens en vez de ThemeExtension (dos fuentes de verdad); migración big-bang de 20 archivos (estado intermedio no compilable).

### Decisión A2 — Tipografía: Nunito empaquetada como asset, sin google_fonts

pubspec.yaml con sección fonts: y assets/fonts/Nunito-{Regular,SemiBold,Bold,ExtraBold}.ttf (pesos 400/600/700/800). Justificación: proyecto local-first con postura de privacidad explícita; google_fonts introduce descarga en red y modo de fallo que degrada toda la tipografía. Nunito es SIL OFL. Coste ~400-600 KB en APK. Riesgo: overflow en contenedores de tamaño fijo (celda de fecha 70px en home_screen, columnas de weekly_screen, chips de player_card).

### Decisión A3 — Gamificación: dominio congelado, presentación reestructurada mediante providers derivados

Regla estructural: domain/ y application/services/ de gamificación quedan intactos (player_xp_calculator.dart, quest_calculator.dart, streak_calculator.dart, PlayerProfile incl. shownLevelUps, Streak, Badge, BadgeType, simetría anti-exploit de TasksNotifier.toggleComplete, desbloqueo de insignias de BadgesNotifier). Todo el cambio ocurre en presentation/ más dos providers derivados de solo lectura en application/providers/:

- dailyProgressProvider → (completedToday, totalToday), derivado de tasksProvider + nowProvider. Resuelve dependencia D3: la Y debe ser el total real de tareas programadas hoy, no QuestCalculator.requiredCompletions (=3), porque la etiqueta dice "tareas completadas hoy" y usar el umbral de la quest mostraría información falsa.
- weekActivityProvider → List<bool> de 7 posiciones (L→D), recalculando StreakCalculator.calculate(...).activeDays desde tasksProvider. Se rechaza persistir activeDays en Streak porque obligaría a modificar StreakAdapter, typeId de Hive y backup_codec.dart, convirtiendo un rediseño visual en migración de datos con riesgo sobre backups existentes.

Tabla de componentes de presentación:

| Componente actual | Destino | Nota |
|---|---|---|
| home/widgets/quest_card.dart (QuestCard) | Sale del árbol de Home | Lógica (questProvider.claim()) sigue viva; ver P4 |
| widgets/streak_badge.dart (StreakBadge) | Reemplazado | Sustituido por rombo/gota coral; se extrae átomo StreakMark reutilizable |
| — | NUEVO home/widgets/daily_progress_card.dart | Tarjeta unificada de RF3 |
| — | NUEVO home/widgets/streak_header_row.dart | "N días seguidos" + StreakMark |
| — | NUEVO home/widgets/daily_progress_bar.dart | Texto + barra (dailyProgressProvider) |
| — | NUEVO home/widgets/week_activity_row.dart | 7 indicadores circulares (weekActivityProvider) |
| stats/widgets/player_card.dart | Convive, restilizado | Desaparece borde índigo con glow, glifo ◆, etiqueta "◆ JUGADOR" |
| stats/widgets/streak_display.dart | Convive, restilizado | Usará StreakMark |
| stats/widgets/badge_vault.dart | Convive, restilizado | Grid sirve, cambia tratamiento |
| stats/widgets/badge_presentation.dart | Convive, posible cambio de iconos | Resuelve por BadgeType, ya tiene fallback |
| widgets/common/level_up_snackbar.dart | Convive, restilizado | Requiere Aesthetic |
| widgets/common/slate_card.dart (SlateCard) | Se conserva, parametrizado | Debe aceptar radius/elevation |
| application/services/thematic_texts_catalog.dart | Cambio de tono, alcance fuera de UI | Ver riesgo RG5 |

### Decisión A4 — Impacto pantalla por pantalla

**home/home_screen.dart** (tiene mockup final): cabecera 24px w800/12.5px secundario, se elimina StreakBadge de cabecera. Selector de fechas: celdas 36px, radio 14, seleccionada en acento con sombra; recomendación de sustituir ListView.separated horizontal por Row de 7 Expanded. Cuerpo: DailyProgressCard → sección "Con horario" → sección "Sin horario" (P2) → estado vacío restilizado. La bottom nav no aparece en el mockup pero no implica eliminarla (omisión del marco de render).

**home/widgets/task_section.dart**: restilizado puro. Observación: contiene efectos de negocio (toggleComplete, recálculo de racha, showLevelUpSnackBar) — acoplamiento indebido documentado como deuda, fuera de alcance de este rediseño.

**widgets/task_tile.dart** (reestructuración real): mockup tiene check circular 24px, título, hora debajo del título (hoy va en la misma fila), y un punto de color de 7px antes del título. Hoy hay dos indicadores (punto de categoría + barra de prioridad de 4×40px) → ambigüedad A2/P1. Riesgo: el mockup no muestra more_horiz, única vía hoy para editar una tarea → P3. Se conserva Dismissible de borrado (fondo rojo con token danger).

**weekly/weekly_screen.dart**: restilizado completo (19 refs), host de RF9. Sin mockup final → requiere Aesthetic.

**stats/stats_screen.dart**: contenedor de gamificación reestructurada. Sin mockup final → requiere Aesthetic. Weekly y Stats se solapan; consolidación es decisión de producto con impacto en go_router (P6).

**settings/settings_screen.dart**: restilizado puro (49 refs), sin cambios estructurales. No se añade toggle de gamificación (A1 resuelta).

**task_form/task_form_sheet.dart** + selectores: restilizado (37+16 refs). Selectores de prioridad usan tokens semánticos. Sin mockup final en el tono elegido → requiere Aesthetic.

**stats/widgets/monthly_calendar.dart**: restilizado (puntos verde/ámbar). Tiene test asociado.

**widgets/common/navigation_shell.dart**: sin cambio estructural, color desde bottomNavigationBarTheme. Ningún mockup la define → requiere Aesthetic mínima.

**categories_screen.dart**: restilizado (17 refs) + Decisión A5.

### Decisión A5 — Paleta de categorías

AppColors.categoryColors son 17 colores saturados tipo Tailwind que chocan con la paleta cálida. No requiere migración (categorías persisten su colorHex propio). Cambia la oferta del selector para categorías nuevas: paleta curada de 8-10 tonos cálidos compatibles, semilla #5C87C4. Elección concreta de tonos es de Aesthetic.

### Decisión A6 — Secuenciación en tres fases

- Fase 1 — Infraestructura (desbloqueada): slate_palette, SlateColors, SlateTypography, slate_shapes, fábrica de app_theme, asset Nunito, helper de tests pumpWithSlateTheme. AppColors sigue existiendo y compilando. Entregable solo, suite en verde.
- Fase 2 — Agenda (desbloqueada, tiene mockup final): DailyProgressCard + átomos, providers derivados, home_screen, task_section, task_tile, retirada de QuestCard y StreakBadge de Home. Migración a tokens de esos archivos.
- Fase 3 — Resto de la app (bloqueada por Aesthetic): Weekly, Stats + gamificación reestructurada, Settings, Task form, Categories, Monthly calendar, Navigation shell, snackbars/diálogos/estados vacíos. Cierre: borrado de AppColors.
- Fase 4 (opcional, workstream separado) — Marca: ver A7.

### Decisión A7 — Marca (nombre y logo): inventario de impacto, sin decidir el nombre

Separar "nombre comercial" de "identificadores técnicos".

Bajo riesgo (cambiar libremente si el usuario lo decide): AndroidManifest.xml (android:label), Info.plist (CFBundleName/CFBundleDisplayName), lib/app.dart (MaterialApp.title), icono (icon/slate_icon_v1.png, flutter_launcher_icons.yaml, adaptive_icon_background actualmente #1A1A2E — debería pasar a #241812), splash y colores nativos (launch_background.xml, colors.xml, styles.xml, LaunchScreen.storyboard), copy visible con identidad "Slate System" (ThematicTextsCatalog, README.md).

Alto riesgo (recomendación explícita de NO tocar): applicationId/namespace = com.slate.slate_app, directorio Kotlin com/slate/slate_app/MainActivity.kt, bundle id de iOS — cambiar equivale a otra app (listado nuevo si está publicada, o pérdida de datos locales de Hive si se reinstala). Nombre del paquete Dart slate_app en pubspec.yaml — renombrarlo obliga a reescribir todos los package:slate_app/... de lib/ y 31 archivos de test, churn masivo sin beneficio. Identificadores internos (SlateApp, SlateCard, archivos slate_*) pueden quedarse.

## Flujo de Información

```
Hive boxes ──> repositories ──> StateNotifiers (tasks, streak, player, badges, quest, settings)
                                        │
                                        ├─ dailyProgressProvider  (derivado, nuevo)
                                        └─ weekActivityProvider   (derivado, nuevo)
                                                     │
settingsProvider.themeMode ──> MaterialApp.router ──> ThemeData(light|dark)
                                                          │  extensions: SlateColors, SlateTypography, SlateShapes
                                                          ▼
                                            SlateColors.of(context) / context.slate
                                                          ▼
                                     widgets de presentación (sin constantes de color propias)
```

## Dependencias

- D-A Asset de fuente Nunito (4 pesos, OFL).
- D-B Definición visual de Aesthetic para Fase 3.
- D-C Decisiones de producto P1–P9.
- D-D Actualización de tests de widget existentes (bloquea cierre de Fase 2 y 3, no su inicio).

## Riesgos Arquitectónicos

| # | Riesgo | Impacto | Mitigación |
|---|---|---|---|
| RG1 | Migraciones Hive | Alto si ocurre | Ninguna es necesaria; restricción dura: cero typeId nuevos, cero cambios de adapter/backup_codec |
| RG2 | Cambio de métricas tipográficas (Roboto→Nunito) | Medio | Revisar contenedores de tamaño fijo; verificación en pantalla pequeña y escala de fuente aumentada |
| RG3 | Migración de 288 referencias en estado intermedio | Medio | AppColors y SlateColors conviven durante Fases 1–3; borrado de AppColors como verificación final |
| RG4 | Tests de widget existentes se rompen | Medio | Presupuestar actualización por fase; helper pumpWithSlateTheme; SlateColors.of() con fallback obligatorio |
| RG5 | Acoplamiento del tono de copy con notificaciones y caché de IA | Medio-alto | ThematicTextCache guarda variantes con voz RPG anterior; requiere invalidación (P7) |
| RG6 | Modo claro nunca ha sido real | Medio | Verificación obligatoria en ambos brillos |
| RG7 | Pérdida de acceso a edición de tareas si se elimina more_horiz | Alto (regresión funcional) | P3 |
| RG8 | Quest huérfana si QuestCard sale sin reubicar la acción | Alto (regresión silenciosa) | P4 |
| RG9 | Navegación (go_router) | Bajo salvo consolidación | Solo se rompe si se consolidan Weekly y Stats (P6) |
| RG10 | Performance de theming dinámico | Bajo si se respeta el patrón | static final; ThemeExtension.lerp liviano |
| RG11 | Deriva entre temas (causa raíz del bug actual) | Medio | Fábrica única de ThemeData lo previene estructuralmente |
| RG12 | Splash e icono desalineados con nueva paleta | Bajo técnico, alto en percepción | Incluir recursos nativos en alcance aunque no cambie el logo |

## Puntos que requieren decisión antes de Implementation

Del Orquestador/usuario (producto):
- P1 (A2) — Semántica del punto de color en tarjeta de tarea. Propuesta por defecto: un único punto que muestre color de prioridad cuando prioridad ≠ normal, y color de categoría en caso contrario.
- P2 (A3) — Sección "Sin horario" ausente del mockup. Recomendación: conservarla (quitarla sería regresión funcional).
- P3 — Afordancia de edición en tarjeta de tarea si se retira more_horiz. Opciones: conservar icono (más seguro), o mover a pulsación larga/swipe.
- P4 (RG8) — Destino de "reclamar quest" (+25 XP). Opciones: (a) afordancia discreta en la tarjeta de progreso, visible solo si canClaim (recomendada); (b) trasladar a Stats/Progreso; (c) auto-reclamar (cambia comportamiento de dominio, excede autoridad de Architecture).
- P5 — Visibilidad de nivel/XP/rango en la app sobria; cuánto se muestra y con qué vocabulario.
- P6 — Consolidación de Weekly y Stats (fuera de alcance salvo instrucción explícita).
- P7 (RG5) — Invalidación de ThematicTextCache al cambiar tono de copy, y alcance del cambio en notificaciones.
- P8 — Alcance de marca. Recomendación: cambiar solo nombre visible + icono + splash, no applicationId/paquete Dart.
- P9 — Confirmación de fuente: Nunito como asset local (recomendado) vs google_fonts.

Requiere definición de Aesthetic antes de implementarse con precisión (bloquea Fase 3, no 1 ni 2):
1. Gamificación reestructurada (nivel, XP, progreso, rango, insignias en tono cálido sobrio).
2. Pantalla Stats completa.
3. Pantalla Weekly/Progreso (RF9).
4. Detalle/formulario de tarea (RF8) en tono final.
5. Pantalla de Ajustes y Categorías.
6. Estados transversales sin mockup (vacío, snackbars, diálogos, swipe-to-delete, loading).
7. Bottom navigation bar.
8. Paleta curada de categorías y regla del punto único.
9. Marca del rombo/gota de racha (StreakMark).
10. Logo/marca si P8 lo aprueba.

## Justificación de las decisiones principales

ThemeExtension en lugar de constantes estáticas: única opción que hace la corrección por brillo el comportamiento por defecto. Fábrica única de ThemeData: corrige la causa raíz de la divergencia actual entre temas. Providers derivados en lugar de persistir activeDays: mantiene el rediseño dentro de presentation/, evita tocar Hive/backup_codec. Faseo en tres bloques: separa lo desbloqueado de lo bloqueado por Aesthetic. Fuente empaquetada: coherencia con postura local-first. No renombrar applicationId ni paquete Dart: beneficio nulo, coste irreversible o desproporcionado.

## Recomendaciones para las siguientes etapas

1. Decision: resolver P1–P9 antes de abrir Implementation de Fase 2 en adelante.
2. Aesthetic: puede trabajar en paralelo a la Fase 1, cubriendo los 10 puntos listados con los mismos tokens semánticos como vocabulario común.
3. Implementation: restricciones duras — cero cambios en domain/ y calculadores de gamificación y adapters/typeIds de Hive; ningún widget nuevo con literal Color(0x...); SlateColors.of(context) con fallback obligatorio.
4. Verification: cada pantalla en ambos brillos y con escala de fuente aumentada; actualizar los 5 tests de widget afectados.
5. Marca: tratarla como pase de pipeline propio, posterior al sistema visual.

## Resultado

La arquitectura concentra el rediseño en un sistema de design tokens semánticos basado en ThemeExtension (lib/core/theme/) que sustituye el acceso estático a AppColors, ensamblado por una fábrica única de ThemeData para claro y oscuro. La gamificación se reestructura exclusivamente en presentation/, apoyándose en dos providers derivados de solo lectura que evitan cualquier cambio de dominio o persistencia: el rediseño completo no requiere ninguna migración de Hive ni cambio en go_router. La ejecución se fasea en: (1) infraestructura de tokens y tipografía, (2) pantalla Agenda, (3) resto de pantallas más gamificación reestructurada (bloqueada por Aesthetic). Quedan 9 puntos de decisión de producto (P1–P9), de los cuales P3 y P4 pueden provocar regresión funcional silenciosa si se implementa el mockup literalmente sin resolverlos.

## Addendum — P2 ampliado, P4 y P6

# Addendum de Arquitectura — Rediseño visual de slate-app (P2 ampliado, P4, P6)

Complementa el documento base. No repite sus decisiones A1–A7; añade A8, A9 y A10, nuevos riesgos RG13–RG19, y dos correcciones al documento base.

## A8 — P2 ampliado: rango horario en el tile de tarea

### Hallazgo bloqueante: el modelo NO soporta un rango

Verificado en lib/domain/entities/task.dart: Task tiene 15 campos y el único campo de hora-del-día es scheduledTime: DateTime?. No existe endTime, ni duration, ni nada de lo que derivar una hora de fin. Confirmado en los tres puntos de persistencia:
- lib/data/hive/adapters/task_adapter.dart — typeId = 0, escribe 15 campos (claves 0–14).
- lib/data/backup/backup_codec.dart — _taskToJson / _taskFromJson, schemaVersion = 1.
- lib/presentation/screens/task_form/task_form_sheet.dart — un único TimeOfDay _selectedTime.

Matiz relevante: scheduledTime es un DateTime completo cuyo componente de día no es autoritativo. reminder_schedule_calculator.dart documenta explícitamente que combina el día de scheduledDate con la hora de scheduledTime, porque en ocurrencias recurrentes scheduledTime conserva el día del padre. Cualquier campo nuevo de tiempo hereda esta trampa.

Conclusión: mostrar "1pm - 2pm" no es un cambio de presentación. Requiere un campo nuevo en la entidad Task, lo que rompe la restricción "cero cambios en domain/" fijada en A3. Se escala como decisión del usuario (P10).

### Opciones (P10)

Opción 1 (recomendada) — añadir int? durationMinutes a Task. El fin se deriva: inicio(scheduledDate@scheduledTime.timeOfDay) + durationMinutes. Por qué duración y no hora de fin: (a) no reintroduce un DateTime con componente de día engañoso; (b) es invariante frente al mecanismo de copia de ocurrencias recurrentes; (c) validación trivial (>0); (d) un solo int nullable en Hive.

Opción 2 — añadir DateTime? endTime. Simétrico con scheduledTime pero arrastra el problema del día no autoritativo. Rechazada salvo instrucción contraria.

Opción 3 (sin tocar el modelo) — duración fija de presentación (ej. siempre 1h). Coste cero pero muestra información que la app no posee. No recomendada.

Opción 4 (sin tocar el modelo) — renunciar al rango, mantener una sola hora movida debajo del título. Único implementable sin cambio de modelo.

### Alcance de la Opción 1 (si se aprueba)

| Archivo | Cambio |
|---|---|
| lib/domain/entities/task.dart | Campo int? durationMinutes + copyWith + props |
| lib/data/hive/adapters/task_adapter.dart | writeByte(16), clave 15, lectura fields[15] as int? |
| lib/data/backup/backup_codec.dart | Clave opcional en _taskToJson/_taskFromJson |
| lib/application/providers/task_provider.dart | Parámetro en addTask/updateTask |
| lib/presentation/screens/task_form/task_form_sheet.dart | Afordancia nueva para fijar duración/fin |
| lib/presentation/widgets/task_tile.dart | Formateo del rango |
| test/data/backup/backup_codec*_test.dart | Cobertura del campo opcional |

Sin migración de Hive y sin subir schemaVersion. typeId sigue siendo 0; un registro escrito antes ignora la clave 15 (?? null), y una build anterior que lea un registro nuevo ignora la clave desconocida. Precedente de claves 13/14 ya documentado. RG1 se respeta.

Sin backfill: tareas existentes quedan con durationMinutes == null. El tile renderiza rango cuando hay duración y hora simple cuando no.

Fuera de alcance explícito: la hora de fin no genera un segundo recordatorio (reminder_manager.dart y reminder_schedule_calculator.dart siguen usando solo scheduledTime), no altera el orden de tasksWithTimeProvider, no introduce detección de solapamientos.

### Sub-decisión de formato

DateTimeExtensions.formattedTime es 24h ("13:00"). El mockup escribe "1pm - 2pm" (12h inglés) en app en español. Recomendación: formateador de rango en presentación usando MaterialLocalizations.formatTimeOfDay respetando alwaysUse24HourFormat del dispositivo, sin tocar la extensión actual. Alternativa aceptable: 24h fijo. No recomendado: hardcodear 12h en inglés.

## A9 — P4: auto-reclamo de la quest, como efecto externo al dominio

### Principio estructural

QuestNotifier.claim() y QuestCalculator no se tocan. El auto-reclamo se implementa como un efecto observador en application/providers/, no como cambio de comportamiento del notifier.

Verificado: test/application/providers/quest_provider_test.dart (16 tests) sigue pasando sin modificación, incluido 'reclamar exige acción explícita: sin claim no hay XP' — el notifier sigue exigiendo llamada explícita; ahora la hace el efecto, no el usuario.

### Mecanismo

Nuevo archivo lib/application/providers/quest_auto_claim.dart con dos proveedores:

1. questRewardLevelUpProvider — StateProvider<int?>: canal de evento con el nivel alcanzado o null. Basta un int? sin secuencia porque PlayerProfile.shownLevelUps garantiza que cada nivel se emite como level-up nuevo a lo sumo una vez, y el nivel nunca decrece.

2. questAutoClaimProvider — Provider<void> con ref.listen<QuestState>(questProvider, ..., fireImmediately: true).
- Qué observa: QuestState (no tasksProvider/dailyProgressProvider directamente; questProvider ya se refresca ante ambos).
- Cuándo dispara: cuando next.canClaim == true.
- fireImmediately: true es obligatorio: QuestNotifier ejecuta _sync() en su constructor antes de que exista oyente; sin esto, un arranque en frío con quest ya cumplida no otorgaría nunca el premio.
- Acción: ref.read(questProvider.notifier).claim(); si devuelve nivel no nulo, lo escribe en questRewardLevelUpProvider.

3. Anti-duplicado en tres capas:
- Persistente: companionState.questClaimedOn == todayKey (ya existe).
- Reentrante: claim() termina llamando a _sync(), que pone isClaimed = true.
- Concurrente (nueva): el efecto guarda el Future en curso y no lanza un segundo claim() mientras haya uno pendiente.

### Suscripción de mantenimiento (requisito no negociable)

questProvider no es autoDispose pero sí perezoso; hoy su único consumidor es QuestCard. Al retirar QuestCard de Home (Fase 2), nadie lo observa y la quest deja de existir de hecho (RG8).

Por tanto: NavigationShell pasa de StatelessWidget a ConsumerWidget con dos responsabilidades nuevas: ref.watch(questAutoClaimProvider) (mantiene vivo el efecto) y ref.listen(questRewardLevelUpProvider, ...) → showLevelUpSnackBar y reseteo a null tras mostrarlo. Se elige NavigationShell (no app.dart) por ser el nodo más alto con Scaffold cubriendo todas las pestañas. El listener de task_section.dart se mantiene (level-up de toggleComplete, distinto origen).

### Impacto en tests

- quest_provider_test.dart — pasa sin cambios (recomendado renombrar el test de 'reclamar exige acción explícita' para reflejar el invariante de unidad).
- quest_calculator_test.dart — sin cambios.
- quest_card_test.dart — se elimina junto con quest_card.dart.
- Test nuevo recomendado: con 3 tareas completadas, XP pasa de 0 a 25 sin invocar claim() manualmente; un segundo ciclo no vuelve a sumar; questRewardLevelUpProvider recibe el nivel exactamente una vez al cruzar nivel nuevo.

## A10 — P6: fusión de Weekly y Stats

### Ruta

Una sola ruta /progress sustituye a /weekly y /stats en lib/presentation/navigation/app_router.dart. No se mantiene ninguna de las dos antiguas como principal. Verificado que no hay enlaces profundos, ni ruta persistida, ni context.go('/stats') fuera de navigation_shell.dart. El redirect de /weekly y /stats → /progress es opcional pero recomendado (coste nulo).

### Navegación

NavigationShell pasa de 4 a 3 destinos: Hoy (/home), Progreso (/progress), Ajustes (/settings). Se reasignan índices 0/1/2. app_theme.dart ya fija type: BottomNavigationBarType.fixed explícitamente en ambos temas, así que bajar a 3 ítems no cambia implícitamente el tipo. La fábrica única de ThemeData de A1 debe preservar ese type explícito. Iconos de Aesthetic.

### Ubicación y composición

Nuevo directorio lib/presentation/screens/progress/ con progress_screen.dart (ProgressScreen). Se trasladan a progress/widgets/ los cinco widgets hoy en screens/stats/widgets/: player_card.dart, badge_vault.dart, badge_presentation.dart, streak_display.dart, monthly_calendar.dart. Se eliminan screens/weekly/ y screens/stats/. Coste: churn de imports en 5 archivos de lib/ y 4 de test, sin cambios de aserciones.

Organización: scroll único, sin tabs internos. Razones: (a) tabs reconstruirían la separación que la fusión elimina; (b) son cinco bloques, no cinco pantallas; (c) narrativa continua; (d) evita TabController. Orden estructural propuesto (tratamiento visual de Aesthetic):
1. Cabecera de la pantalla.
2. Racha (StreakDisplay restilizado, con StreakMark de A3).
3. Progreso semanal: navegación de semana + barra de porcentaje.
4. Resumen por día de la semana.
5. Calendario mensual (MonthlyCalendar).
6. Perfil: nivel + XP (PlayerCard restilizado, sin rango E→S por P5).
7. Insignias (BadgeVault).

Dos widgets de fila semanal conviven a propósito y no se fusionan: week_activity_row.dart de Home (A3) es binario activo/inactivo, el bloque 4 de Progreso es porcentaje por día navegable. Semánticas distintas.

Lógica de cálculo: _calculateWeeklyProgress y _getWeekDays (hoy privados en weekly_screen.dart) deben extraerse a los widgets de sección correspondientes o a un provider derivado de solo lectura.

Advertencia de acoplamiento preexistente: la navegación de semanas escribe en selectedDateProvider, el mismo que gobierna el selector de fecha de Home. Cambiar de semana en Progreso cambia el día seleccionado en Hoy. Comportamiento actual, no se cambia en este rediseño.

## Nuevos riesgos

| # | Riesgo | Impacto | Mitigación |
|---|---|---|---|
| RG13 | El rango horario obliga a un campo nuevo en Task, rompiendo "cero cambios en domain/" de A3 | Medio | Cambio aditivo, nullable; typeId y schemaVersion intactos; requiere aprobación explícita (P10) |
| RG14 | Recompensa silenciosa: con auto-reclamo y sin QuestCard, el +25 XP se otorga sin feedback y el umbral de 3 no aparece en ninguna parte | Alto en percepción | Requiere decisión P11 |
| RG15 | questProvider queda sin suscriptores al retirar QuestCard → la quest deja de construirse y muere en silencio | Alto (regresión silenciosa) | ref.watch(questAutoClaimProvider) en NavigationShell obligatorio |
| RG16 | Un level-up cruzado por los +25 XP se marca en shownLevelUps sin llegar a mostrarse | Medio (pérdida irreversible del aviso) | Canal questRewardLevelUpProvider + oyente en NavigationShell |
| RG17 | Doble reclamo en la ventana await de claim() al automatizar el disparo | Bajo-medio | Guard de serialización en el efecto |
| RG18 | Traslado de stats/widgets/ → progress/widgets/ toca imports de 4 tests | Bajo | Cambio mecánico, sin tocar aserciones |
| RG19 | selectedDateProvider compartido entre Home y Progreso | Bajo, preexistente | Documentado; no se modifica en este rediseño |

## Correcciones al documento base

1. Hallazgo 6/RG4: test/widget_test.dart NO está acoplado a la gamificación (solo prueba DateTimeExtensions.relativeDay). El conjunto real de tests de widget afectados es: quest_card_test.dart (se elimina), player_card_test.dart, badge_vault_test.dart, badge_presentation_test.dart, monthly_calendar_test.dart.
2. RG9 decía que la navegación solo se rompe "si se consolidan Weekly y Stats". Con P6 confirmada, RG9 se activa y queda resuelto por A10; su severidad se mantiene baja al no haber enlaces profundos.

## Requiere decisión adicional del usuario ANTES de Implementation

- P10 (bloqueante parcial) — ¿Se añade un campo a Task para soportar el rango horario? Opción 1 recomendada (int? durationMinutes, sin backfill, sin migración). Alternativa sin costo: Opción 4 (una sola hora). Incluye sub-decisión de formato (12h localizado vs 24h fijo). Alcance del bloqueo: solo la fila de hora de task_tile.dart y el campo nuevo de task_form_sheet.dart; el resto de la Fase 2 está desbloqueado y puede empezar ya.
- P11 (no bloqueante, pero debe resolverse antes de cerrar Fase 2) — ¿Qué feedback recibe el usuario cuando la quest se auto-reclama? Opciones: (a) silencio total; (b) estado de "meta diaria cumplida" en DailyProgressCard (recomendada, forma de Aesthetic); (c) SnackBar de "+25 XP". El umbral de 3 tareas que gobierna la quest no se muestra en ninguna superficie del nuevo diseño; cambiarlo o hacerlo visible es decisión de producto — QuestCalculator.requiredCompletions sigue congelado.

## Resultado

P2 ampliado escala a un campo nuevo en Task (int? durationMinutes recomendado, aditivo, sin migración de Hive ni subida de schemaVersion), requiere aprobación explícita (P10). P4 se resuelve con un efecto observador questAutoClaimProvider en application/providers/ que escucha QuestState.canClaim con fireImmediately, invoca el claim() existente sin modificar QuestNotifier ni QuestCalculator, se protege del doble reclamo en tres capas, y publica los level-up por un canal que NavigationShell consume — con la advertencia crítica de que sin una suscripción de mantenimiento en el shell la quest muere en silencio al retirar QuestCard. P6 se resuelve con una ruta única /progress, tres destinos en la bottom nav, un nuevo directorio screens/progress/ que absorbe los widgets de stats/widgets/, y una organización de scroll único en siete bloques sin tabs internos. Añade los riesgos RG13–RG19 y deja abiertos exactamente dos puntos de decisión, P10 y P11, de los cuales solo P10 bloquea —y parcialmente— la Fase 2.

## Addendum 2 — P10 resuelta: hora de fin obligatoria y detección de solapamiento

# Addendum 2 de Arquitectura — slate-app (P10 resuelta: hora de fin obligatoria + detección de solapamiento)

## Hallazgos nuevos en el código

H-A. domain/ en este proyecto NO contiene lógica. lib/domain/ solo tiene entities/, enums/ y repositories/ (interfaces). Toda la lógica pura vive en lib/application/services/ (StreakCalculator, QuestCalculator, PlayerXpCalculator, ReminderScheduleCalculator, FortnightCalculator). Consecuencia: el validador de solapamiento va en application/services/, no en domain/. El delta total en domain/ sigue siendo exactamente un campo en Task.

H-B (defecto preexistente, no introducido por el rediseño). En lib/application/providers/task_provider.dart, tasksBySelectedDateProvider ordena con a.scheduledTime!.compareTo(b.scheduledTime!). scheduledTime es un DateTime completo cuyo día no es autoritativo: en ocurrencias recurrentes conserva el día de la raíz. Por tanto una ocurrencia recurrente creada el 2026-01-01 a las 09:00 siempre se ordena antes que una tarea puntual de hoy a las 08:00. Bug real, visible hoy, independiente del rediseño. TaskScheduleCalculator.effectiveStart (ver A11) lo corrige con coste cero si se adopta; decisión de corregirlo requiere visto bueno del Orquestador (cambia el orden visible de la agenda).

H-C. El borrado no revierte XP. TasksNotifier.deleteTask no invoca a PlayerNotifier en ningún caso. Borrar una tarea completada conserva su XP. Preexistente, relevante para A13/A14.

## A11 — Hora de fin: obligatoria en el punto de escritura, nullable en el modelo

Se mantiene int? durationMinutes en Task (Opción 1 de A8), pero la obligatoriedad pedida por el usuario se implementa como invariante de escritura, no como no-nulidad de tipo.

Invariante I1: toda tarea guardada a través del formulario con hora de inicio tiene durationMinutes != null && durationMinutes > 0. Obligatoria cuando la tarea tiene hora de inicio; una tarea sin inicio no puede tener fin (se conserva "Sin horario").

Por qué el campo NO es int no-nullable en la entidad: (1) no-nullable obligaría a un backfill inventado (ej. fields[15] ?? 60) que contaminaría el detector de solapamiento generando conflictos falsos en series recurrentes de 365 instancias; (2) tareas sin horario y subtareas no tienen valor honesto; (3) respeta RG1 (cero migraciones Hive): typeId sigue 0, schemaVersion sigue 1.

Por qué se mantiene "duración" y no DateTime endTime (re-evaluado con el campo obligatorio): con durationMinutes > 0 el fin es siempre ≥ inicio por construcción (con endTime habría que validar end > start en todas las vías de escritura); cruce de medianoche sin ambigüedad (23:30 + 60min es inequívoco); invariante frente a la recurrencia (copyWith(scheduledDate: nextDate) propaga la duración correctamente, mientras endTime arrastraría el mismo problema de día no autoritativo que scheduledTime); la representación de almacenamiento no tiene que igualar al selector de UI (el TimePicker de fin se convierte a minutos en el formulario, mapeo de 2 líneas).

Política de backfill: NINGUNO. Tareas existentes quedan con durationMinutes == null, se renderizan con hora simple, quedan fuera de la detección de solapamiento (sin fin conocido no hay rango). Autosanación: al editar una tarea legacy en el formulario, I1 la obliga a tener fin.

Pieza nueva: lib/application/services/task_schedule_calculator.dart (calculador puro, sin Riverpod, mismo patrón que ReminderScheduleCalculator):
- DateTime? effectiveStart(Task) — null si scheduledTime == null; si no, día de scheduledDate + hora/minuto de scheduledTime.
- DateTime? effectiveEnd(Task) — effectiveStart + durationMinutes; null si falta cualquiera.
- TaskTimeRange? effectiveRange(Task) — value object {start; end}, semántica [start, end). null para sin horario/subtareas/legacy sin duración.

Refactor de coherencia recomendado (sin cambio de comportamiento): ReminderScheduleCalculator.effectiveDateTime(task) => TaskScheduleCalculator.effectiveStart(task) ?? task.scheduledDate.

Sub-decisiones de formulario: prefijar fin = inicio + 60 min al elegir inicio; end ≤ start se interpreta como cruce de medianoche ((fin−inicio) mod 1440), tope <24h, rechazar solo duración == 0; "Sin hora" limpia inicio y duración a la vez.

Delta de archivos (además de la tabla de A8): task_schedule_calculator.dart (nuevo), reminder_schedule_calculator.dart (effectiveDateTime delega, sin cambio de comportamiento), task_provider.dart (addTask recibe int? durationMinutes, assert de I1 en debug), task_schedule_calculator_test.dart (nuevo).

## A12 — Detección de solapamiento

Decisión estructural: el no-solapamiento NO es un invariante del modelo de datos, es una guarda en el punto de intención del usuario. Consecuencias: no hay que validar/reparar en backup_codec al restaurar, ni en _generateRecurringTasks, ni en el repositorio; no hace falta flag "force" en TasksNotifier; datos solapados preexistentes o de restore son válidos y se muestran sin drama.

Dónde vive, en tres capas:
1. lib/application/services/task_overlap_detector.dart — calculador puro, sin Riverpod. Define "solapamiento".
2. lib/application/providers/task_overlap_provider.dart — Provider<TaskOverlapQuery>, ref.watch(tasksProvider), índice por día precomputado.
3. task_form_sheet.dart — invoca la consulta en _saveTask() antes de llamar al notifier, muestra el diálogo.

Por qué en el formulario y no en TasksNotifier: resolver el conflicto exige decisión del usuario vía diálogo; precedente exacto: la validación de "título vacío" ya vive en _saveTask(). Reparto: application define y calcula la regla, presentation decide con el usuario, application escribe. domain/ no participa (H-A); el delta en domain/ sigue siendo un único campo en Task.

Definición de solapamiento: A y B se solapan si y solo si (1) ambas tienen rango resoluble (effectiveRange != null) y (2) A.start < B.end && B.start < A.end (intervalos semiabiertos [start,end), 13:00-14:00 y 14:00-15:00 NO son conflicto). Se comparan instantes absolutos, no horas del día (resuelve cruce de medianoche gratis; ventana de candidatos D-1, D, D+1). Los rangos se construyen siempre con effectiveStart, nunca leyendo scheduledTime directamente.

Exclusiones del conjunto de candidatos: tarea sin horario (nunca conflictúa), subtareas (nunca tienen scheduledTime propio), legacy sin durationMinutes (sin fin conocido no hay rango), la propia tarea en edición (por id), toda la serie de la tarea en edición (raíz + parentTaskId == raíz, evita falsos conflictos con ocurrencias viejas de la misma serie), tareas completadas (recomendado: son hechos históricos, no compromisos; además prerrequisito del anti-exploit RG23).

Recurrencia: horizonte de comprobación = 35 días (mínimo que garantiza evaluar al menos una ocurrencia de cada tipo de recurrencia soportado, incluido monthly). Se reporta solo el PRIMER conflicto cronológico (TaskConflict?). Prerrequisito no negociable: extraer la regla de fechas de recurrencia a lib/application/services/recurrence_calculator.dart → List<DateTime> occurrenceDates({required DateTime base, required RecurrenceType recurrence, List<int>? recurrenceDays, required int days}), con la misma semántica del bucle actual. _generateRecurringTasks pasa a consumirla con days:365; el detector con days:35. Si detector y generador divergieran en la regla, el detector diría "sin conflicto" y el generador crearía la ocurrencia que colisiona (RG20 original, renombrado en este documento).

Contrato:
```
TaskTimeRange { DateTime start; DateTime end; }  // [start, end)
TaskDraftSchedule { DateTime scheduledDate; TimeOfDay? startTime; int? durationMinutes; RecurrenceType recurrence; List<int>? recurrenceDays; }
TaskConflict { String taskId; String title; DateTime start; DateTime end; DateTime occurrenceDate; bool isRecurringOccurrence; }

final taskOverlapQueryProvider = Provider<TaskOverlapQuery>(...);
abstract class TaskOverlapQuery {
  TaskConflict? findFirstConflict(TaskDraftSchedule draft, {String? editingTaskId});
}
```
Uso en _saveTask(): null => flujo actual sin cambios; conflicto => se muestra el diálogo. TaskOverlapQuery como interfaz para poder sobrescribir el provider en tests de widget con un doble trivial.

Indexado: TaskOverlapQuery precomputa un Map<DateKey, List<TaskTimeRange+meta>> sobre tareas con rango resoluble al construirse; se reconstruye cuando tasksProvider cambia, no en cada guardado.

## A13 — PENDIENTE en su momento (P12): semántica de "sustituir" — resuelta después en Addendum 3 (A14)

Se dejaron instrumentadas 3 interpretaciones: (a) destructiva (borrar tarea en conflicto, con matiz de que deleteTask no revierte XP de tareas completadas — RG23), (a2) no destructiva (desprogramar la tarea en conflicto a "Sin horario"), (b) no destructiva (solo advertir, "Guardar de todos modos"). Recomendación transversal: el conflicto debe ser siempre anulable ("Guardar de todos modos" presente en las tres variantes). Ver Addendum 3 (A14) para la resolución final, que fue una cuarta opción no listada aquí.

## Riesgos (Addendum 2)

| # | Riesgo | Impacto | Mitigación |
|---|---|---|---|
| RG13 (actualizado) | Campo nuevo en Task rompe "cero cambios en domain/" | Medio | P10 aprobada; delta cerrado: un solo campo; el solapamiento no lo amplía (H-A) |
| RG20 (original) | El detector proyecta ocurrencias con regla distinta a _generateRecurringTasks → aprueba un guardado que generará colisiones | Alto | Extraer RecurrenceCalculator.occurrenceDates y consumirla desde ambos |
| RG21 | Tareas legacy sin duración quedan fuera de la detección | Medio, decreciente | Autosanación al editar; el diálogo no debe prometer "sin conflictos" |
| RG22 | El no-solapamiento no es invariante: restore/generación/escrituras directas pueden producir datos solapados | Bajo, por diseño | No añadir lógica de reparación en backup_codec/repositorio |
| RG23 | Si "sustituir" borra una tarea completada, el XP no se revierte (H-C) → exploit de un toque | Alto si se elige (a) sin salvaguarda | Excluir completadas del detector |
| RG24 | Hora de fin obligatoria añade fricción al alta rápida | Bajo-medio | Prefijar fin = inicio+60min; "Sin hora" sigue siendo un toque |
| RG25 | Rangos que cruzan medianoche | Bajo | Comparación por instantes absolutos + ventana D-1/D+1; marca visual (Aesthetic) |

Impacto en recordatorios: ninguno funcional. reminder_manager.dart sin cambios; reminder_schedule_calculator.dart sin cambio de comportamiento (solo delega opcionalmente en TaskScheduleCalculator.effectiveStart).

Estado de bloqueo en su momento: campo durationMinutes/adapter/backup_codec/TaskScheduleCalculator desbloqueado; fin obligatorio en formulario y tile desbloqueado; RecurrenceCalculator desbloqueado; TaskOverlapDetector/taskOverlapQueryProvider desbloqueado; diálogo de conflicto y sus acciones bloqueado por P12 (resuelto luego en A14); corrección de ordenación H-B bloqueada por decisión del Orquestador (pendiente, no bloquea el resto).

## Addendum 3 — A14: P12 resuelta con la semántica "truncar"

# Addendum 3 de Arquitectura — A14: P12 resuelta con la semántica "c — truncar"

## 1. Verificación del supuesto crítico: CONFIRMADO

Cada ocurrencia de una serie recurrente es un registro Task individual y persistido en Hive, con id propio y parentTaskId apuntando a la raíz. No hay cálculo dinámico ni proyección en memoria. Evidencia en lib/application/providers/task_provider.dart: _generateRecurringTasks (líneas 174-231) materializa la serie en el momento de la creación (bucle de 365 días, task.copyWith(id: nuevo, scheduledDate: nextDate, parentTaskId: task.id), escritura real vía _repository.add). Único llamador: addTask. updateTask no la invoca ni propaga a otras ocurrencias (solo propaga en el caso de invariante de fecha subtarea↔principal, que no aplica a ocurrencias recurrentes: isSubtask == false para ellas). deleteTask vs deleteTaskAndRecurring confirman el modelo de registros individuales.

Conclusión: no hace falta tabla de excepciones de recurrencia. Truncar la ocurrencia del día X es un updateTask normal sobre esa entidad; los días siguientes conservan su duración original automáticamente. Vale igual si la ocurrencia en conflicto es hija o raíz de la serie (la raíz tampoco propaga hacia las hijas).

Limitación preexistente anotada: la serie solo existe 1 año; conflictos más allá de 365 días no son detectables porque la ocurrencia aún no existe.

## 2. Flujo del diálogo con la semántica "truncar"

Acción: "Acortar «{título de X}»" (con subtexto del rango resultante), sustituye a "Sustituir". Las interpretaciones (a) borrar y (a2) desprogramar quedan descartadas.

Acciones del diálogo por conflicto: (1) Acortar «X» — solo si canTruncate; (2) Guardar de todos modos — deja el solapamiento (equivale a la interpretación b, se conserva como escape); (3) Cancelar.

Condición canTruncate: X.startMinuteOfDay < Y.startMinuteOfDay. Si Y empieza a la vez o antes que X, truncar daría duración <=0 (no representable); en ese caso el diálogo no ofrece "Acortar", solo "Guardar de todos modos" y "Cancelar".

Cálculo: nuevaDuración = minutosDelDía(Y.scheduledTime) − minutosDelDía(X.scheduledTime), usando solo el componente hora-del-día (nunca la fecha), por la misma trampa de scheduledTime en recurrentes ya documentada en A8/A11.

Llamada exacta: releer X del repositorio por conflict.taskId (nunca aplicar copyWith sobre el snapshot del diálogo, para no resucitar campos obsoletos como isCompleted), luego updateTask(actual.copyWith(durationMinutes: nuevaDuración)). Ningún otro campo cambia: scheduledTime/scheduledDate de X se mantienen. Esto es idempotente para el recordatorio (mismo id, misma hora de inicio) y no dispara regeneración de textos temáticos con IA (la clave de caché usa el título normalizado, que no cambia).

Interacción con el detector: NO requiere re-chequeo. Justificación formal: el truncamiento conserva el inicio y reduce el fin (X' ⊆ X); si X' solapara con otra tarea Z, X también lo habría hecho — el truncamiento no puede crear conflictos nuevos, solo resolver o conservar los preexistentes. Si Y conflictúa con varias tareas, cada conflicto se resuelve por separado (su propio canTruncate y nuevaDuración); Y se guarda solo cuando todos los conflictos tienen acción elegida.

## 3. Tareas completadas: A14 no aplica

Confirmado: A12 excluye completadas del detector, así que una X completada nunca se ofrece para truncar. Guarda defensiva de coste nulo: si al releer X por id resulta isCompleted == true, la acción se aborta silenciosamente y Y se guarda igual (cubre la ventana entre detección y confirmación).

## 4. Contrato de A12: ampliación mínima

TaskConflict se amplía con dos campos derivados (no datos nuevos de origen): canTruncate: bool (X.start < Y.start) y truncatedDurationMinutes: int? (duración resultante precalculada, null si !canTruncate). Ambos derivados puros, precalculados en el detector, no en el widget del diálogo. No se requiere ningún campo de recurrencia adicional (isRecurringOccurrence, parentTaskId): la acción es idéntica para tarea suelta, ocurrencia hija o raíz de serie, porque updateTask no propaga en ninguno de los tres casos.

Riesgo nuevo:

| # | Riesgo | Impacto | Mitigación |
|---|---|---|---|
| RG20 (A14) | Truncar es una escritura destructiva sobre un dato del usuario (fin original de X), sin deshacer | Medio | Label debe nombrar el efecto y el rango resultante, no decir "Sustituir"; recomendado: SnackBar con acción "Deshacer" que restaure la duración previa (segundo updateTask, sin costo estructural) |

## 5. Estado de P12 y disposición para Implementation

P12 queda resuelta. La semántica "truncar" es implementable tal cual, sin mecanismos adicionales; el supuesto que la sostenía quedó verificado en código, no asumido. P1-P12 resueltos (P11 ya había sido resuelto por el usuario con la opción b). Fase 1 (infraestructura de tokens) y Fase 2 (Agenda, incluyendo durationMinutes, detector de solapamiento y diálogo con truncamiento) quedan completamente desbloqueadas para Implementation. Fase 3 sigue esperando definición de Aesthetic, como ya establecía A6.

Nota operativa: el Orquestador adoptó la recomendación de ofrecer "Deshacer" tras truncar (RG20 de este addendum).
