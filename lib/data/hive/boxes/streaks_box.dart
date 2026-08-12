import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/entities/streak.dart';

class StreaksBox {
  static const String _boxName = 'streaks';
  static const String _singletonId = 'main_streak';
  late Box<Streak> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Streak>(_boxName);
  }

  Box<Streak> get box => _box;

  Streak getStreak() {
    final streak = _box.get(_singletonId);
    if (streak == null) {
      final newStreak = Streak(
        id: _singletonId,
        currentStreak: 0,
        longestStreak: 0,
        updatedAt: DateTime.now(),
      );
      _box.put(_singletonId, newStreak);
      return newStreak;
    }
    return streak;
  }

  Future<void> updateStreak(Streak streak) async {
    await _box.put(_singletonId, streak);
  }
}