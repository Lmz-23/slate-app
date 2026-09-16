---
fecha: 2026-09-15
etapa: Aesthetic (Fase 3 — resto de la app)
autor: Aesthetic Specialist
insumo: docs/architecture/rediseno-identidad-visual.md (Decisiones A1–A10), design_handoff_gamificacion_agenda/Final Design Reference.dc.html (único mockup confirmado)
---

# Sistema visual — Fase 3 (slate-app)

Este documento cierra los 10 puntos que Architecture dejó bloqueados por falta de definición visual. No define tokens nuevos: usa exclusivamente el vocabulario semántico ya fijado en la Decisión A1 del documento de arquitectura (`SlateColors`, radios, sombras) y extrapola su lógica visual —ya validada en el único mockup confirmado (pantalla Hoy)— al resto de la app. Donde el mockup no cubre un caso, la extrapolación se justifica por continuidad de patrón, nunca por preferencia personal.

Restricciones de producto que gobiernan todo lo que sigue (no son mías, son decisiones ya tomadas por el usuario): tono sobrio para público general; gamificación conservada pero sin estética RPG (sin glow, sin glifos ◆, sin "JUGADOR"/rangos); sin rango E→S; `/progress` fusiona Weekly+Stats en un solo scroll de 7 bloques; bottom nav de 3 destinos; punto de color en tile de tarea = solo prioridad; edición de tarea por pulsación larga; rango horario con diálogo de conflicto de 3 botones; quest diaria auto-reclamada sin botón.

---

## 0. Vocabulario de tokens (referencia, no redefine A1)

Valores tal como los fija `slate_palette.dart` (A1). Los cito aquí para que cada spec de abajo sea inequívoca sin tener que saltar de documento.

| Token semántico (`SlateColors`) | Claro | Oscuro | Uso |
|---|---|---|---|
| `background` | `#FCF1E4` | `#241812` | fondo de pantalla |
| `surface` | `#FFFBF3` | `#34241B` | tarjetas, tiles, hoja de formulario |
| `surfaceAlt` | `#F3DEC4` | `#402C21` | píldoras/contadores, track de barras de progreso |
| `outline` | `#E3D5C4` | `#8F7460` | bordes de checkbox vacío, indicador de día vacío |
| `textPrimary` | `#4A3325` | `#FBEEE0` | títulos, texto principal |
| `textSecondary` | `#8C6F58` | `#C9A88D` | subtítulos, etiquetas de sección |
| `textTertiary` | `#C0A98F` | `#8F7460` | metadatos (hora, día no seleccionado, texto tachado) |
| `accent` | `#E8734F` | `#E8734F` | día seleccionado, FAB, StreakMark, progreso de nivel, foco |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | texto/ícono sobre `accent` |
| `success` | `#7FAE7A` | `#8FC088` | check de completado, barra de progreso diario, punto de calendario con actividad |
| `onSuccess` | `#FFFFFF` | `#241812` | ícono de check sobre `success` (en oscuro el check es oscuro sobre verde claro, no blanco — así está en el mockup) |
| `todayAccent` | `#E8734F` | `#F0A868` | énfasis del día actual dentro de filas semanales (distinto de `accent` solo en oscuro, para no competir con el FAB/selector) |
| `priorityHigh` | `#C15A4E` | `#E07362` | punto de prioridad alta |
| `priorityMedium` | `#E3A94A` | `#EDB868`* | punto de prioridad media |
| `danger` | `#B23B2E`* | `#D9614F`* | fondo de swipe-to-delete, botón destructivo, borde de error |

\* Valores no explícitos en el mockup (que solo cubre Hoy); los derivo por continuidad de la relación claro→oscuro que sí es observable en el resto de la paleta (el modo oscuro sistemáticamente aclara ~10-15% el tono para mantener contraste sobre fondo oscuro sin perder temperatura cálida). `priorityMedium` oscuro aclara `#E3A94A`→`#EDB868` igual que `success` aclara `#7FAE7A`→`#8FC088`. `danger` se separa deliberadamente de `priorityHigh` aunque ambos sean rojizos: `priorityHigh` es informativo (una tarea importante), `danger` es destructivo (vas a borrar algo); confundirlos entrenaría al usuario a temer sus propias tareas urgentes. Verificar contraste real (WCAG AA, texto sobre `danger`) en Verification.

Radios (A1): `20` tarjetas contenedoras grandes (daily progress, player card), `18` tiles de lista (task tile, filas de settings), `14` elementos pequeños (celda de fecha, chips, botones de diálogo), `10` píldoras/contadores.

