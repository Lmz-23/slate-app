import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/quest_auto_claim.dart';
import '../../../core/theme/slate_theme_context.dart';
import 'level_up_snackbar.dart';

/// Cascarón de navegación con la bottom bar (3 destinos, Decisión A10).
///
/// Fase 2 (Addendum 1, A9): pasa a [ConsumerWidget] con dos responsabilidades
/// nuevas, necesarias porque `QuestCard` sale del árbol de Home:
/// - `ref.watch(questAutoClaimProvider)` mantiene VIVA la suscripción a
///   `questProvider`; sin ella la quest deja de construirse y muere en
///   silencio (RG15).
/// - `ref.listen(questRewardLevelUpProvider, ...)` muestra el SnackBar de
///   nivel cuando el auto-reclamo produce un level-up nuevo, y resetea el
///   canal a `null` tras mostrarlo.
///
/// Fase 3a (Addendum 1, A10 + sistema-visual-fase3.md §7): 3 destinos —
/// Hoy, Progreso, Ajustes.
class NavigationShell extends ConsumerWidget {
  final Widget child;

  const NavigationShell({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/progress')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el efecto de auto-reclamo (A9): sin este `watch`, al no
    // haber más consumidores de `questProvider` tras retirar `QuestCard`, la
    // quest quedaría sin suscriptores.
    ref.watch(questAutoClaimProvider);

    ref.listen<int?>(questRewardLevelUpProvider, (previous, level) {
      if (level == null) return;
      showLevelUpSnackBar(context, level);
      ref.read(questRewardLevelUpProvider.notifier).state = null;
    });

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getCurrentIndex(context),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/progress');
              break;
            case 2:
              context.go('/settings');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined),
            activeIcon: Icon(Icons.check_box),
            label: 'Hoy',
          ),
          BottomNavigationBarItem(
            icon: _ProgressNavIcon(filled: false),
            activeIcon: _ProgressNavIcon(filled: true),
            label: 'Progreso',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

/// Ícono de "Progreso": mismo rombo/gota que [StreakMark]
/// (sistema-visual-fase3.md §7/§9), en línea cuando está inactivo y relleno
/// cuando está activo. No reutiliza [StreakMark] directamente porque ese
/// átomo es siempre `accent`; aquí el color depende del estado de
/// selección de la bottom nav (regla general de §7), así que se dibuja como
/// un widget dedicado y pequeño en vez de ampliar el átomo compartido.
class _ProgressNavIcon extends StatelessWidget {
  final bool filled;

  const _ProgressNavIcon({required this.filled});

  static const double _dimension = 18;

  @override
  Widget build(BuildContext context) {
    final slate = context.slate;
    final color = filled ? slate.accent : slate.textTertiary;

    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: _dimension,
            height: _dimension,
            decoration: BoxDecoration(
              color: filled ? color : Colors.transparent,
              border: filled ? null : Border.all(color: color, width: 1.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(_dimension / 2),
                topRight: Radius.circular(_dimension / 2),
                bottomLeft: Radius.circular(_dimension / 2),
                bottomRight: Radius.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
