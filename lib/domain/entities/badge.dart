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

  @override
  List<Object?> get props => [id, type, name, iconName, unlockedAt, isDisplayed];
}