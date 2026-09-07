# Slate — Gestión de tareas con gamificación

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44.1-blue?style=flat-square&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12.1-blue?style=flat-square&logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/State-Riverpod-green?style=flat-square" alt="Riverpod">
  <img src="https://img.shields.io/badge/Storage-Hive-orange?style=flat-square" alt="Hive">
  <img src="https://img.shields.io/badge/Platform-Android-green?style=flat-square&logo=android" alt="Android">
  <img src="https://img.shields.io/badge/Tests-312%20passing-brightgreen?style=flat-square" alt="Tests">
  <img src="https://img.shields.io/badge/Analyze-0%20issues-brightgreen?style=flat-square" alt="Analyze">
</div>

---

## 🎯 Highlights técnicos

- **Clean Architecture por capas** (`core` / `domain` / `data` / `application` / `presentation`) con inversión de dependencias vía interfaces de repositorio y estado gestionado con Riverpod.
- **Offline-first real**: toda la persistencia vive en Hive; la app funciona al 100% sin conexión y no depende de ningún backend.
- **Cálculo derivado, no contadores mutables**: rachas, XP y quests se recalculan desde el historial (fuente de verdad) en lugar de mantenerse en campos acumulativos, evitando bugs clásicos de desincronización entre estado y datos.
- **Rendimiento medido y optimizado**: el borrado de series recurrentes bajó de 8-12 s a **~2 s** gracias a una cancelación selectiva de recordatorios, y el cold start redujo el jank de 403 a 321 frames saltados.
- **Cobertura de tests significativa**: **312 tests** (`flutter test`) y **0 errores** de análisis estático (`flutter analyze`), incluyendo cobertura de calculadores puros, providers, adaptadores Hive y presentación.
- **Feature de IA con gating estricto**: la generación de textos con Gemini es opt-in (default OFF); con el toggle apagado, el servicio de IA **nunca se invoca**, ni siquiera en el path de disparo de notificaciones.

---

## 📱 Descripción

**Slate** es una aplicación gamificada de gestión de tareas para **Android** desarrollada con **Flutter**. Es **local-first**: todos los datos se guardan en el dispositivo (Hive) y funciona 100% sin conexión.

La app adopta una estética **System / Hunter / Dungeon** inspirada en "Solo Leveling" (ventanas de sistema, rangos, misiones y niveles), con textos y marca propios, sin copiar arte ni frases literales de la obra. Esta identidad es la **única** del producto: las notificaciones, las insignias y el sistema de progresión usan siempre la nomenclatura del Sistema (con textos generados por IA opcionales).

Versión mostrada en Ajustes: **v1.2.0** (constante de UI en `settings_screen.dart`, independiente del `version` de `pubspec.yaml`).

<!-- Capturas de pantalla / demo — pendiente de agregar -->

---

## ✨ Características principales

- ✅ **Gestión de tareas** — CRUD completo: fecha, horario opcional, notas, prioridad, categoría, estado completado
- 🔽 **Subtareas** — Tareas anidadas bajo una principal, con XP individual (+2) y arrastre al completar la principal
- 🔄 **Tareas recurrentes** — Diarias, semanales, por días específicos (p. ej. lunes-viernes) o mensuales, con ocurrencias generadas y **borrado en serie optimizado**
- 🗂️ **Categorías** — CRUD completo con colores
- 🎮 **Sistema de progresión** — Rangos E→S, XP, niveles y racha
- ⚔️ **Quests diarias** — "Completa 3 misiones hoy" con recompensa de +25 XP
- 🏅 **Insignias Hunter** — 9 hitos de racha [3, 7, 14, 21, 30, 60, 90, 180, 365 días] con nomenclatura de Cazador (El Despertar, Primera Llamada, ...)
- 🔔 **Notificaciones temáticas** — Recordatorios, resúmenes diarios, cierre de jornada, alerta de racha y resumen quincenal, con textos del "Slate System" (▶ ◇ ⚠ ◆)
- 🤖 **Textos con IA (opt-in)** — Variantes generadas con Gemini solo al guardar, con caché local y fallback sin red
- 🌗 **Temas** — Oscuro (por defecto) y Claro (el modo "Sistema" fue eliminado)
- 🧹 **Poda automática** — Las tareas pendientes de más de 45 días se eliminan para mantener la BD ligera
- 📱 **Pantallas** — Hoy, Progreso, Estadísticas y Ajustes

