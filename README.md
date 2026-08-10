# Slate - Task Management App with Streak Gamification

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44.1-blue?style=flat-square&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12.1-blue?style=flat-square&logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/State-Riverpod-green?style=flat-square" alt="Riverpod">
  <img src="https://img.shields.io/badge/Storage-Hive-orange?style=flat-square" alt="Hive">
  <img src="https://img.shields.io/badge/Platform-Android-green?style=flat-square&logo=android" alt="Android">
</div>

---

## 📱 Descripción

**Slate** es una aplicación de gestión de tareas diarias con gamificación por rachas. Es **local-first**: todos los datos se guardan en el dispositivo (Hive) y funcionan 100% sin conexión.

La app incluye un sistema de notificaciones completo (recordatorios de tarea, resúmenes diarios y cierre de jornada), rachas e insignias derivadas del historial, y una personalización estética **opcional** llamada **Slate System**, inspirada en la estética de "Solo Leveling" (ventanas de sistema, rangos y niveles) pero con textos y marca propios, sin copiar arte ni frases literales de la obra.

### Características Principales

- ✅ **Tareas con/sin horario** — CRUD completo: fecha, hora opcional, notas, prioridad y categoría
- 🔄 **Tareas recurrentes** — Series diarias, semanales o por días específicos, con ocurrencias generadas y borrado en serie
- 🎤 **Input por voz** — Speech-to-text para crear tareas rápidamente
- 🔥 **Sistema de rachas** — Días consecutivos con ≥1 tarea completada (no requiere completar todas); calculada del historial y recalculada al completar/desmarcar
- 🏅 **Insignias coleccionables** — 9 hitos de racha [3, 7, 14, 21, 30, 60, 90, 180, 365 días], desbloqueo irreversible
- 🔔 **Recordatorios de tarea** — Margen de aviso configurable (default 0: a la hora exacta)
- 📊 **Resúmenes diarios** — 10:00 y 19:00 con condiciones de producto (pendientes hoy / nada completado hoy)
- 🌙 **Cierre de jornada** — Resumen del día reportado al día siguiente (default 04:00), opt-in
- ⚙️ **Slate System** — Tema estético opt-in: textos temáticos de notificaciones y nomenclatura de rangos/niveles para insignias
- 🤖 **Textos con IA (opt-in)** — Variantes generadas con Gemini solo al guardar, con caché local y fallback sin red
- 📱 **Widget de inicio** — Accede a tus tareas desde la pantalla principal (Android)
- 🌗 **Temas** — Oscuro por defecto, claro y automático

---

## 🏗️ Arquitectura

La app sigue una arquitectura por capas, con el estado gestionado mediante Riverpod y la persistencia local con Hive.

```
lib/
├── core/                    # Constantes, theme, utils, extensions
├── domain/                  # Entities, enums, repository interfaces
├── data/                    # Hive boxes, adapters, repository implementations
├── application/             # Riverpod providers + services (lógica de negocio pura)
└── presentation/            # Screens, widgets, navigation
```

### Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Framework | Flutter (SDK Dart ≥ 3.5.0 según `pubspec.yaml`) |
| State Management | flutter_riverpod / riverpod_annotation |
| Local Storage | Hive + hive_flutter |
| Navigation | GoRouter |
| Speech-to-Text | speech_to_text |
| Notifications | flutter_local_notifications |
| Home Widget | home_widget |
| Timezone | timezone |
| Permissions | permission_handler |
| IA (opt-in) | http + Gemini (clave en tiempo de compilación) |
| Imágenes IA (opt-in) | image_picker |

---

## 🚀 Empezar

### Prerrequisitos

- Flutter SDK (stable). El proyecto declara `sdk: ^3.5.0` en `pubspec.yaml`.
- Android SDK (compileSdk y minSdk usan los valores por defecto del Flutter Gradle plugin) y JDK 17+.
- iOS: proyecto Xcode disponible; las notificaciones locales usan `DarwinInitializationSettings`.

### Variables de Entorno

Las funcionalidades de IA (textos temáticos y personalización de insignias/notificaciones) son **opt-in y opcionales**. Para compilar con ellas, se inyecta la API key de Gemini en tiempo de compilación:

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

### Estructura de Carpetas

