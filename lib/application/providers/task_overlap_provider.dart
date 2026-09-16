import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/task_overlap_detector.dart';
import 'task_provider.dart';

/// Provider de la consulta de solapamiento (Addendum 2, A12). Se reconstruye
/// (índice por día incluido) cuando [tasksProvider] cambia, no en cada
/// guardado del formulario.
final taskOverlapQueryProvider = Provider<TaskOverlapQuery>((ref) {
  final tasks = ref.watch(tasksProvider);
  return TaskOverlapDetector(tasks);
});
