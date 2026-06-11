import '../entities/streak.dart';

abstract class StreakRepository {
  Streak getStreak();
  Future<void> updateStreak(Streak streak);
}