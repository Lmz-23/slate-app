extension DateTimeExtensions on DateTime {
  String get formattedDate {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${day.toString().padLeft(2, '0')} ${months[month - 1]} $year';
  }

  String get formattedTime {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String get formattedFull {
    final weekDays = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    return '${weekDays[weekday % 7]}, ${day.toString().padLeft(2, '0')} ${formattedDate.split(' ')[1]}';
  }

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  DateTime get startOfDay => DateTime(year, month, day);

  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);

  /// Devuelve 'Hoy', 'Mañana' o 'Ayer' cuando corresponde, o la fecha formateada.
  ///
  /// [now] permite pasar el instante actual en la zona horaria configurada
  /// (p. ej. `ref.read(nowProvider)`). Si es `null` se usa `DateTime.now()`.
  String relativeDay({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final thisDate = DateTime(year, month, day);
    final diff = thisDate.difference(today).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    return formattedDate;
  }
}