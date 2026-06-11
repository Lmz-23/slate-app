import '../entities/badge.dart';

abstract class BadgeRepository {
  List<Badge> getAll();
  Badge? getById(String id);
  Future<void> add(Badge badge);
  Future<void> update(Badge badge);
  List<Badge> getUnlocked();
  Badge? getByType(int typeIndex);
}