import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/entities/companion_state.dart';

/// Caja Hive `companion_state` con el estado del Sistema (F3, singleton).
///
/// Backfill: al abrir por primera vez se crea un estado por defecto (quest sin
/// reclamar y sin visibilidad decidida).
class CompanionStateBox {
  static const String _boxName = 'companion_state';
  static const String _singletonId = 'main_companion';
  late Box<CompanionState> _box;

  Future<void> init() async {
    _box = await Hive.openBox<CompanionState>(_boxName);
  }

  Box<CompanionState> get box => _box;

  CompanionState getState() {
    final state = _box.get(_singletonId);
    if (state == null) {
      final fresh = CompanionState(updatedAt: DateTime.now());
      _box.put(_singletonId, fresh);
      return fresh;
    }
    return state;
  }

  Future<void> updateState(CompanionState state) async {
    await _box.put(_singletonId, state);
  }
}