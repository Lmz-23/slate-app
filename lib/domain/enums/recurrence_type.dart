enum RecurrenceType {
  none,
  daily,
  weekly,
  specificDays,
  // F4: se AÑADE al FINAL para no alterar los índices persistidos en Hive por
  // el TaskAdapter (que guarda `recurrence.index`). Los valores 0-3 ya escritos
  // en dispositivos existentes siguen significando none/daily/weekly/
  // specificDays.
  monthly;

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
      case RecurrenceType.monthly:
        return 'Mensual';
    }
  }
}