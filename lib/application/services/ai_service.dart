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

  /// ¿Existe API key de Gemini compilada (--dart-define)?
  static bool get hasApiKey => _apiKey.isNotEmpty;

  /// Lo mismo que [hasApiKey] pero como getter de instancia, para poder
  /// sobrescribirlo en los tests (un fake puede "tener" API key sin compilar
  /// el --dart-define).
  bool get canUseAI => _apiKey.isNotEmpty;

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

  /// Genera la variante TEMÁTICA (Slate System) de una notificación.
  ///
  /// Se invoca cuando el usuario guarda una tarea o se genera contenido con el
  /// toggle "Textos con IA" activo (NUNCA en el disparo de la notificación).
  ///
  /// La respuesta se VALIDA (estructura `title`/`body`, longitud y no vacía).
  /// Cualquier error, timeout, JSON inválido o ausencia de API key devuelve
  /// `null` para que el llamador use el catálogo local (fallback, nunca
  /// bloquear).
  Future<ThematicTextAIResult?> generateThematicText({
    required String eventType,
    required String titleContext,
  }) async {
    if (_apiKey.isEmpty) return null;
    try {
      final prompt = '''
Eres el "System" de una app de productividad con estética de cazadores y rangos.
Genera el texto de una notificación motivacional en ESPAÑOL para el evento "$eventType" relacionado con: "$titleContext".

Responde SOLO con JSON válido:
{"title": "título corto (máximo 60 caracteres)", "body": "cuerpo (máximo 200 caracteres)"}

Estilo: ventana de sistema (System window), tono de progresión por rangos/niveles.
Puedes usar glifos como ▶ ◇ ⚠ ◆. Motivacional, breve, sin emojis.
No copies frases literales de ninguna obra existente.
''';

      final parts = <Map<String, dynamic>>[
        {'text': prompt},
      ];

      final requestBody = jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 200,
        },
      });

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          '';
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(text);
      if (jsonMatch == null) return null;
      final result = jsonDecode(jsonMatch.group(0)!);

      final title = result['title'];
      final content = result['body'] ?? result['content'];
      if (title is! String || content is! String) return null;
      final cleanTitle = title.trim();
      final cleanContent = content.trim();
      if (cleanTitle.isEmpty || cleanContent.isEmpty) return null;
      if (cleanTitle.length > 60 || cleanContent.length > 200) return null;
      return ThematicTextAIResult(title: cleanTitle, body: cleanContent);
    } catch (_) {
      return null;
    }
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

class ThematicTextAIResult {
  final String title;
  final String body;

  ThematicTextAIResult({
    required this.title,
    required this.body,
  });
}
