import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quest_provider.dart';

/// Canal de evento del level-up producido por el auto-reclamo de la quest
/// (Addendum 1, A9). Basta un `int?` sin secuencia: `PlayerProfile.shownLevelUps`
/// garantiza que cada nivel se emite como level-up nuevo a lo sumo una vez, y
/// el nivel nunca decrece.
final questRewardLevelUpProvider = StateProvider<int?>((ref) => null);

/// Efecto observador que reclama la quest diaria automáticamente cuando se
/// cumple, SIN modificar `QuestNotifier` ni `QuestCalculator` (A9).
///
/// - Observa `QuestState` (no `tasksProvider`/`dailyProgressProvider`
///   directamente: `questProvider` ya se refresca ante ambos).
/// - `fireImmediately: true` es OBLIGATORIO: `QuestNotifier` ejecuta `_sync()`
///   en su constructor antes de que exista oyente; sin esto, un arranque en
///   frío con la quest ya cumplida no otorgaría nunca el premio.
/// - Guard anti-reentrada: mientras haya un `claim()` en vuelo, un nuevo
///   evento `canClaim == true` no dispara un segundo `claim()` (RG17).
///
/// Requiere una suscripción de mantenimiento (`ref.watch` en
/// `NavigationShell`, ver A9): sin ella, al retirar `QuestCard` de Home nadie
/// observa `questProvider` y la quest muere en silencio (RG15).
final questAutoClaimProvider = Provider<void>((ref) {
  Future<void>? pending;

  ref.listen<QuestState>(
    questProvider,
    (previous, next) {
      if (!next.canClaim) return;
      if (pending != null) return;

      final future = ref.read(questProvider.notifier).claim().then((levelUp) {
        if (levelUp != null) {
          ref.read(questRewardLevelUpProvider.notifier).state = levelUp;
        }
      });
      pending = future;
      future.whenComplete(() => pending = null);
    },
    fireImmediately: true,
  );
});
