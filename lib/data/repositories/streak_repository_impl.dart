import '../../domain/entities/streak.dart';
import '../../domain/repositories/streak_repository.dart';
import '../hive/boxes/streaks_box.dart';

class StreakRepositoryImpl implements StreakRepository {
  final StreaksBox _streaksBox;

  StreakRepositoryImpl(this._streaksBox);

  @override
  Streak getStreak() => _streaksBox.getStreak();

  @override
  Future<void> updateStreak(Streak streak) => _streaksBox.updateStreak(streak);
}