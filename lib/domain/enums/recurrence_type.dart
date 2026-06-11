enum RecurrenceType {
  none,
  daily,
  weekly,
  specificDays;

  String get displayName {
    switch (this) {
      case RecurrenceType.none:
        return 'No repetir';
      case RecurrenceType.daily:
        return 'Diario';
      case RecurrenceType.weekly:
        return 'Semanal';
      case RecurrenceType.specificDays:
        return 'Días específicos';
    }
  }
}