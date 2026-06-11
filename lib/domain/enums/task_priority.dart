enum TaskPriority {
  normal,
  medium,
  high;

  String get displayName {
    switch (this) {
      case TaskPriority.normal:
        return 'Normal';
      case TaskPriority.medium:
        return 'Media';
      case TaskPriority.high:
        return 'Alta';
    }
  }

  int get sortOrder {
    switch (this) {
      case TaskPriority.high:
        return 0;
      case TaskPriority.medium:
        return 1;
      case TaskPriority.normal:
        return 2;
    }
  }
}