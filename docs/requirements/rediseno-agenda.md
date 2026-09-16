# Análisis funcional — Rediseño visual de la Agenda (handoff Claude Design)

**Fuente:** `design_handoff_gamificacion_agenda/Final Design Reference.dc.html` (+ `android-frame.jsx` como marco de renderizado) y `Exploration History.dc.html` (contexto de variantes descartadas).
**Proyecto destino:** `slate-app` — app Flutter (Dart, Riverpod, go_router, Hive), NO React/web.

---

## Objetivo

Adoptar en slate-app la nueva dirección visual "Cálida y amigable" para la pantalla de Agenda ("Hoy"), reemplazando la paleta índigo-sobre-negro actual y **simplificando drásticamente el lenguaje de gamificación** (de un sistema tipo RPG — nivel, rango, XP, misión diaria con recompensa, insignias — a un formato tipo "hábitos": racha + progreso del día + fila semanal de días completados), manteniendo la funcionalidad actual de la agenda.

---

## Contexto

Slate hoy es una app de tareas con gamificación fuerte y siempre visible: rango, nivel, XP, "Daily Quest" con recompensa reclamable (+25 XP), insignias de racha — sobre fondo oscuro con acento índigo (`#6366F1`), tipografía Inter. Esto se confirma en el código actual: `player_profile.dart` (XP/nivel/rangos), `quest_card.dart` ("Daily Quest", botón "Reclamar +XP"), `badge_vault.dart`, `player_card.dart`, `streak_display.dart`, todos visibles permanentemente en `StatsScreen` y `HomeScreen`.

El handoff de diseño documenta que se exploraron 4 direcciones visuales (1a actual, 1b minimalista, 1c cálida, 1d corporativa) y, dentro de la dirección cálida, 3 tonos de gamificación (3a RPG restilizado, 3b minimalista tipo hábitos, 3c refuerzo positivo suave). El archivo **`Final Design Reference.dc.html`** es el único marcado explícitamente como "Dirección final" y contiene **un solo artefacto**: la pantalla de Agenda ("Hoy"), en versión clara y oscura, usando el tono de gamificación **3b (minimalista tipo hábitos)** integrado directamente en la tarjeta de racha (sin nivel, sin XP, sin insignias, sin misión diaria).

`Exploration History.dc.html` es más amplio pero es material descartado/exploratorio: incluye mockups de pantallas "Detalle" (editar tarea) y "Calendario" (progreso semanal + mensual) en la misma dirección cálida, pero usando la variante de gamificación **3a (RPG restilizado)**, es decir, un tono de gamificación **distinto** al elegido como final para la Agenda. Ver "Ambigüedades" para el impacto de esto.

`android-frame.jsx` es infraestructura de presentación de Claude Design (marco de dispositivo Android, según su propio comentario "omelette starter... do not edit"): no aporta ningún requerimiento de producto, solo envuelve el mockup para visualizarlo como un teléfono. No debe usarse como referencia de estructura de UI de slate-app (slate-app es Flutter, no tiene "status bar"/"app bar"/teclado Android renderizados a mano; eso lo da el SO).

---

## Requerimientos Funcionales

### Pantalla Agenda / "Hoy" (única pantalla con mockup final)

- RF1. La cabecera debe mostrar el nombre relativo del día ("Hoy") en tamaño grande y la fecha formateada completa debajo (p. ej. "14 de septiembre"), igual que el `home_screen.dart` actual, pero con la nueva paleta.
- RF2. Debe existir un selector de 7 días en franja horizontal con flechas de navegación semanal (‹ ›) a los lados, mostrando inicial del día de la semana + número de día; el día seleccionado se resalta con el color de acento (coral) y contraste de texto en blanco. (Ya existe funcionalmente en `home_screen.dart::_buildDateSelector`; el cambio es solo de estilo visual — tamaño de celda, radios, colores.)
- RF3. Debe existir una tarjeta de racha/progreso que combine, en un solo componente:
  - RF3.1. Racha actual en días ("N días seguidos") con un ícono de racha (rombo/gota, no necesariamente el ícono de fuego actual).
  - RF3.2. Texto "X de Y tareas completadas hoy" + barra de progreso horizontal.
  - RF3.3. Fila "Esta semana" con 7 indicadores circulares (uno por día L–D), marcados con check si el día tuvo actividad (según la misma noción de "día activo" que ya calcula `StreakCalculator`) o vacíos si no.
  - Esta tarjeta **reemplaza** visual y funcionalmente tanto a la actual `StreakBadge` (icono de fuego en la cabecera) como a la actual `QuestCard` ("Daily Quest" con botón de reclamar XP) en la pantalla Home. Ver Ambigüedad A1 sobre si la reclamación de recompensa (XP) debe desaparecer o mantenerse oculta bajo el nuevo look.