---

## 🗂️ Pantallas

1. **Hoy (Home)** — Vista del día con selector de fecha (±3 días), selector de semana, tarjetas "Con horario" / "Sin horario" y la **Daily Quest** en la parte superior
2. **Progreso** — Progreso semanal, **calendario mensual** (resalta hoy y los días con tareas, sin navegar al futuro) e **indicadores diarios** de la semana
3. **Estadísticas** — Layout vertical: **racha** (actual, mejor racha e insignias), **tarjeta de Jugador** (nivel, rango E→S y barra de XP) y **vitrina de insignias**
4. **Ajustes** — Usuario, zona horaria, hora de reset, notificaciones (margen, resúmenes, cierre de jornada), tema, textos con IA y categorías

---

## 🏗️ Arquitectura

La app sigue una **Clean Architecture** por capas, con el estado gestionado mediante **Riverpod** y la persistencia local con **Hive**.

```
lib/
├── core/                    # Constantes, theme, utils, extensions
├── domain/                  # Entities, enums, repository interfaces
├── data/                    # Hive boxes, adapters, repository implementations, backup
├── application/             # Riverpod providers + services (lógica de negocio pura)
└── presentation/            # Screens, widgets, navigation
```

### Estructura de Carpetas

```
lib/
├── core/
│   ├── constants/      # AppColors, AppTypography, AppSpacing
│   ├── theme/          # AppTheme (dark/light)
│   ├── utils/          # DateUtils, StringUtils
│   └── extensions/     # DateTime extensions
├── domain/
│   ├── entities/       # Task, Category, Badge, Streak, UserSettings,
│   │                   # PlayerProfile, CompanionState
│   ├── enums/          # TaskPriority, RecurrenceType, BadgeType,
│   │                   # AppThemeMode, PlayerRank, XpEventType
│   └── repositories/   # Interfaces abstractas
├── data/
│   ├── hive/
│   │   ├── adapters/   # Hive TypeAdapters (incl. PlayerProfile, CompanionState)
│   │   └── boxes/      # tasks, categories, badges, streaks, settings,
│   │                   # thematic_text_cache, player_progress, companion_state
│   ├── backup/         # BackupService, BackupCodec, BackupFileStore (sin UI)
│   └── repositories/   # Implementaciones concretas
├── application/
│   ├── providers/      # Riverpod StateNotifiers (tasks, streak, player, quest,
│   │                   # settings, notifications, backup, ...)
│   └── services/       # NotificationService, ReminderManager,
│   │                   # ReminderScheduleCalculator, DailyReminderController,
│   │                   # StreakCalculator, PlayerXpCalculator, QuestCalculator,
│   │                   # ThematicTextsResolver/Catalog/Generator, AIService,
│   │                   # FortnightCalculator, ...
└── presentation/
    ├── screens/        # Home, Weekly, Stats, Settings, Categories, TaskForm
    │   └── stats/widgets/  # BadgeVault, BadgePresentation, PlayerCard,
    │                       # StreakDisplay, MonthlyCalendar
    ├── widgets/        # TaskTile, QuestCard, StreakBadge, common/
    └── navigation/     # GoRouter configuration (app_router)
```

### Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Framework | Flutter (Dart SDK ^3.5.0 según `pubspec.yaml`) |
| State Management | flutter_riverpod / riverpod_annotation |
| Local Storage | Hive + hive_flutter (8 cajas + caja auxiliar `app_meta`) |
| Navigation | GoRouter |
| Notifications | flutter_local_notifications |
| Timezone | timezone |
| Permissions | permission_handler |
| IA (opt-in) | http + Gemini (clave en tiempo de compilación) |
| Utilidades | uuid, intl, equatable |
| Backup (capa de datos) | path_provider |

