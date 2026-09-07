import '../../domain/entities/companion_state.dart';
import '../../domain/repositories/companion_state_repository.dart';
import '../hive/boxes/companion_state_box.dart';

class CompanionStateRepositoryImpl implements CompanionStateRepository {
  final CompanionStateBox _box;

  CompanionStateRepositoryImpl(this._box);

  @override
  CompanionState getState() => _box.getState();

  @override
  Future<void> updateState(CompanionState state) => _box.updateState(state);
}