Sombra: solo en modo claro (`0 4px 14px rgba(74,51,37,.06)` para tarjetas grandes, `0 3px 10px rgba(74,51,37,.05)` para tiles, `0 6px 16px rgba(232,115,79,.4)` para el FIB/FAB). En oscuro, cero sombra — la separación de superficie se hace solo por color (`surface` sobre `background`), tal como ya se ve en el mockup oscuro.

Tipografía (A2, Nunito): 24px/800 títulos de pantalla, 14px/700 títulos de sección o tarjeta, 13-14px/600-700 cuerpo de tile, 11-12.5px/400-600 metadatos, 10-10.5px/400-700 etiquetas diminutas (días de la semana, contadores).

---

## 1. Gamificación reestructurada (nivel, XP, insignias — sin rango, sin RPG vistoso)

### Análisis
El estado actual (`player_card.dart`) usa borde índigo con glow, glifo `◆` y etiqueta `◆ JUGADOR`. Esto es exactamente el lenguaje que el producto descarta. El dominio (`PlayerProfile`, `player_xp_calculator.dart`) sigue calculando nivel y XP; solo cambia la piel. Regla rectora: la gamificación debe leerse como *información de progreso*, con el mismo tratamiento visual que cualquier otra métrica de la app (igual que la racha o el % semanal), no como un sistema de juego aparte.

### Propuesta

**Bloque "Perfil" (dentro de `/progress`, ver §2):**
- Tarjeta `surface`, radio 20, padding 16, sin borde de color, sin sombra en oscuro.
- Fila superior: `Nivel {n}` — 16px/800, `textPrimary`. A la derecha, sin badge ni glifo: solo el número, texto plano.
- Debajo, una línea de XP: `{xpActual} / {xpSiguiente} XP` — 12px/600, `textSecondary`.
- Barra de progreso al siguiente nivel: altura 6px, radio 3, track `surfaceAlt`, relleno `accent` (no `success`: `success` está reservado semánticamente para "tarea/día completado"; el avance de nivel usa `accent` para no mezclar dos significados en el mismo color).
- No se muestra rango, ni título honorífico, ni ícono de clase. Punto final.

**Insignias (`badge_vault.dart` / `badge_presentation.dart`):**
- Grid de tiles circulares, 56px de diámetro, `surface` de fondo, radio total (círculo).
- Insignia desbloqueada: ícono a color pleno (el que ya resuelve `badge_presentation.dart` por `BadgeType`), tamaño de ícono 28px centrado. Sombra solo en claro (`0 3px 10px rgba(74,51,37,.05)`, igual que un tile).
- Insignia bloqueada: mismo círculo, ícono en `outline` (silueta monocroma) al 100% de opacidad de trazo pero sin relleno de color — se lee como "contorno pendiente", no como "elemento apagado con opacity: 0.4" (la opacidad baja en fondos claros cálidos tiende a verse sucia; un contorno limpio comunica mejor "aún no").
- Sin halo, sin glow, sin animación de "rareza". Si se desea diferenciar insignias por importancia, se hace por tamaño de ícono (24px vs 28px) o por texto de subtítulo, nunca por efectos de brillo.
- Etiqueta de nombre debajo del círculo: 10.5px/600, `textSecondary`; centrada, máx 2 líneas.

**Level-up (snackbar):** ver §6 — incluido ahí junto al resto de estados transversales para no duplicar spec de snackbar.

### Impacto
Nivel y XP quedan legibles y coherentes con el resto de "métricas de progreso" de la app (racha, % semanal), sin lenguaje de videojuego. La eliminación del rango simplifica la jerarquía de información: menos que entender, más fácil de escanear.

---

## 2. Composición visual de `/progress` (7 bloques, scroll único)

### Propuesta
Contenedor: `background`, padding horizontal 20px (igual que Hoy), separación vertical **entre bloques de 24px** (más generosa que el `gap:18px` interno de Hoy, porque aquí cada bloque es una sección con identidad propia, no una lista continua de tiles).

1. **Cabecera** — mismo tratamiento tipográfico que Hoy: `Progreso` 24px/800 `textPrimary`, subtítulo 12.5px `textSecondary` (ej. "Tu constancia esta semana"). Sin selector de fecha aquí (ese es exclusivo de Hoy).

