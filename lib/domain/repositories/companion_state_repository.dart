import '../entities/companion_state.dart';

abstract class CompanionStateRepository {
  CompanionState getState();
  Future<void> updateState(CompanionState state);
}