import '../../domain/entities/badge.dart';
import '../../domain/repositories/badge_repository.dart';
import '../hive/boxes/badges_box.dart';

class BadgeRepositoryImpl implements BadgeRepository {
  final BadgesBox _badgesBox;

  BadgeRepositoryImpl(this._badgesBox);

  @override
  List<Badge> getAll() => _badgesBox.getAll();

  @override
  Badge? getById(String id) => _badgesBox.get(id);

  @override
  Future<void> add(Badge badge) => _badgesBox.add(badge);

  @override
  Future<void> update(Badge badge) => _badgesBox.update(badge);

  @override
  List<Badge> getUnlocked() => _badgesBox.getUnlocked();

  @override
  Badge? getByType(int typeIndex) => _badgesBox.getByType(typeIndex);
}