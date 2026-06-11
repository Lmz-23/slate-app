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

**Slate** es una aplicación de gestión de tareas diarias con gamificación por rachas. Diseñada para uso personal, funciona 100% offline y está preparada para sincronización en la nube cuando se necesite.

### Características Principales

- ✅ **Tareas con/sin horario** — Agrega tareas a cualquier día, con hora opcional
- 🎤 **Input por voz** — Speech-to-text para crear tareas rápidamente
- 🔄 **Tareas recurrentes** — Diario, semanal, o días específicos
- 📝 **Notas y prioridades** — Detalles opcionales, prioridades Normal/Media/Alta
- 🏷️ **Categorías personalizables** — Nombre y color para cada categoría
- 🔥 **Sistema de rachas** — Mantén tu racha diaria completando tareas
- 🏅 **Insignias coleccionables** — 9 insignias desbloqueables por hitos (3, 7, 14, 21, 30, 60, 90, 180, 365 días)
- 📊 **Estadísticas** — Calendario mensual, progreso semanal, mejor racha
- 🌙 **Dark mode por defecto** — Tema oscuro optimizado
- 📱 **Widget de inicio** — Accede a tus tareas desde la pantalla principal (Android)

---

## 🏗️ Arquitectura

```
lib/
├── core/                    # Constantes, theme, utilities
├── domain/                  # Entities, enums, repository interfaces
├── data/                    # Hive boxes, adapters, repository implementations
├── application/             # Riverpod providers, services
└── presentation/            # Screens, widgets, navigation
```

### Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Framework | Flutter 3.44.x |
| Language | Dart 3.12.x |
| State Management | Riverpod |
| Local Storage | Hive |
| Navigation | GoRouter |
| Speech-to-Text | speech_to_text |
| Notifications | flutter_local_notifications |
| Home Widget | home_widget |

---

## 🚀 Empezar

### Prerrequisitos

- Flutter SDK 3.44.x
- Android SDK 36
- JDK 17+

### Instalación

```bash
# Clonar el repositorio
git clone https://github.com/Lmz-23/slate-app.git
cd slate-app

# Instalar dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

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
│   ├── theme/          # AppTheme (dark mode)
│   ├── utils/          # DateUtils, StringUtils
│   └── extensions/    # DateTime extensions
├── domain/
│   ├── entities/       # Task, Category, Badge, Streak, UserSettings
│   ├── enums/          # TaskPriority, RecurrenceType, BadgeType
│   └── repositories/    # Abstract interfaces
├── data/
│   ├── hive/
│   │   ├── adapters/   # Hive TypeAdapters
│   │   └── boxes/      # Hive boxes
│   └── repositories/    # Concrete implementations
├── application/
│   ├── providers/      # Riverpod StateNotifiers
│   └── services/        # NotificationService, WidgetService
└── presentation/
    ├── screens/        # Home, Weekly, Stats, Settings, Categories
    ├── widgets/        # Reusable components
    └── navigation/     # GoRouter configuration
```

---

## 🎮 Sistema de Gamificación

### Insignias

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

Las insignias **NO se pierden** si rompes la racha.

---

## 📋 Pantallas

1. **Home** — Vista del día con selector de fecha, tareas programadas y sin horario
2. **Semana** — Vista de 7 columnas con progreso por día
3. **Estadísticas** — Racha actual, mejor racha, calendario mensual, vitrina de insignias
4. **Ajustes** — Nombre de usuario, hora de reset, notificaciones, tema
5. **Categorías** — CRUD completo de categorías con colores

---

## 🔮 Roadmap

### Fase 1 ✅ (Completada)
- Persistencia local con Hive
- Todas las pantallas core
- Gamificación (streaks + badges)
- Input por voz
- Widget de Android

### Fase 2 🔜 (Pendiente)
- Autenticación (email/password, Google Sign-In)
- Backend para sincronización
- Sync entre dispositivos
- Widget para iOS

---

## 📦 Build

```bash
# Debug APK
flutter build apk --debug

# Release APK (firmado)
flutter build apk --release

# APK en: build/app/outputs/flutter-apk/
```

---

## 📄 Licencia

Este proyecto es privado y para uso personal.