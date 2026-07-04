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
  static Future<Uint8List> testHuggingFace({
    required String token,
    required String prompt,
    String model = 'black-forest-labs/FLUX.1-schnell',
  }) async {
    final url = Uri.parse('https://router.huggingface.co/hf-inference/models/$model');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'inputs': prompt,
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Hugging Face API Error (${response.statusCode}): ${response.body}');
    }
  }

  /// Call the IDM-VTON virtual try-on model via Nymbo HF Space Gradio API.
  /// Sends person image and garment image, returns the try-on result as bytes.
  static Future<Uint8List> callVirtualTryOn({
    required Uint8List personImageBytes,
    required Uint8List garmentImageBytes,
    String garmentDescription = '',
    String personMimeType = 'image/jpeg',
    String garmentMimeType = 'image/jpeg',
    String hfToken = '',
  }) async {
    final personBase64 = 'data:$personMimeType;base64,${base64Encode(personImageBytes)}';
    final garmentBase64 = 'data:$garmentMimeType;base64,${base64Encode(garmentImageBytes)}';

    // Nymbo/Virtual-Try-On Space uses IDM-VTON.
    // Input order: [person_image_dict, garment_image, garment_description,
    //               is_checked (bool), is_checked_crop (bool), denoise_steps (int),
    //               seed (int)]
    final body = {
      'data': [
        {
          'background': {'name': 'person.jpg', 'data': personBase64},
          'layers': [],
          'composite': null,
        },
        {'name': 'garment.jpg', 'data': garmentBase64},
        garmentDescription.isEmpty ? 'A garment to try on' : garmentDescription,
        true,  // is_checked
        true,  // is_checked_crop
        30,    // denoise_steps
        42,    // seed
      ],
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (hfToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $hfToken';
    }

    // Step 1: Queue the job
    final queueUrl = Uri.parse('https://nymbo-virtual-try-on.hf.space/run/predict');
    final response = await http.post(
      queueUrl,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      // Gradio returns {"data": [url_or_base64, ...]}
      final resultData = decoded['data'];
      if (resultData != null && resultData is List && resultData.isNotEmpty) {
        final first = resultData[0];
        String? imageUrl;

        if (first is Map) {
          // Newer Gradio returns {url: "..."} or {path: "..."}
          imageUrl = first['url'] as String? ?? first['path'] as String?;
        } else if (first is String) {
          if (first.startsWith('data:')) {
            // Inline base64 data URI
            final base64Part = first.split(',').last;
            return base64Decode(base64Part);
          }
          imageUrl = first;
        }

        if (imageUrl != null) {
          // Fetch the image from the returned URL
          final imgResponse = await http.get(Uri.parse(imageUrl))
              .timeout(const Duration(seconds: 30));
          if (imgResponse.statusCode == 200) {
            return imgResponse.bodyBytes;
          }
          throw Exception('Failed to download result image: ${imgResponse.statusCode}');
        }
      }
      throw Exception('Unexpected IDM-VTON response format: ${response.body.substring(0, 200)}');
    } else {
      throw Exception('IDM-VTON API Error (${response.statusCode}): ${response.body.substring(0, 300)}');
    }
  }
}