```
lib/
├── core/
│   ├── constants/      # AppColors, AppTypography, AppSpacing
│   ├── theme/          # AppTheme (dark/light/auto)
│   ├── utils/          # DateUtils, StringUtils
│   └── extensions/     # DateTime extensions
├── domain/
│   ├── entities/       # Task, Category, Badge, Streak, UserSettings
│   ├── enums/          # TaskPriority, RecurrenceType, BadgeType, AppThemeMode
│   └── repositories/   # Interfaces abstractas
├── data/
│   ├── hive/
│   │   ├── adapters/   # Hive TypeAdapters (incl. UserSettingsAdapter)
│   │   └── boxes/      # tasks, categories, badges, streaks, settings, thematic cache
│   └── repositories/   # Implementaciones concretas
├── application/
│   ├── providers/      # Riverpod StateNotifiers (tasks, streak, settings, notifications...)
│   └── services/       # NotificationService, ReminderManager, StreakCalculator,
│                       # ReminderScheduleCalculator, ThematicTextsResolver/Catalog,
│                       # ThematicTextsGenerator, AIService, WidgetService, ...
└── presentation/
    ├── screens/        # Home, Weekly, Stats, Settings, Categories, TaskForm,
    │                   # BadgeCustomization, AINotificationSettings
    ├── widgets/        # TaskTile, StreakBadge, VoiceInputButton, common/
    └── navigation/     # GoRouter configuration (app_router)
```

---

## 🎮 Sistema de Gamificación

### Rachas

- Una **racha** es la cadena de días consecutivos con **al menos una tarea completada** (no es necesario completar todas las tareas del día).
- Se calcula de forma **derivada** a partir del historial de tareas completadas (fuente de verdad), no con contadores incrementales.
- Al completar una tarea con fecha pasada se acredita su fecha programada; las tareas con fecha hoy/futura se acreditan como hoy.
- El cálculo se **recalcula** al completar y al desmarcar: si el conjunto de días activos se reduce, la racha baja, pero la **mejor racha histórica nunca baja**.
- Un día con tareas completadas no "expira" la racha: permanece anclada al último día activo hasta la siguiente completación.

### Insignias

Las insignias se desbloquean por hitos de racha y **no se pierden** al romper la racha (desbloqueo irreversible).

| Hitos | Nombre | Icono |
|-------|--------|-------|
| 3 días | Primer Paso | ⭐ |
| 7 días | Semana Perfecta | 🔥 |
| 14 días | Quincena | ⚡ |
| 21 días | Hábito Formado | 🌸 |
| 30 días | Mes de Hierro | 🛡️ |
| 60 días | Doble Mes | 🏆 |
| 90 días | Trimestre | 👑 |
| 180 días | Medio Año | 💎 |
| 365 días | Leyenda | 🚀 |

Al subir la racha se desbloquean **todos** los umbrales alcanzados de una vez (p. ej. un backfill de historial); al bajar nunca se retiran.

La presentación de las insignias en la vitrina está **centralizada** en `BadgePresentation`, que resuelve nombre/icono con este orden: 1) configuración IA personalizada del usuario, 2) nomenclatura Slate System (si el tema está activo), 3) nombre/icono canónico (fallback por defecto).

---

## 🔔 Sistema de Notificaciones

Basado en `flutter_local_notifications`, con `zonedSchedule` y zona horaria configurada por el usuario.

### Recordatorios de tarea

- Se programa el aviso para tareas con horario, `hora - margen` (margen configurable en Ajustes; default **0** = aviso a la hora exacta).
- El id se deriva de forma determinista del id de la tarea (FNV-1a, rango `[0x10000000, 0x4FFFFFFF]`), por lo que reprogramar tras editar reemplaza la programación anterior.
- Se cancela al completar, borrar o perder el horario, y **nunca se programa un disparo en el pasado** (defensa documentada: cancelar es el lado seguro).

### Resúmenes diarios

- **10:00** (`0x60000001`): solo si hay tareas pendientes hoy.
- **19:00** (`0x60000002`): solo si hay tareas pendientes hoy y **no se ha completado ninguna tarea** en el día.
- Ambas horas son configurables en Ajustes y se cancelan si las notificaciones o el resumen diario están desactivados.

### Cierre de jornada

- **`0x60000003`**: notificación única **opt-in** (default OFF) que reporta el resultado del día al día siguiente a la hora de reset (default 04:00): completadas/total, pendientes, racha actual y hito alcanzado.

### Permisos y canal

- Permiso de notificaciones solicitado en la **primera ejecución** (una sola vez) y mediante toggle en Ajustes.
- Alarmas **exactas** con fallback a inexactas si el permiso no se concede (`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` en el manifest).
- Canal único `task_reminders` con sonido, vibración y badge según los ajustes del usuario; se recrea al cambiar los toggles.

---