- RF4. Debajo de la tarjeta de racha, debe existir una sección "Con horario" con: título + contador en píldora (nº de tareas con horario), y una lista de tarjetas de tarea, cada una con:
  - RF4.1. Checkbox circular (relleno verde con check si completada; contorno si pendiente).
  - RF4.2. Título de la tarea (tachado y en color atenuado si está completada).
  - RF4.3. Hora programada debajo del título.
  - RF4.4. Punto de color junto al título para tareas con prioridad "alta" (visto en "Preparar presentación cliente" con punto rojo/coral) — el mockup final NO muestra el punto en tareas de prioridad normal; comportamiento exacto por prioridad/categoría debe confirmarse (ver Ambigüedad A2).
- RF5. Debe existir un botón flotante circular ("+") en la esquina inferior derecha, color de acento coral, para crear una tarea nueva — funcionalmente equivalente al FAB ya existente en `home_screen.dart`.
- RF6. La pantalla debe soportar **modo claro y modo oscuro** con paletas de color específicas y completas provistas en el handoff (ver "Restricciones — paleta de color").
- RF7. El mockup final **no incluye** una sección "Sin horario" (tareas sin hora asignada) — a diferencia de la exploración 2a, que sí la mostraba. El componente `TaskSection` ya soporta esta sección hoy; debe decidirse si se conserva (ver Ambigüedad A3).

### Fuera del mockup final (solo referenciales, en Exploration History)

- RF8 (no confirmado como final). Pantalla de detalle/edición de tarea con la misma paleta cálida: campo de título, fecha/hora, aviso de recordatorio, selector de prioridad (Normal/Media/Alta con punto de color), selector de categoría (chips con punto de color), selector de repetición, notas, subtareas, botón "Guardar". Esto es prácticamente 1:1 con `task_form_sheet.dart` actual — solo cambia estilo visual, no estructura ni campos.
- RF9 (no confirmado como final). Pantalla de progreso/calendario con: cabecera "Mi progreso" + racha, navegador semanal, tarjeta "Progreso semanal" con barra y porcentaje, calendario mensual con puntos de color por día (verde = día completo, ámbar = parcial), fila "Resumen diario" con anillos de progreso circulares (conic-gradient) por día de la semana actual. Corresponde conceptualmente a `weekly_screen.dart` + `monthly_calendar.dart` actuales.
- RF10. Toggle "Gamificación" en Ajustes ("Muestra racha, metas y progreso en la app"), **desactivado por defecto**, mencionado en el texto de contexto de `Exploration History.dc.html` como aplicable a las 3 direcciones de gamificación. **No existe hoy en `settings_screen.dart` ni en `settings_provider`/`user_settings.dart`.** Este requerimiento entra en conflicto directo con el título del mockup final ("gamificación habit-style **siempre activa**") — ver Ambigüedad A1, es crítica y bloqueante.

---

## Requerimientos No Funcionales

- RNF1. La paleta de color debe implementarse como tokens de tema reutilizables (equivalente Flutter a los actuales `AppColors` / `ThemeData` en `app_theme.dart`), no como colores embebidos por widget, para mantener consistencia con el patrón ya usado en el proyecto (`AppColors`, `AppTypography`, `AppSpacing`).
- RNF2. Debe respetarse la separación de capas ya existente (`domain` / `data` / `application` / `presentation`) — el rediseño es una tarea de capa `presentation` (widgets/temas), sin alterar entidades de dominio salvo que un requerimiento funcional lo exija explícitamente (p. ej. si se requiere persistir el estado on/off de gamificación).
- RNF3. La tipografía del mockup usa la fuente **Nunito** (redondeada), vía Google Fonts, distinta de la tipografía actual del proyecto (Inter, vía `AppTypography`, cargada probablemente como fuente de sistema o asset local). Se requiere decisión de origen: fuente empaquetada como asset (offline-friendly, recomendado para apps móviles) vs. `google_fonts` package (requiere red la primera vez o vendoring). No es una decisión que competa a este análisis (es de Architecture/Decision), pero se documenta como necesidad derivada del diseño.
- RNF4. La pantalla debe seguir funcionando de forma idéntica en términos de datos (no debe alterar el modelo de persistencia de tareas/rachas) salvo que se decida lo contrario para RF10.
- RNF5. Debe mantenerse el soporte de modo claro/oscuro ya presente en el proyecto (`AppThemeMode`, sin modo "system" según decisión de producto ya tomada — ver commit reciente "Update app theme to remove 'system' mode").

