class TimezoneService {
  static const Map<String, String> supportedTimezones = {
    // América
    'America/New_York': 'Nueva York (EE.UU.)',
    'America/Chicago': 'Chicago (EE.UU.)',
    'America/Denver': 'Denver (EE.UU.)',
    'America/Los_Angeles': 'Los Ángeles (EE.UU.)',
    'America/Phoenix': 'Phoenix (EE.UU.)',
    'America/Anchorage': 'Anchorage (EE.UU.)',
    'America/Tijuana': 'Tijuana (México)',
    'America/Mexico_City': 'Ciudad de México',
    'America/Cancun': 'Cancún (México)',
    'America/Monterrey': 'Monterrey (México)',
    'America/Bogota': 'Bogotá (Colombia)',
    'America/Lima': 'Lima (Perú)',
    'America/Caracas': 'Caracas (Venezuela)',
    'America/Santiago': 'Santiago (Chile)',
    'America/Buenos_Aires': 'Buenos Aires (Argentina)',
    'America/Sao_Paulo': 'São Paulo (Brasil)',
    'America/Havana': 'La Habana (Cuba)',
    'America/Jamaica': 'Kingston (Jamaica)',
    'America/Panama': 'Ciudad de Panamá',
    'America/Costa_Rica': 'San José (Costa Rica)',
    'America/Guatemala': 'Ciudad de Guatemala',
    'America/El_Salvador': 'San Salvador',
    'America/Tegucigalpa': 'Tegucigalpa (Honduras)',
    'America/Managua': 'Managua (Nicaragua)',
    'America/Asuncion': 'Asunción (Paraguay)',
    'America/La_Paz': 'La Paz (Bolivia)',
    'America/Quito': 'Quito (Ecuador)',
    'America/Georgetown': 'Georgetown (Guyana)',
    'America/Suriname': 'Paramaribo (Surinam)',
    // Europa Occidental
    'Europe/Madrid': 'Madrid (España)',
    'Europe/Paris': 'París (Francia)',
    'Europe/London': 'Londres (Reino Unido)',
    'Europe/Berlin': 'Berlín (Alemania)',
    'Europe/Rome': 'Roma (Italia)',
    'Europe/Lisbon': 'Lisboa (Portugal)',
    'Europe/Amsterdam': 'Ámsterdam (Países Bajos)',
    'Europe/Brussels': 'Bruselas (Bélgica)',
    'Europe/Vienna': 'Viena (Austria)',
    'Europe/Zurich': 'Zúrich (Suiza)',
    'Europe/Athens': 'Atenas (Grecia)',
    'Europe/Dublin': 'Dublín (Irlanda)',
    'Europe/Oslo': 'Oslo (Noruega)',
    'Europe/Stockholm': 'Estocolmo (Suecia)',
    'Europe/Copenhagen': 'Copenhague (Dinamarca)',
    'Europe/Helsinki': 'Helsinki (Finlandia)',
    'Europe/Warsaw': 'Varsovia (Polonia)',
    'Europe/Prague': 'Praga (República Checa)',
    'Europe/Budapest': 'Budapest (Hungría)',
    'Europe/Bucharest': 'Bucarest (Rumanía)',
    'Europe/Moscow': 'Moscú (Rusia)',
    'Europe/Istanbul': 'Estambul (Turquía)',
  };

  static String getDisplayName(String timezone) {
    return supportedTimezones[timezone] ?? timezone;
  }

  static List<String> get sortedTimezones {
    final zones = supportedTimezones.keys.toList();
    zones.sort((a, b) {
      // América primero
      final aIsAmerica = a.startsWith('America');
      final bIsAmerica = b.startsWith('America');
      if (aIsAmerica && !bIsAmerica) return -1;
      if (!aIsAmerica && bIsAmerica) return 1;
      return supportedTimezones[a]!.compareTo(supportedTimezones[b]!);
    });
    return zones;
  }

  static String? detectSystemTimezone() {
    // Intentar detectar la zona horaria del sistema
    // En Flutter web/desktop podemos usar DateTime.now().timeZoneName
    // En móvil esto es más limitado
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final hours = offset.inHours.abs();
      final minutes = (offset.inMinutes.abs() % 60);

      // Buscar coincidencia por offset
      for (final entry in _offsetToTimezone.entries) {
        if (entry.value == hours || (entry.value == hours && minutes > 0)) {
          // Verificar que no sea solo coincidencia parcial
          final tz = entry.key;
          return tz;
        }
      }
    } catch (_) {}
    return null;
  }

  static const Map<String, int> _offsetToTimezone = {
    // América
    'America/New_York': -5,
    'America/Chicago': -6,
    'America/Denver': -7,
    'America/Los_Angeles': -8,
    'America/Mexico_City': -6,
    'America/Bogota': -5,
    'America/Lima': -5,
    'America/Caracas': -4,
    'America/Santiago': -4,
    'America/Buenos_Aires': -3,
    'America/Sao_Paulo': -3,
    'America/Havana': -5,
    'America/Panama': -5,
    'America/Costa_Rica': -6,
    // Europa
    'Europe/Madrid': 1,
    'Europe/Paris': 1,
    'Europe/London': 0,
    'Europe/Berlin': 1,
    'Europe/Rome': 1,
    'Europe/Amsterdam': 1,
    'Europe/Brussels': 1,
    'Europe/Vienna': 1,
    'Europe/Zurich': 1,
    'Europe/Athens': 2,
    'Europe/Dublin': 0,
  };
}
