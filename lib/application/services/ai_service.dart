import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AIService {
  // API key must be provided at build time using:
  // flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Analyze context (images + text) and return notification settings
  Future<NotificationAIResult> analyzeNotificationSettings({
    List<String>? imagePaths,
    String? textDescription,
  }) async {
    try {
      // Build prompt for notification settings
      final prompt = '''
Analiza el siguiente contexto y sugiere configuración de notificaciones para una app de tareas.
Devuelve SOLO un JSON válido con esta estructura exacta:
{"sound": true, "vibration": true, "badge": true}

Considera:
- Si el usuario sube imágenes de apps gaming/notification-silent → sound: false, vibration: true
- Si el usuario describe "minimal" o "discreto" → sound: false, vibration: false, badge: true
- Si el usuario describe "épico" o "destacado" → sound: true, vibration: true, badge: true

Contexto del usuario: ${textDescription ?? "Sin descripción adicional"}
''';

      final parts = <Map<String, dynamic>>[
        {'text': prompt},
      ];

      // Add images if provided
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (final path in imagePaths) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64Image = base64Encode(bytes);
            parts.add({
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Image,
              },
            });
          }
        }
      }

      final body = jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 100,
        },
      });

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

        // Extract JSON from response
        final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(text);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final result = jsonDecode(jsonStr);
          return NotificationAIResult(
            sound: result['sound'] ?? true,
            vibration: result['vibration'] ?? true,
            badge: result['badge'] ?? true,
          );
        }
      }

      return NotificationAIResult.defaults();
    } catch (e) {
      return NotificationAIResult.defaults();
    }
  }

  /// Analyze context and return badge customization suggestions
  Future<BadgeAIResult> analyzeBadgeCustomization({
    required String badgeType,
    required int daysRequired,
    List<String>? imagePaths,
    String? textDescription,
  }) async {
    try {
      final badgeNames = _getBadgeNames();
      final defaultName = badgeNames[badgeType] ?? 'Insignia $daysRequired';

      final prompt = '''
Analiza el siguiente contexto y sugiere un nombre épico y un icono para una insignia de racha de $daysRequired días en una app de tareas.

Responde SOLO con JSON válido:
{"name": "nombre épico en español", "icon": "nombre_icono"}

Iconos disponibles: star, fire, lightning, flower, shield, trophy, crown, diamond, rocket, sword, crown, medal, trophy, award, flame, bolt, zap, moon, sun, heart, bell, bellSlash, bellOff, volume, volume2, volumeX, alarm, clock, hourglass

Contexto del usuario: ${textDescription ?? "Sin descripción"}
''';

      final parts = <Map<String, dynamic>>[
        {'text': prompt},
      ];

      // Add images if provided
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (final path in imagePaths) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64Image = base64Encode(bytes);
            parts.add({
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Image,
              },
            });
          }
        }
      }

      final body = jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 100,
        },
      });

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

        final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(text);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final result = jsonDecode(jsonStr);
          return BadgeAIResult(
            name: result['name'] ?? defaultName,
            icon: result['icon'] ?? 'star',
          );
        }
      }

      return BadgeAIResult(name: defaultName, icon: 'star');
    } catch (e) {
      return BadgeAIResult(
        name: _getBadgeNames()[badgeType] ?? 'Insignia $daysRequired',
        icon: 'star',
      );
    }
  }

  Map<String, String> _getBadgeNames() {
    return {
      'streak3': 'Primer Paso',
      'streak7': 'Semana Perfecta',
      'streak14': 'Quincena',
      'streak21': 'Hábito Formado',
      'streak30': 'Mes de Hierro',
      'streak60': 'Doble Mes',
      'streak90': 'Trimestre',
      'streak180': 'Medio Año',
      'streak365': 'Leyenda',
      'custom90': 'Veterano',
      'custom180': 'Maestro',
      'custom365': 'Dios del Hábito',
    };
  }
}

class NotificationAIResult {
  final bool sound;
  final bool vibration;
  final bool badge;

  NotificationAIResult({
    required this.sound,
    required this.vibration,
    required this.badge,
  });

  factory NotificationAIResult.defaults() {
    return NotificationAIResult(
      sound: true,
      vibration: true,
      badge: true,
    );
  }
}

class BadgeAIResult {
  final String name;
  final String icon;

  BadgeAIResult({
    required this.name,
    required this.icon,
  });
}