---

## Restricciones

- R1. **Stack real es Flutter/Dart, no React/HTML/CSS.** El handoff está expresado como HTML+JSX renderizado por el runtime propio de Claude Design (`support.js`, marcado "GENERATED — do not edit", no es parte del producto). Todo el código de los archivos de handoff (estilos inline en `px`, `AndroidDevice` de `android-frame.jsx`) es **material de referencia visual**, no código a portar ni traducir línea a línea.
- R2. El proyecto ya tiene un sistema de theming centralizado (`AppColors`, `AppTypography`, `AppSpacing`, `AppTheme.darkTheme` / `AppTheme.lightTheme`) y componentes reutilizables (`SlateCard`, `TaskSection`, `TaskTile`, `StreakBadge`) que deberían ser el punto de extensión, no de reemplazo total.
- R3. Navegación existente: `go_router` con 4 tabs (`/home`, `/weekly`, `/stats`, `/settings`) vía `NavigationShell` con `BottomNavigationBar`. El mockup final no muestra bottom nav (el `android-frame.jsx` no lo simula; el diseño se centra solo en el contenido). No hay indicación en el handoff de cambios a la navegación global.
- R4. Paleta de color literal provista por el handoff (para uso en Decision/Architecture, no interpretarla libremente):
  - Claro: fondo `#FCF1E4`, tarjetas `#FFFBF3`, texto principal `#4A3325`, texto secundario `#8C6F58`, texto terciario/deshabilitado `#C0A98F`, acento `#E8734F` (coral), éxito `#7FAE7A` (verde), alta prioridad `#C15A4E`, media prioridad `#E3A94A`, categoría "Personal" `#5C87C4`.
  - Oscuro: fondo `#241812`, tarjetas `#34241B`, texto principal `#FBEEE0`, texto secundario `#C9A88D`, texto terciario `#8F7460`, acento `#E8734F` (igual), éxito `#8FC088`, alta prioridad `#E07362`.
- R5. El sistema de gamificación actual (XP, nivel, rango, quest diaria reclamable, insignias) tiene lógica de dominio y persistencia ya implementada y con reglas de negocio no triviales (`player_xp_calculator.dart`, `quest_calculator.dart`, anti-exploit al desmarcar tareas, `shownLevelUps`, etc.). Cualquier decisión de "ocultar" o "quitar" ese sistema debe distinguir entre **ocultar en UI** (bajo riesgo, reversible) y **eliminar del dominio** (alto riesgo, irreversible, afecta backups/migraciones vía `backup_codec.dart`). El handoff no se pronuncia sobre esto — es una decisión de producto pendiente.

---

## Dependencias

- D1. Depende de una decisión de producto sobre el destino del sistema RPG actual (nivel/XP/rango/quest/insignias): ¿se retira de la UI visible, se relega a una pantalla opcional, o convive con el nuevo estilo "hábitos" bajo el toggle de Ajustes mencionado en el handoff (RF10)?
- D2. Depende de si se decide extender `StreakCalculator` (ya expone `activeDays`) para derivar la fila "Esta semana" (7 días con check/vacío) sin nuevas entidades de dominio, o si se requiere un nuevo modelo persistido de "racha semanal". A nivel de análisis, los datos ya disponibles (`activeDays: Set<DateTime>`) parecen suficientes para derivar este requerimiento sin cambios de dominio — se señala como hallazgo, no como decisión tomada.
- D3. Depende de qué representa el "3" en "2 de 3 tareas completadas hoy": ¿es el total real de tareas programadas hoy (dato ya disponible vía `tasksProvider`), o es el umbral fijo de `QuestCalculator.requiredCompletions` (=3) heredado del sistema de quest? El mockup usa un ejemplo donde ambas lecturas coinciden numéricamente, por lo que no es posible determinar cuál se pretende solo con el handoff.
- D4. Depende de decisión tipográfica (RNF3): asset local de Nunito vs. paquete `google_fonts`.