2. **Racha** — reutiliza `streak_display.dart` restilizado: tarjeta `surface`, radio 20, padding 16, fila `"{n} días seguidos"` (14px/700 `textPrimary`) + `StreakMark` grande (18px, ver §9) a la derecha. Si se quiere una segunda línea de contexto ("Tu racha más larga: 21 días"), 11px `textTertiary` debajo.

3. **Progreso semanal** (navegación de semana + barra %):
   - Fila de navegación: `‹  8–14 sept  ›` — flechas 17px `textTertiary` (igual estilo que las flechas del selector de fecha de Hoy), etiqueta central 13px/700 `textPrimary`.
   - Barra de porcentaje: misma construcción que la barra diaria de Hoy pero más alta (8px, radio 4) para señalar que es un agregado, no un detalle: track `surfaceAlt`, relleno `success` (agregación de días completados, mismo significado semántico que el check verde). Etiqueta encima: `"5 de 7 días con actividad"` 11px `textSecondary`.
   - Toda la tarjeta en `surface`, radio 20, padding 16, mismo patrón que bloque 2.

4. **Resumen por día de la semana** — fila de 7 columnas dentro de la misma tarjeta del bloque 3 o en tarjeta separada inmediatamente debajo (recomendado: separada, radio 20, padding 16, para que cada bloque sea escaneable independientemente). Por columna: letra del día (9px, `textTertiary`, o `todayAccent`+700 si es el día actual — mismo patrón que la fila "Esta semana" de Hoy) y debajo un indicador de **porcentaje** (no binario, a diferencia de la fila de Hoy): un anillo de progreso circular de 28px, trazo 3px, track `surfaceAlt`, arco `success` proporcional al % completado ese día; en el centro, el número de tareas completadas en 9px/700 `textPrimary` (ej. "3"). Esto diferencia deliberadamente esta fila de `week_activity_row` de Hoy (binaria ✓/vacío) tal como exige A10 — misma familia visual, semántica distinta, sin fusionarlas.

5. **Calendario mensual** (`monthly_calendar.dart`, ya tiene test): conserva estructura de grid, restilizado a tokens: fondo `surface` de la tarjeta contenedora radio 20; celda de día 32px, número 12px `textPrimary` (o `textTertiary` si es de otro mes); punto de actividad debajo del número, 5px de diámetro — `success` si ese día tuvo actividad completa, `priorityMedium` si tuvo actividad parcial, sin punto si no hubo actividad. El día actual recibe círculo de fondo `accent` con número en `onAccent` (mismo patrón que la celda de fecha seleccionada de Hoy, radio 14 pero en un círculo de 32px por ser celda de calendario, no selector).

6. **Perfil (nivel + XP)** — spec completa en §1.

7. **Insignias** — spec completa en §1. Grid de 4 columnas, gap 12px.

Cierre de scroll: padding inferior de 24px extra para no quedar pegado a la bottom nav (mismo criterio que el `padding-bottom: 74px` que ya usa Hoy para no chocar con el FAB/nav).

### Impacto
Un único ritmo visual (tarjeta `surface` + radio 20 + padding 16 + separación 24px) recorre los 7 bloques, evitando que la fusión de dos pantallas antiguas se note como un "pegado" de partes inconexas.

---

## 3. Estado "meta diaria cumplida" en la tarjeta de progreso de Hoy

### Análisis
Con el auto-reclamo (A9) ya no hay botón "reclamar". El riesgo (RG14) es que la recompensa de +25 XP sea invisible. La solución no puede ser un modal ni un elemento nuevo llamativo (rompería el tono sobrio y el layout ya estable de `DailyProgressCard`): debe ser una transformación *del mismo elemento* que el usuario ya está mirando.

### Propuesta
Cuando `completedToday >= totalToday` (o se cumple el umbral de la quest — el mismo bloque sirve para ambas lecturas, ver nota):
- La etiqueta `"2 de 3 tareas completadas hoy"` cambia a `"Meta diaria cumplida"` — 11px/700 (sube de weight respecto al 400 habitual), color `success` en vez de `textSecondary`. Es el único texto de toda la tarjeta que toma un color de acento — señal suficiente sin necesitar iconografía adicional.
- Se antepone un check pequeño (14px, ícono de check simple, color `success`) a la izquierda del texto, mismo glifo que ya usan los checks de tile de tarea — reutilización de vocabulario, no un ícono nuevo.
- La barra de progreso debajo se anima a 100% de relleno `success` (transición de color/ancho ya existente en la barra, sin efecto añadido).
- No hay confetti, no hay pop-up, no hay sonido. La discreción es la especificación, no una limitación: el usuario ya vio la tarea completarse (el check de la tarea ya le dio el feedback inmediato); esta línea es la confirmación de que además cerró la meta del día.
- Este estado persiste el resto del día sin revertir aunque se destache una tarea después (si el dominio permite destachar) — no es responsabilidad de Aesthetic decidir esa regla de negocio, pero visualmente el estado "cumplida" no debe parpadear entre completo/incompleto por una interacción incidental; si el dominio revierte, la barra/etiqueta simplemente vuelven a leer el nuevo valor.