---

## ⚔️ Sistema de Gamificación

### XP, Nivel y Rango del Jugador

- Cada tarea completa otorga XP según su prioridad: **+10** (baja) · **+15** (media) · **+20** (alta). Desmarcar una tarea **resta** ese XP (simetría anti-exploit).
- Las **subtareas** otorgan **+2 XP** al marcarlas explícitamente (y lo restan al desmarcarlas). El arrastre de la principal NO otorga XP individual.
- Curva de niveles: `100 · (nivel−1)²` XP totales (nivel 2 = 100 XP, nivel 3 = 400, ...).
- El **nivel es irreversible**: aunque el XP baje al desmarcar, el nivel alcanzado nunca retrocede. El nivel 1 es el backfill de arranque (0 XP).
- **Rango E→S** derivado del nivel: 1-9 E · 10-19 D · 20-29 C · 30-49 B · 50-69 A · 70+ S.
- Cada transición de nivel se muestra una sola vez (SnackBar "◆ Nivel subió").

### Quests (misiones diarias)

- La **Daily Quest** "Completa 3 misiones hoy" aparece en Hoy **solo si hay ≥3 tareas programadas para hoy** (decisión tomada una vez por día y persistente).
- Se reclama con acción explícita y otorga **+25 XP** una vez por día. Las tareas visibles y el conteo de completadas **no cuentan subtareas**.

### Rachas

- Una **racha** es la cadena de días consecutivos con **al menos una tarea completada**.
- Se calcula de forma **derivada** del historial (fuente de verdad), no con contadores.
- Al completar una tarea con fecha pasada se acredita su fecha programada; las tareas de hoy/futura se acreditan como hoy.
- Al desmarcar, la racha puede bajar, pero la **mejor racha histórica nunca baja**. Las subtareas no activan la racha.

### Insignias (tema Hunter)

Las insignias se desbloquean por hitos de racha y **no se pierden** al romper la racha (desbloqueo irreversible). Al subir la racha se desbloquean **todos** los umbrales alcanzados de una vez.

| Hito | Rango / Nivel | Apodo | Icono |
|------|---------------|-------|-------|
| 3 días | Rango E · Nivel I | El Despertar | 👁️ |
| 7 días | Rango E · Nivel II | Primera Llamada | 🔥 |
| 14 días | Rango D · Nivel I | Guía del acero | ⚔️ |
| 21 días | Rango D · Nivel II | Sangrado de ojos | 🛡️ |
| 30 días | Rango C · Nivel I | Fortaleza inquebrantable | 🎖️ |
| 60 días | Rango B · Nivel I | Guerrero del tiempo | 🏆 |
| 90 días | Rango A · Nivel I | Élite Nacional | 💠 |
| 180 días | Rango S · Nivel I | Honor Absoluto | 💎 |
| 365 días | Nivel Nacional | Leyenda | ☠️ |

La presentación está **centralizada** en `BadgePresentation` y usa únicamente la nomenclatura del Slate System (la IA personalizada de insignias fue eliminada).

---

## 🔔 Sistema de Notificaciones

Basado en `flutter_local_notifications` con `zonedSchedule` y la zona horaria configurada por el usuario.

### Recordatorios de tarea

- Se programa el aviso para tareas con horario, `hora − margen` (margen configurable en Ajustes; default **0** = a la hora exacta).
- El id se deriva de forma determinista del id de la tarea (FNV-1a, rango `[0x10000000, 0x4FFFFFFF]`).
- Se cancela al completar, borrar o perder el horario, y **nunca se programa un disparo en el pasado**.
- Las **series recurrentes** generan ~365 ocurrencias en BD, pero solo se programan notificaciones para las ocurrencias dentro del **horizonte de 7 días** (`recurringReminderHorizonDays`); el re-sync diario programa las que entran en la ventana. Esto evita saturar AlarmManager y el retraso histórico de 8-12 s al guardar (ahora ~2 s).

### Resúmenes diarios

- **10:00** (`0x60000001`): solo si hay tareas pendientes hoy.
- **19:00** (`0x60000002`): solo si hay tareas pendientes hoy y no se completó ninguna.