---

## Riesgos Funcionales

- RG1. **Riesgo de regresión de producto:** eliminar de la vista principal toda referencia a XP/nivel/rango/insignias podría no ser lo que el usuario final quiere para su uso personal de la app (el propio contexto del handoff dice que esta dirección "cálida + habit-style" se diseñó pensando en "un público general", implicando que la dirección "actual" (RPG) se mantiene como opción, no que se elimina). Sin aclaración, se corre el riesgo de implementar una regresión de una función que el usuario valora.
- RG2. **Riesgo de inconsistencia visual entre pantallas** si se implementa solo la Agenda con el tono "habit-style" (3b) y el resto de la app (Stats/Settings/Weekly) permanece con el estilo visual e idioma RPG actual (3a): produciría una experiencia visualmente fragmentada a mitad de camino.
- RG3. **Riesgo de scope creep no solicitado:** las pantallas de Detalle y Calendario (RF8/RF9) no están en el archivo "final", solo en el histórico exploratorio con un tono de gamificación distinto (3a) al elegido para Agenda (3b); implementarlas asumiendo que son parte del "diseño final" introduciría inconsistencia y trabajo no validado por el usuario.
- RG4. **Riesgo de fuente/licencia:** introducir Nunito vía red (`google_fonts`) en una app que ya maneja datos sensibles de IA (Gemini) y backups locales podría no alinearse con el enfoque "local-first" que el proyecto parece favorecer (ver aviso de privacidad ya existente en Ajustes sobre IA).

---

## Ambigüedades Detectadas

- **A1 (bloqueante).** Contradicción directa entre fuentes: el título de `Final Design Reference.dc.html` dice "gamificación habit-style (**siempre activa**)", mientras que `Exploration History.dc.html` documenta explícitamente un toggle "Gamificación" en Ajustes, **desactivado por defecto**, aplicable a las 3 direcciones. No es posible determinar, solo con el handoff, si el toggle sigue vigente para la dirección final elegida o si se descartó junto con las otras 2 variantes de gamificación. Esto determina si RF10 aplica o no, y es una decisión de producto que debe resolver el usuario, no el Analyst.
- **A2.** No queda claro el criterio exacto para mostrar el punto de color junto al título de una tarea (¿solo prioridad alta? ¿prioridad + categoría? ¿solo categoría?). En el mockup, "Preparar presentación cliente" tiene un punto rojo/coral y en `Exploration History` (2a) el mismo tipo de punto aparece junto a chips de categoría con distintos colores (Trabajo=rojo, Personal=azul, Salud=verde). El proyecto actual ya tiene `TaskPriority` y `Category.colorHex` como candidatos, pero el mockup no lo distingue de forma inequívoca.
- **A3.** No está confirmado si la sección "Sin horario" (tareas sin hora) se conserva en el diseño final: está ausente en `Final Design Reference.dc.html` pero presente en la exploración ampliada 2a de la misma dirección cálida. Podría ser una omisión del mockup reducido (que solo muestra 3 tareas con horario, sin datos de ejemplo sin horario) más que una decisión deliberada de quitarla.
- **A4.** El destino del sistema RPG actual (nivel, XP, rango, misión diaria reclamable, insignias) no está resuelto: ¿se retira completamente de la experiencia de usuario, se mueve a una pantalla/sección secundaria, o coexiste oculto tras el toggle de gamificación? Ver RG1 y D1.
- **A5.** Las pantallas de Detalle de tarea y Progreso/Calendario (RF8/RF9) no tienen un mockup marcado como "final" — solo existen en el historial exploratorio, con un tono de gamificación (3a, RPG restilizado) inconsistente con el elegido para Agenda (3b). Se requiere confirmación explícita del usuario sobre si estas pantallas entran en el alcance de esta implementación y, si es así, con qué tono de gamificación.
- **A6.** No se especifica si el rediseño alcanza también a `WeeklyScreen`/`StatsScreen`/`SettingsScreen` (que hoy muestran racha, nivel, XP e insignias de forma prominente) o si el alcance se limita estrictamente a la pantalla Home/Agenda. El material entregado (Final Design Reference) solo cubre Agenda.

---