Nota sobre el desacople de "meta diaria" (Y=total real de tareas) vs. "quest de +25 XP" (umbral fijo de 3, `QuestCalculator.requiredCompletions`): son dos condiciones potencialmente distintas (A3 ya señala esto). Recomendación visual: el texto que cambia a "Meta diaria cumplida" refleja `dailyProgressProvider` (completedToday == totalToday), que es la lectura honesta que la propia etiqueta promete. El +25 XP de la quest no se anuncia en esta tarjeta con un texto aparte —anunciar dos umbrales distintos en el mismo componente confundiría más de lo que aclara—; su único aviso visible al usuario es el level-up (§6) si ese XP cruza un nivel. Si el umbral de 3 no coincide con el total de hoy, el usuario puede ganar el XP sin ver "Meta diaria cumplida", o viceversa; esto es una discrepancia de producto (ya señalada por Architecture, punto 11) y no algo que el tratamiento visual pueda ni deba disimular.

### Impacto
Cero elementos nuevos en el árbol de widgets, cero riesgo de reflow: mismo contenedor, mismo texto, mismo bar — solo cambia estado. Coherente con "feedback discreto" pedido explícitamente por el usuario.

---

## 4. Detalle/formulario de tarea

### Propuesta

**Contenedor:** hoja (`task_form_sheet.dart`) `surface`, radio 20 en las esquinas superiores, padding 20.

**Selector de prioridad** — 3 segmentos en fila, tipo "pill group", altura 40px, radio 14 cada segmento:
- Cada segmento: punto de color (7px, mismo tamaño que en el tile — ver §8) + etiqueta de texto (13px/600).
- Alta: punto `priorityHigh`. Media: punto `priorityMedium`. Normal: sin punto (un guion corto `–` en `textTertiary` o simplemente ausencia de punto con solo el texto "Normal") — coherente con la regla de §8 de que "normal" no lleva color.
- Segmento activo: fondo `accent` al 12% de opacidad (`accent.withOpacity(0.12)`) + borde 1.5px `accent`; texto e ícono del segmento activo pasan a `textPrimary`/color de prioridad con weight 700. Segmento inactivo: fondo `surfaceAlt`, texto `textSecondary`.

**Selector de categoría** — fila de chips horizontales scrolleable, altura 36px, radio 18 (chip = mini tile):
- Cada chip: punto de color 8px (color de la categoría, paleta curada de §5) + nombre, 13px/600.
- Activo: fondo `surfaceAlt` + borde 1.5px del color de la propia categoría (no `accent` genérico, porque aquí cada categoría ya *es* un color — usar su propio color de borde refuerza la asociación en vez de opacarla con acento naranja).
- Último chip: `+ Nueva categoría`, ícono `+` 14px `accent`, texto `accent`, abre `categories_screen.dart`/diálogo de creación.

**Selector de recurrencia** — segmented control de 4 opciones ("No se repite", "Diario", "Semanal", "Personalizado"), mismo tratamiento visual que el selector de prioridad (fondo `surfaceAlt`, activo con fondo `accent` al 12%+ borde `accent`), sin punto de color (la recurrencia no tiene semántica de color, es un estado binario/enum sin urgencia asociada).

**Hora de inicio y duración/fin:**
- Campo de hora: mismo tratamiento que ya existe (selector de `TimeOfDay`), 14px/700 `textPrimary` sobre chip `surfaceAlt` radio 14, ícono de reloj 16px `textSecondary` a la izquierda.
- Campo de duración (nuevo, condicional a que P10/Opción 1 sea aprobada por Decision): chip idéntico al de hora, con etiqueta `"+ 1h"` o `"Sin duración"` si es null. Se coloca inmediatamente a la derecha del campo de hora, separados 8px, mismo alto — visualmente son "un par", no dos secciones distintas del formulario. Al tocar, abre un selector de duración simple (picker de horas/minutos o lista de opciones predefinidas 15/30/45/60/90 min + "Personalizado"), mismo estilo de hoja que el resto de selectores.
- Si no se aprueba el campo de duración (Opción 4 de A8), el campo de duración simplemente no existe en el formulario; el resto de esta sección no cambia.

