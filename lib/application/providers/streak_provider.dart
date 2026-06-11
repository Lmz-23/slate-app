import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/streak.dart';
import '../../domain/entities/badge.dart';
import '../../domain/enums/badge_type.dart';
import '../../data/hive/boxes/streaks_box.dart';
import '../../data/hive/boxes/badges_box.dart';
import '../../data/repositories/streak_repository_impl.dart';
import '../../data/repositories/badge_repository_impl.dart';

final streaksBoxProvider = Provider<StreaksBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final badgesBoxProvider = Provider<BadgesBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final streakRepositoryProvider = Provider<StreakRepositoryImpl>((ref) {
  return StreakRepositoryImpl(ref.watch(streaksBoxProvider));
});

final badgeRepositoryProvider = Provider<BadgeRepositoryImpl>((ref) {
  return BadgeRepositoryImpl(ref.watch(badgesBoxProvider));
});

final streakProvider = StateNotifierProvider<StreakNotifier, Streak>((ref) {
  return StreakNotifier(ref.watch(streakRepositoryProvider), ref.watch(badgeRepositoryProvider));
});

final badgesProvider = StateNotifierProvider<BadgesNotifier, List<Badge>>((ref) {
  return BadgesNotifier(ref.watch(badgeRepositoryProvider));
});

final newUnlockedBadgeProvider = StateProvider<Badge?>((ref) => null);

class StreakNotifier extends StateNotifier<Streak> {
  final StreakRepositoryImpl _streakRepository;
  final BadgeRepositoryImpl _badgeRepository;
  final _uuid = const Uuid();

  StreakNotifier(this._streakRepository, this._badgeRepository) : super(_streakRepository.getStreak());

  void refresh() {
    state = _streakRepository.getStreak();
  }

  Future<void> onTaskCompleted() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = state.lastCompletedDate;

    int newStreak = state.currentStreak;

    if (lastDate == null) {
      newStreak = 1;
    } else {
      final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = today.difference(lastDateOnly).inDays;

      if (diff == 0) {
        return;
      } else if (diff == 1) {
        newStreak = state.currentStreak + 1;
      } else {
        newStreak = 1;
      }
    }

    final newLongest = newStreak > state.longestStreak ? newStreak : state.longestStreak;

    final updatedStreak = state.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastCompletedDate: now,
      updatedAt: now,
    );

    await _streakRepository.updateStreak(updatedStreak);
    state = updatedStreak;

    await _checkAndUnlockBadges(newStreak);
  }

  Future<void> _checkAndUnlockBadges(int streakDays) async {
    final badgeType = BadgeType.fromDays(streakDays);
    if (badgeType == null) return;

    final existing = _badgeRepository.getByType(badgeType.index);
    if (existing != null) return;

    final badge = Badge(
      id: _uuid.v4(),
      type: badgeType,
      name: badgeType.name,
      iconName: badgeType.iconName,
      unlockedAt: DateTime.now(),
      isDisplayed: true,
    );

    await _badgeRepository.add(badge);
  }

  void markBadgeAsDisplayed(String badgeId) {
    final badge = _badgeRepository.getById(badgeId);
    if (badge != null) {
      _badgeRepository.update(badge.copyWith(isDisplayed: false));
    }
  }
}

class BadgesNotifier extends StateNotifier<List<Badge>> {
  final BadgeRepositoryImpl _repository;

  BadgesNotifier(this._repository) : super(_repository.getAll());

  void refresh() {
    state = _repository.getAll();
  }

  List<Badge> getUnlocked() => _repository.getUnlocked();
}