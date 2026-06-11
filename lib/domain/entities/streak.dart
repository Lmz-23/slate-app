import 'package:equatable/equatable.dart';

class Streak extends Equatable {
  final String id;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompletedDate;
  final DateTime updatedAt;

  const Streak({
    required this.id,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    required this.updatedAt,
  });

  Streak copyWith({
    String? id,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastCompletedDate,
    DateTime? updatedAt,
  }) {
    return Streak(
      id: id ?? this.id,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, currentStreak, longestStreak, lastCompletedDate, updatedAt];
}