**Diálogo de conflicto de horario:**
- Contenedor: `surface`, radio 20, padding 20, ancho máx 320px, centrado, con scrim `background` al 60% de opacidad detrás (no negro puro — mantiene la temperatura cálida incluso en el overlay).
- Título: `"Conflicto de horario"` 16px/800 `textPrimary`.
- Cuerpo: 13px/400 `textSecondary`, ej. `"«Preparar presentación cliente» se solapa con «Llamar al proveedor» (14:30–16:00)."`. Los nombres de tarea entre comillas van en `textPrimary`/600 para que destaquen del resto del cuerpo.
- Tres acciones, apiladas verticalmente (no en fila — con 3 botones y texto potencialmente largo como `"Acortar «Preparar presentación cliente»"`, una fila los comprimiría o los rompería mal), separadas 8px, en este orden de arriba a abajo, de más a menos recomendada:
  1. `Acortar «tarea»` — botón lleno, fondo `accent`, texto `onAccent`, radio 14, altura 44px. Es la acción sugerida por defecto porque resuelve el conflicto sin dejar solapamiento.
  2. `Guardar de todos modos` — botón de contorno, borde 1.5px `outline`, texto `textPrimary`, mismo radio/alto, fondo transparente. Acción secundaria válida, no destructiva, pero no la recomendada.
  3. `Cancelar` — texto plano centrado, sin fondo ni borde, `textSecondary`, altura 44px (misma alzada táctil que los otros dos aunque no tenga contenedor visible).

### Impacto
Todos los selectores comparten un único patrón visual (`surfaceAlt` inactivo → `accent`-tint activo), así que el formulario se lee como un solo sistema de controles aunque resuelva prioridad, categoría y recurrencia con datos distintos.

---

## 5. Ajustes y Categorías

### Ajustes
- Lista de filas `surface`, radio 18 cada fila (o una sola tarjeta larga con separadores `outline` de 1px entre filas — recomendado: filas independientes con 8px de separación, igual que los tiles de tarea, para mantener el mismo lenguaje de "tarjeta = unidad tocable" en toda la app).
- Cada fila: ícono 20px `textSecondary` a la izquierda, etiqueta 14px/600 `textPrimary`, control a la derecha (switch/chevron/valor) según el tipo de ajuste.
- Switches: pista `surfaceAlt` (off) / `accent` (on), 100% coherente con Material pero recoloreado a tokens — no se introduce un componente de switch custom.
- Secciones agrupadas bajo encabezado de categoría (ej. "Apariencia", "Notificaciones", "Datos"): encabezado 11px/700 uppercase, `textTertiary`, letter-spacing +0.04em (mismo tratamiento que "CON HORARIO" del mockup si se decide llevar esa etiqueta a mayúsculas — en el mockup no lo está, así que para Settings uso mayúsculas solo en encabezados de sección, para diferenciarlos jerárquicamente de las etiquetas de fila).

### Categorías — paleta curada (semilla `#5C87C4`)
Reemplaza los 17 tonos saturados tipo Tailwind de `AppColors.categoryColors`. Propuesta de 9 tonos, generados por rotación de matiz alrededor de la semilla y de los acentos ya presentes en la paleta cálida (para que una categoría nunca desentone del resto de la UI), manteniendo saturación y luminosidad similares entre sí (ningún tono debe "gritar" más que otro al aparecer junto a los demás en un chip):

| # | Hex | Nombre orientativo |
|---|---|---|
| 1 | `#5C87C4` | Azul semilla (ya en uso, ancla de la paleta) |
| 2 | `#7A9FD1` | Azul claro |
| 3 | `#6FAE9E` | Verde azulado |
| 4 | `#7FAE7A` | Verde (= `success`, reutilizado deliberadamente para categorías tipo "salud/hábitos") |
| 5 | `#E3A94A` | Ámbar (= `priorityMedium`, reutilizado para categorías tipo "trabajo/urgente" — coincidencia intencional de temperatura, no de significado: en el tile solo se ve el punto de prioridad, nunca ambos a la vez, así que no hay conflicto visual real) |
| 6 | `#C97B5A` | Terracota |
| 7 | `#B5769E` | Ciruela suave |
| 8 | `#8C7FBF` | Lavanda grisáceo |
| 9 | `#A98F6F` | Marrón arena (vecino de `textSecondary`, para categorías neutras) |