### Cierre de jornada

- **`0x60000003`**: notificación única **opt-in** (default OFF) con el resumen del día al día siguiente a la hora de reset (default 04:00).

### Otras notificaciones

- **Alerta de racha en peligro** (F2): si la racha activa es ≥3 días y no se ha completado ninguna misión hoy.
- **Resumen quincenal** (F3): reporte de la quincena (misiones completadas, racha, nivel, XP e insignias).

### Textos temáticos "Slate System"

- Los textos usan siempre la identidad del Sistema (glifos `▶ ◇ ⚠ ◆`): "Daily Quest" (recordatorio), "System Report" (resumen mañana), "Advertencia del Sistema" (resumen tarde), "System Report — Jornada completada" (cierre).
- **Textos con IA (opt-in, default OFF)**: genera variantes con Gemini **solo al guardar** una tarea o editar su título, las guarda en caché local (Hive) y usa el catálogo local como fallback si no hay red/API key.
- El resolver de textos es de **solo lectura**: la generación con IA nunca ocurre en el path de disparo de la notificación, y con el toggle OFF la IA nunca se invoca.

### Permisos y canal

- Permiso `POST_NOTIFICATIONS` solicitado en la **primera ejecución** (una sola vez) y mediante toggle en Ajustes.
- Alarmas **exactas** con fallback a inexactas si el permiso no se concede (`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` en el manifest).
- Canal único `task_reminders` con sonido, vibración y badge.

---

## 🧹 Mantenimiento de datos

### Poda automática (45 días)

Para mantener la base de datos ligera (una serie recurrente diaria genera ~365 instancias), la app ejecuta **una vez por sesión**, en segundo plano, una poda de tareas pendientes antiguas:

- **Solo** se podan tareas **NO completadas** con fecha programada anterior a `hoy − 45 días`.
- **Nunca** se podan tareas completadas (la racha, la mejor racha, el calendario y las quest dependen del historial) ni tareas de los últimos 45 días, de hoy o futuras.
- Al podar una principal pendiente se podan también sus subtareas pendientes que cumplan el criterio; una subtarea completada o con padre no podado no se toca.
- Se lanza en segundo plano tras la primera frame, para no bloquear el cold start.

### Borrado de series optimizado

`deleteTaskAndRecurring` sube desde cualquier ocurrencia a la **raíz** de la serie y borra la serie completa. La cancelación de recordatorios es **selectiva**: solo cancela la raíz y las ocurrencias dentro del horizonte de 7 días (las lejanas nunca tuvieron notificación), reduciendo el borrado de una serie de segundos a **~2 s**.

### Backups (importante)

La **UI de import/export JSON manual fue eliminada** de Ajustes. La capa de datos de backup (`lib/data/backup/`) sigue existiendo y está cubierta por tests, pero ya **no hay ningún punto de entrada en la interfaz**.

---

## ⚙️ Ajustes

- **Usuario** — Nombre del jugador.
- **Ubicación y Zona Horaria** — Detección automática (permiso de localización opcional) o zona manual.
- **Preferencias** — Hora de reset del día y notificaciones on/off.
- **Recordatorios** — Margen de aviso, resumen diario (mañana/tarde), cierre de jornada.
- **Apariencia** — Tema **Oscuro** / **Claro** (el modo "Sistema" fue eliminado; los datos persistidos con ese valor migran a oscuro) y **Textos con IA** (opt-in, con aviso de privacidad la primera vez).
- **Gestión** — Categorías.

---

## 🚀 Empezar

### Prerrequisitos

- Flutter SDK (stable). El proyecto declara `sdk: ^3.5.0` en `pubspec.yaml`.
- Android SDK (compileSdk, minSdk y targetSdk usan los valores por defecto del plugin Flutter Gradle) y JDK 17+.
- iOS: proyecto Xcode disponible (las notificaciones locales usan `DarwinInitializationSettings`).

### Variables de Entorno

Las funcionalidades de IA ("Textos con IA") son **opt-in y opcionales**. Para compilar con ellas, se inyecta la API key de Gemini en tiempo de compilación:

```bash
# Crear archivo .env.local con tu API key (ver .env.example)
echo "GEMINI_API_KEY=tu_api_key_aqui" > .env.local

# Compilar con la API key
flutter run --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
flutter build apk --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

Sin la API key la app compila y funciona igual: la IA queda deshabilitada y se usa el catálogo local de textos temáticos.

Obtén tu API key en: https://aistudio.google.com/app/apikey

### Instalación

```bash
# Clonar el repositorio
git clone https://github.com/Lmz-23/slate-app.git
cd slate-app

# Instalar dependencias
flutter pub get

# Ejecutar en modo debug (sin IA)
flutter run

# Ejecutar en modo debug (con IA opt-in)
flutter run --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY

# Compilar APK debug
flutter build apk --debug

# Compilar APK release
flutter build apk --release
```

---

## 🧪 Testing y Calidad

La suite de pruebas cubre la lógica pura (calculadores de racha, XP, quest y recordatorios), los providers, los adaptadores Hive, el backup y la presentación:

```bash
# Ejecutar toda la suite de tests
flutter test      # 312 tests

# Análisis estático
flutter analyze   # 0 errores
```

Los tests se organizan en `test/application`, `test/data` y `test/presentation`, con cobertura específica de: cálculo de rachas (incl. backfill y multiumbral), condición de quest (visibilidad/claim/25 XP), curva de XP y niveles, subtareas (XP, arrastre, invariante de fecha), recurrencia mensual, poda de 45 días, horizonte de recordatorios, cierre de jornada, textos temáticos y gating del opt-in de IA.

---

## 🕘 Estado actual / Historial reciente

- ✅ **Ronda de correcciones y optimización** — Eliminación del input por voz, mejoras de rendimiento (apertura paralela de cajas Hive, poda y recordatorios fuera del primer frame), insignias rediseñadas (identidad única Slate System) y tema corregido (eliminado el modo "Sistema").
- ✅ **Fijación de bugs** — Overflow de tarjetas en Estadísticas (layout vertical), quests dinámicas (visibilidad/re-cálculo al cambiar tareas), bloqueo de tareas futuras en el calendario y recordatorios nunca en el pasado, arrastre de subtareas y conservación exacta del XP.
- ✅ **Rendimiento** — Cold start reducido (jank de 403→321 frames saltados), borrado de series recurrentes en ~2 s (antes 8-12 s) y guardado recurrente sin bloqueos.
- ✅ **Ampliaciones recientes** — Sistema de XP/nivel/rango (F2), quest diaria + resumen quincenal (F3), subtareas + recurrencia mensual (F4), icono adaptativo.

---

## 🔮 Roadmap

### Fase 1 ✅ (Completada)
- Persistencia local con Hive
- Todas las pantallas core (Hoy / Progreso / Estadísticas / Ajustes)
- Gamificación (rachas + XP/niveles/rangos + insignias Hunter + quests)
- Sistema de notificaciones (recordatorios, resúmenes, cierre de jornada, alerta de racha, quincena)
- Identidad Slate System (textos temáticos + rangos/niveles de insignias) con IA opt-in
- Subtareas y recurrencias (diaria, semanal, días específicos, mensual)
- Poda automática de 45 días y borrado de series optimizado

### Fase 2 🔜 (Pendiente)
- Autenticación (email/password, Google Sign-In)
- Backend para sincronización
- Sync entre dispositivos
- Re-exponer backup/exportación en la UI
- Widget para iOS

---

## 🛠️ Notas de desarrollo

- Verificación local sobre emulador Android (API 35, x86_64) con `flutter test` y `flutter analyze` como puertas de calidad antes de integrar.
- El proyecto usa el NDK por defecto de Flutter (26.3); algunos plugins piden la 27.0 — es solo una advertencia y no bloquea el build debug.

---

## 📄 Licencia

Este proyecto es de código abierto con fines de **portafolio y demostración técnica**; su uso está pensado como proyecto personal y no está licenciado para redistribución comercial.
