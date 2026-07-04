import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AIService {
  /// Test the Google Gemini API with a prompt and optional image bytes.
  static Future<String> testGemini({
    required String apiKey,
    required String prompt,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    // List of fallback endpoints/models to try
    final List<String> endpoints = [
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent',
    ];

    final List<Map<String, dynamic>> parts = [];

    // Add text prompt
    parts.add({'text': prompt});

    // Add image if available
    if (imageBytes != null) {
      final base64Image = base64Encode(imageBytes);
      parts.add({
        'inlineData': {
          'mimeType': mimeType,
          'data': base64Image,
        }
      });
    }

    final body = {
      'contents': [
        {
          'parts': parts,
        }
      ]
    };

    String lastError = '';

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse('$endpoint?key=$apiKey');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'];
          return text;
        } else {
          lastError = 'Endpoint $endpoint returned (${response.statusCode}): ${response.body}';
        }
      } catch (e) {
        lastError = 'Endpoint $endpoint threw: ${e.toString()}';
      }
    }

    throw Exception('Gemini API Error after trying fallback endpoints. Last error details: $lastError');
  }

  /// Test the Hugging Face Inference API to generate an image from a prompt.
  static Future<Map<String, dynamic>> testHuggingFace({
    required String token,
    required String prompt,
    String model = 'stabilityai/stable-diffusion-xl-base-1.0',
  }) async {
    try {
      final url = Uri.parse('https://api-inference.huggingface.co/models/$model');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': prompt,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {
          'bytes': response.bodyBytes,
          'source': 'Hugging Face ($model)',
        };
      } else {
        throw Exception('Hugging Face API Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      // Fallback to Pollinations AI (free, no token needed, reliable DNS)
      try {
        final bytes = await generatePollinations(prompt: prompt);
        return {
          'bytes': bytes,
          'source': 'Pollinations.ai (Fallback due to: ${e.toString().split('\n').first})',
        };
      } catch (fallbackError) {
        throw Exception('Both Hugging Face and Pollinations failed.\nHF Error: $e\nPollinations Error: $fallbackError');
      }
    }
  }

  /// Generate image using Pollinations.ai (completely free, no auth key required)
  static Future<Uint8List> generatePollinations({
    required String prompt,
  }) async {
    final encodedPrompt = Uri.encodeComponent(prompt);
    final url = Uri.parse('https://image.pollinations.ai/prompt/$encodedPrompt?nologo=true&private=true');
    final response = await http.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Pollinations API Error (${response.statusCode})');
    }
  }
}