Cada tono debe pasar contraste AA como texto/ícono sobre `surface` y sobre `background` en ambos modos; si algún tono falla en oscuro, se aclara ~10% igual que el resto de la paleta (mismo criterio de §0), sin cambiar el matiz.

### Impacto
Ajustes deja de sentirse como una pantalla "de sistema" separada del resto de la app (mismo radio 18, misma tarjeta `surface`). La paleta de categorías pasa de 17 tonos arbitrarios a 9 tonos que conviven con los tokens ya definidos, dos de ellos compartidos deliberadamente con `success`/`priorityMedium` porque el contexto (categoría vs. prioridad) nunca se muestra en el mismo punto.

---

## 6. Estados transversales

**Estado vacío** (sin tareas hoy / sin insignias / sin datos en el mes):
- Ícono simple (outline, 40px, `textTertiary`, sin ilustración compleja — coherente con "sobrio").
- Texto 13px/600 `textSecondary` debajo, 8px de separación. Ej. `"Sin tareas para hoy"` / `"Aún no hay insignias"`.
- Centrado vertical y horizontal dentro del espacio disponible, sin tarjeta contenedora (fondo `background` directo) — un estado vacío no es un componente, es la ausencia de uno.

**Snackbar por defecto** (ej. tarea eliminada sin deshacer, error genérico):
- Fondo `surface` en claro (con sombra), `surfaceAlt` en oscuro (para diferenciarse del `background` ya que no hay sombra); radio 14; texto 13px/600 `textPrimary`; padding 12/16; posicionado 16px sobre el borde inferior/nav.

**Snackbar "Deshacer"** (al truncar una tarea por el diálogo de conflicto, o al borrar):
- Mismo contenedor que el snackbar por defecto. Texto a la izquierda (`"Tarea acortada a 14:30–15:00"`), acción `DESHACER` a la derecha en `accent`/700 uppercase, sin fondo de botón (texto-acción, como el Snackbar de Material estándar pero recoloreado).
- Duración 4s, una sola línea, sin ícono.

**Snackbar de subida de nivel:**
- Es el único snackbar con tratamiento distinto porque marca un evento positivo poco frecuente, pero sigue sin recurrir a lenguaje RPG.
- Fondo `accent` (no `surface` — se gana la excepción de color pleno precisamente por ser un evento, igual que ya hace el FAB), texto `onAccent`.
- Contenido: `"Subiste a nivel {n}"` 14px/700, sin ícono de trofeo/corona — si se quiere un glifo, el mismo rombo de `StreakMark` (§9) en `onAccent`, reforzando que es "una marca de progreso más", no un ícono de videojuego nuevo.
- Duración 3s. Sin sonido ni haptics definidos aquí (fuera de alcance visual).

**Diálogo de confirmación de borrado:**
- Mismo patrón de contenedor que el diálogo de conflicto (§4): `surface`, radio 20, padding 20, scrim `background` 60%.
- Título `"¿Eliminar tarea?"` 16px/800. Cuerpo 13px `textSecondary` con el nombre de la tarea en `textPrimary`/600.
- Dos botones en fila (a diferencia del diálogo de conflicto, aquí solo hay 2 opciones y caben sin comprimirse): `Cancelar` (texto plano, `textSecondary`, izquierda) y `Eliminar` (fondo `danger`, texto blanco, radio 14, derecha) — es el único botón lleno de toda la app que usa `danger` en vez de `accent`, reservado exclusivamente para confirmaciones destructivas finales.

**Fondo de swipe-to-delete:**
- Color de fondo `danger`, ícono de papelera 20px en blanco, alineado al borde (izquierdo si el swipe revela desde la derecha, y viceversa), radio igual al del tile que se está revelando (18) para que el fondo no se vea recortado.

**Indicadores de carga:**
- Spinner circular simple, trazo 2.5px, color `accent`, tamaño 24px para inline (dentro de un botón) y 32px para pantalla completa/centro de sección.
- Sin skeleton screens (no están en el vocabulario visual actual de la app ni se justifican por la latencia real de una app local-first con Hive: las cargas son instantáneas salvo operaciones puntuales como restaurar backup). El spinner centrado sobre `background` es suficiente.