## Priorización (MoSCoW)

- **Must:** RF1–RF6 (rediseño visual + funcional de la pantalla Agenda en claro/oscuro, con la tarjeta de racha unificada), RNF1, RNF2, RNF4, RNF5, R1–R4.
- **Should:** Resolución de A1/A4 (destino del sistema RPG) antes de tocar Home, porque condiciona directamente el diseño de RF3.
- **Could:** RF8/RF9 (Detalle y Calendario) — solo si el usuario confirma que están en alcance (A5) y con qué tono de gamificación.
- **Won't (por ahora, sin instrucción explícita):** Cambios a la navegación global (R3), migración de datos de dominio del sistema RPG, introducción de `google_fonts` sin decisión de Architecture/Decision sobre RNF3.

---

## Resultado

El handoff entrega un mockup visual **final y completo únicamente para la pantalla Agenda/Hoy** (claro y oscuro), con una nueva paleta cálida y un nuevo lenguaje de gamificación minimalista tipo "hábitos" que reemplaza el sistema RPG visible hoy en Home. Las pantallas de Detalle de tarea y Progreso/Calendario, así como el toggle de Ajustes para gamificación, existen solo como material exploratorio no confirmado, con una variante de gamificación distinta e inconsistente con la elegida para Agenda.

Existe una **contradicción bloqueante (A1)** entre "gamificación siempre activa" (mockup final) y "gamificación desactivable, apagada por defecto" (contexto del histórico) que determina si hace falta un requerimiento nuevo de Ajustes/Settings y si el sistema RPG actual debe convivir, ocultarse o eliminarse. Recomiendo que el Orquestador escale esta pregunta al usuario antes de avanzar a Architecture, junto con las ambigüedades A2, A3, A5 y A6, que acotan significativamente el alcance real de la tarea de implementación.

Con esa resolución, el resto de los requerimientos (RF1–RF6, RNF1–RNF5, restricciones R1–R5) son suficientemente claros y accionables para que Architecture pueda proponer cómo extender el sistema de theming y los widgets ya existentes (`AppColors`, `AppTheme`, `SlateCard`, `TaskSection`, `StreakBadge`) sin necesidad de rediseñar la arquitectura de dominio.

---

## Decisiones del usuario (post-Analysis)

**Fecha de decisión:** 2026-09-15

### Contexto de negocio dado por el usuario

El proyecto empezó como personal, pero el usuario evalúa publicarlo. Por eso quiere un estilo visual más sobrio, no basado en gustos personales sino pensado para un público general. La gamificación le parece valiosa (ayuda a ver progreso y sentirse recompensado), pero tal como está implementada hoy (RPG con nivel/XP/rango/insignias vistoso) queda "fuera de lugar" frente a la nueva cara sobria de la app.

### Resolución A1 (destino del sistema de gamificación)

El sistema de gamificación **no se apaga ni se elimina**, y **no se implementa como toggle opcional**. Se **reestructura**: la lógica de dominio existente (XP, niveles, rachas, insignias, anti-exploit, level-ups) se conserva, pero su presentación visual debe rediseñarse para encajar con la nueva identidad sobria de la app. Esto implica trabajo de Architecture/Aesthetic para definir cómo se comunica el progreso/recompensa sin el lenguaje visual RPG actual.

### Resolución A5 (alcance de pantallas y adaptación)

El alcance se **amplía** más allá de la pantalla Agenda. Todo el rediseño de identidad visual debe extenderse al resto de la app (Weekly/Stats/Settings, Detalle de tarea, Progreso/Calendario), incluyendo potencialmente el logo de la app y posiblemente su nombre. Esto es una decisión de marca/identidad, no solo de una pantalla puntual.

### Resolución A6

Coincide con A5: Weekly/Stats/Settings entran en el alcance del rediseño.

### Nota para Architecture

Dado que el mockup del handoff (`Final Design Reference.dc.html`) solo cubre la pantalla Agenda/"Hoy" en detalle, el resto de pantallas (Weekly/Stats/Settings/Detalle/Calendario) y la reestructuración visual de la gamificación **no tienen un mockup final de referencia** — deberán diseñarse extendiendo el lenguaje visual (paleta, tipografía, tono) ya definido en el mockup de Agenda, posiblemente con apoyo del agente Aesthetic para garantizar coherencia de sistema de diseño antes o durante Architecture/Implementation.