## ⚙️ Slate System (personalización estética)

**Opt-in** (default OFF). Cuando está activo cambia los textos de las notificaciones y la nomenclatura de las insignias con una estética de "System" de cazadores y rangos (inspirada en Solo Leveling, con textos propios).

### Textos temáticos de notificaciones

- **Catálogo local** siempre disponible (glifos `▶ ◇ ⚠ ◆`): "Daily Quest" (recordatorio), "System Report" (resumen mañana), "Advertencia del Sistema" (resumen tarde), "System Report — Jornada completada" (cierre).
- **Textos con IA** (opt-in, default OFF): genera variantes con Gemini **solo al guardar** una tarea o editar su título, las guarda en caché local (Hive) y usa el catálogo local como fallback si no hay red/API key.
- El resolver de textos es de **solo lectura**: la generación con IA **nunca ocurre en el path de disparo** de la notificación.

### Nomenclatura de insignias (rangos/niveles)

| Hito | Rango | Apodo |
|------|-------|-------|
| 3 días | Rango E · Nivel I | Cazador Novato |
| 7 días | Rango E · Nivel II | Semana Perfecta |
| 14 días | Rango D · Nivel I | Aprendiz |
| 21 días | Rango D · Nivel II | Hábito Formado |
| 30 días | Rango C · Nivel I | Asedio Prolongado |
| 60 días | Rango B · Nivel I | Doble Asedio |
| 90 días | Rango A · Nivel I | Élite Nacional |
| 180 días | Rango S · Nivel I | Sobresaliente S |
| 365 días | Nivel Nacional | Leyenda |

---

## 🛡️ Privacidad

- **Local-first**: los datos (tareas, categorías, rachas, insignias, ajustes) se guardan en Hive en el dispositivo. Nada se envía a servidores.
- Las únicas funciones que salen del dispositivo son las **IA opt-in**:
  - "Textos con IA" envía el **título** de tus tareas a Google Gemini para generar los textos de notificaciones. La app muestra un **aviso informativo** la primera vez que se activa el toggle, y los textos generados se guardan en tu dispositivo.
  - "Estilo de notificaciones con IA" y "Personalizar insignias" también son opt-in y requieren acción explícita del usuario.
- Sin conexión o con los toggles desactivados no se envía nada y se usan los textos/valores locales.

---

## 🧪 Testing y Calidad

La suite de pruebas cubre la lógica pura (calculadores de racha y recordatorios), los providers, los adaptadores Hive y la presentación:

```bash
# Ejecutar toda la suite de tests
flutter test

# Análisis estático
flutter analyze
```

Estado reportado por el Pipeline: suite completa en verde (148/148) y `flutter analyze` sin errores. Los tests se organizan en `test/application`, `test/data` y `test/presentation`, con cobertura específica de: cálculo de rachas (R1a/R2a/R3b), condiciones de resúmenes diarios, cierre de jornada, gating del opt-in de IA y textos temáticos.

---

## 📋 Pantallas

1. **Home** — Vista del día con selector de fecha, tareas programadas y sin horario
2. **Semana** — Vista de 7 columnas con progreso por día
3. **Estadísticas** — Racha actual, mejor racha, progreso semanal, calendario mensual y vitrina de insignias
4. **Ajustes** — Usuario, zona horaria, hora de reset, notificaciones (margen, resúmenes, cierre de jornada), tema, Slate System, textos con IA y categorías
5. **Categorías** — CRUD completo de categorías con colores
6. **Personalizar insignias** — Configuración personalizada (incluye IA opt-in)
7. **Estilo de notificaciones con IA** — Configuración de sonido/vibración/badge (incluye IA opt-in)

---

## 📦 Build

```bash
# Debug APK (la API key es opcional, solo para IA)
flutter build apk --debug
flutter build apk --debug --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY

# Release APK (firmado)
flutter build apk --release --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY

# APK en: build/app/outputs/flutter-apk/
```

---

## 🔮 Roadmap

### Fase 1 ✅ (Completada)
- Persistencia local con Hive
- Todas las pantallas core
- Gamificación (rachas + insignias)
- Sistema de notificaciones (recordatorios, resúmenes, cierre de jornada)
- Slate System (textos temáticos + rangos/niveles) con IA opt-in
- Input por voz
- Widget de Android

### Fase 2 🔜 (Pendiente)
- Autenticación (email/password, Google Sign-In)
- Backend para sincronización
- Sync entre dispositivos
- Widget para iOS

---

## 📄 Licencia

Este proyecto es privado y para uso personal.