### Impacto
Los 6 estados comparten radio 20/paleta ya fijada, así que ninguno se percibe como "importado" de un kit de componentes genérico de Flutter sin adaptar.

---

## 7. Bottom navigation bar (3 destinos)

- Barra `surface` (claro, con sombra superior sutil `0 -2px 8px rgba(74,51,37,.05)`) / `surface` sin sombra (oscuro), altura estándar Material (56-64px + safe area), `BottomNavigationBarType.fixed` (ya fijado por A10, no se toca).
- 3 destinos, orden fijo: **Hoy** — **Progreso** — **Ajustes**.
- Íconos (outline 24px, un único set de línea consistente en todo momento, evitando mezclar estilos filled/outline entre sí salvo por el estado seleccionado):
  - Hoy: check dentro de un cuadrado redondeado (representa "agenda del día" — reutiliza el glifo de check que ya vive en toda la app en vez de un ícono de calendario genérico, para reforzar la asociación check=completar).
  - Progreso: el mismo rombo/gota de `StreakMark` (§9) pero renderizado como ícono de línea en estado inactivo, y como forma rellena en estado activo — es la pieza de continuidad más fuerte entre Home y Progreso que pide el punto 9, y evita reutilizar un ícono de "gráfico de barras" que remitiría a dashboards fríos, no al tono cálido de la app.
  - Ajustes: engranaje estándar (ícono universal, no hay razón de marca para reinventarlo).
- Estado seleccionado: ícono y etiqueta en `accent`, ícono en versión "filled"/sólida si el set lo permite (o simplemente el mismo trazo con `stroke-width` +0.5 para dar peso, si se usa un único ícono en ambos estados). Etiqueta 10px/700.
- Estado no seleccionado: ícono y etiqueta en `textTertiary`, trazo normal, etiqueta 10px/600.
- Sin badges numéricos, sin puntos de notificación en los íconos (coherente con "sin lenguaje de videojuego" — un contador de XP pendiente sobre el ícono de Progreso sería justamente el tipo de urgencia gamificada que el producto quiere evitar).

### Impacto
El ícono de Progreso comparte forma exacta con el `StreakMark` que el usuario ya asocia a "racha" desde Hoy, dando a la navegación una pista visual coherente con el contenido al que lleva.

---

## 8. Regla del punto único de prioridad en el tile de tarea

- **Un solo indicador de color por tarea**, y ese color codifica **solo prioridad**, nunca categoría (la categoría ya se puede inferir por el texto/contexto del formulario; forzarla también en el tile duplicaría información y es justo la ambigüedad que Architecture señaló como P1 — se resuelve aquí a favor de la instrucción explícita del usuario).
- Tamaño: **7px de diámetro**, círculo perfecto — es el valor exacto que ya usa el mockup confirmado para el punto de "Preparar presentación cliente" (línea con prioridad alta), así que no es una elección nueva sino la generalización de un patrón ya validado.
- Posición: inmediatamente a la izquierda del título de la tarea, en la misma fila, con 6px de separación al texto (igual que el mockup).
- Colores:
  - Prioridad alta → `priorityHigh` (`#C15A4E` claro / `#E07362` oscuro).
  - Prioridad media → `priorityMedium` (`#E3A94A` claro / `#EDB868` oscuro).
  - Prioridad normal → **sin punto**. No se pinta un punto neutro/gris; simplemente no hay indicador, tal como ya ocurre en el mockup con "Llamar al proveedor" (prioridad normal, sin punto, solo check vacío + título). Esto evita que el ojo tenga que descartar activamente "un punto gris no importa" — la ausencia es más rápida de leer que un color neutro.
- La barra de prioridad de 4×40px que existe hoy en `task_tile.dart` (además del punto de categoría) se elimina: queda un único indicador, el punto de 7px. Esto es lo que resuelve la "ambigüedad A2/P1" señalada por Architecture.

### Impacto
Un solo indicador, un solo significado. El tile queda más limpio (un elemento menos) y más legible (no hay que decodificar dos colores distintos por tarea).

---

## 9. StreakMark (marca de racha)

