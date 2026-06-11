import 'package:equatable/equatable.dart';
import '../enums/badge_type.dart';

class Badge extends Equatable {
  final String id;
  final BadgeType type;
  final String name;
  final String iconName;
  final DateTime unlockedAt;
  final bool isDisplayed;

  const Badge({
    required this.id,
    required this.type,
    required this.name,
    required this.iconName,
    required this.unlockedAt,
    this.isDisplayed = false,
  });

  Badge copyWith({
    String? id,
    BadgeType? type,
    String? name,
    String? iconName,
    DateTime? unlockedAt,
    bool? isDisplayed,
  }) {
    return Badge(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isDisplayed: isDisplayed ?? this.isDisplayed,
    );
  }

  @override
  List<Object?> get props => [id, type, name, iconName, unlockedAt, isDisplayed];
}