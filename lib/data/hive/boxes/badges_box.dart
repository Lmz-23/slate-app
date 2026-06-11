import 'package:hive_flutter/hive_flutter.dart';
import '../adapters/badge_adapter.dart';
import '../../../domain/entities/badge.dart';

class BadgesBox {
  static const String _boxName = 'badges';
  late Box<Badge> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Badge>(_boxName);
  }

  Box<Badge> get box => _box;

  List<Badge> getAll() => _box.values.toList();

  Badge? get(String id) {
    try {
      return _box.values.firstWhere((badge) => badge.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(Badge badge) async {
    await _box.put(badge.id, badge);
  }

  Future<void> update(Badge badge) async {
    await _box.put(badge.id, badge);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  List<Badge> getUnlocked() {
    return _box.values.toList()..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
  }

  Badge? getByType(int typeIndex) {
    try {
      return _box.values.firstWhere((badge) => badge.type.index == typeIndex);
    } catch (_) {
      return null;
    }
  }
}