- Forma: **rombo con una esquina recta** (`border-radius: 50% 50% 50% 0` + `rotate(45deg)` sobre un cuadrado), tal como ya está resuelto y validado en el mockup confirmado (línea junto a "12 días seguidos"). No es un ícono de librería; es una forma pintada simple — cero coste de asset, cero ambigüedad de licencia, y ya tiene precedente pixel-perfect en el mockup.
- Color: siempre `accent` (`#E8734F`), en ambos modos y en ambos contextos de uso — es intencional que no cambie con el tema ni con el valor de la racha (no hay "niveles de rombo" por antigüedad de racha; eso reintroducría progresión gamificada visual que el producto no pidió).
- Tamaños de uso, dos variantes nada más (evitar una escala arbitraria de tamaños):
  - **Pequeño (9px)** — dentro de `DailyProgressCard` en Hoy, junto al texto "N días seguidos" (uso ya validado por el mockup).
  - **Grande (18-20px)** — en el bloque "Racha" de `/progress` (§2.2) y como base del ícono de navegación de "Progreso" (§7), donde necesita ser reconocible como ícono táctil.
- Sin relleno degradado, sin brillo/glow, sin animación de pulso continuo. Se permite (opcional, no obligatorio) una animación de "pop" de escala (1 → 1.08 → 1, ~200ms) únicamente en el momento en que la racha suma un día nuevo, como único micro-feedback permitido — discreto, una vez, no un loop.

### Impacto
Una única forma reconocible ancla visualmente "racha" en tres lugares distintos de la app (Hoy, Progreso, bottom nav), dando cohesión sin depender de texto repetido.

---

## 10. Formato de rango horario y estilo del diálogo de conflicto

### Formato: 24 horas, fijo
- El mockup confirmado **ya usa 24h** para toda hora mostrada en el tile ("09:00", "14:30", "16:00") — no hay ninguna instancia de 12h/am-pm en el único diseño aprobado por el usuario. Se recomienda 24h fijo también para el rango, por consistencia directa con lo ya validado, en vez de introducir una regla nueva (`MaterialLocalizations`/reloj de 12h del dispositivo) que el mockup nunca mostró.
- Rango: `"{inicio}–{fin}"` con **guion medio sin espacios** (en-dash `–`, no guion corto `-` ni palabra "a"), ej. `14:30–16:00`. Mismo tamaño/color que la hora simple ya usa hoy: 11px, `textTertiary` claro / `textTertiary` oscuro, ubicado en la misma posición (debajo del título, misma fila que ocupaba la hora única).
- Si la tarea no tiene duración (`durationMinutes == null`, caso por defecto y todas las tareas preexistentes sin backfill — A8), se muestra solo la hora de inicio, exactamente como hoy: `09:00`. No se inventa una duración de presentación (Opción 3 de A8 queda descartada también desde lo visual: mostrar un rango fabricado sería mostrar información falsa, mismo argumento que ya usó Architecture para rechazar usar el umbral de la quest como total diario).

### Diálogo de conflicto — estilo visual
Ya especificado en detalle en §4 (contenedor, tipografía, los 3 botones apilados en orden Acortar → Guardar de todos modos → Cancelar). Complemento aquí: el texto del cuerpo debe citar el **rango con el mismo formato 24h** definido arriba (`14:30–16:00`), nunca una descripción en palabras ("de 2:30 a 4 de la tarde") — coherencia total entre lo que se ve en el tile y lo que se lee en el diálogo que lo referencia.

### Impacto
Cero nueva decisión de localización de reloj: se sigue exactamente lo que el mockup confirmado ya decidió, evitando una inconsistencia entre "cómo se ve una tarea" (tile, ya construido en Fase 2) y "cómo se describe esa misma tarea" (diálogo, Fase 3).

---

## Resultado

Los 10 puntos bloqueados quedan especificados con valores de color (tokens `SlateColors` ya definidos en A1, con dos valores derivados y justificados donde el mockup no los cubre: `priorityMedium` oscuro y `danger` en ambos modos), tamaños en px, radios (20/18/14/10, reutilizando exactamente la escala de A1), spacing y comportamiento de estado — sin introducir ningún token, color literal fuera de la paleta, ni componente que no tenga precedente directo en el mockup confirmado o una extrapolación explícitamente justificada de su patrón. Ningún punto requiere lenguaje RPG, glow, rangos o glifos de clase; la gamificación queda reducida a nivel+XP+insignias con el mismo tratamiento visual que cualquier otra métrica de progreso de la app. Quedan dos dependencias de producto que este documento no puede resolver por exceder la autoridad de Aesthetic: P10 (si se aprueba el campo `durationMinutes`, condición para que el rango horario de §10 exista en absoluto) y P11 (confirmación de que el tratamiento de §3 es el feedback aceptado para el auto-reclamo de la quest) — ambos ya escalados por Architecture a Decision, no a Aesthetic.
