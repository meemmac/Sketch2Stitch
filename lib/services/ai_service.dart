import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/appearance_profile.dart';


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

  /// Generate an image using Gemini's native image generation capability.
  /// Uses the same API key as the text Gemini call.
  /// Accepts an optional list of input images (person, garment, references).
  static Future<Uint8List> generateImageWithGemini({
    required String apiKey,
    required String prompt,
    List<Uint8List> inputImages = const [],
    String mimeType = 'image/jpeg',
  }) async {
    // Image-generation capable Gemini models, newest first
    final List<String> imageModels = [
      'gemini-2.0-flash-preview-image-generation',
      'gemini-3.1-flash-lite-image',
      'gemini-3.1-flash-image',
    ];

    String lastError = '';

    for (final model in imageModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        // Build parts: text prompt first, then all input images
        final List<Map<String, dynamic>> parts = [
          {'text': prompt},
        ];
        for (final imgBytes in inputImages) {
          parts.add({
            'inlineData': {
              'mimeType': mimeType,
              'data': base64Encode(imgBytes),
            }
          });
        }

        final body = {
          'contents': [
            {'parts': parts}
          ],
          'generationConfig': {
            'responseModalities': ['IMAGE', 'TEXT'],
          },
        };

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final parts2 = data['candidates'][0]['content']['parts'] as List;
          // Find the image part in the response
          for (final part in parts2) {
            if (part['inlineData'] != null) {
              final base64Img = part['inlineData']['data'] as String;
              return base64Decode(base64Img);
            }
          }
          lastError = 'Model $model returned 200 but no image part in response';
        } else {
          lastError = 'Model $model returned (${response.statusCode}): ${response.body}';
        }
      } catch (e) {
        lastError = 'Model $model threw: ${e.toString()}';
      }
    }

    throw Exception('Gemini image generation failed after all models. Last error: $lastError');
  }

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

  // ────────────────────────────────────────────────────────────────────────────
  // Profile-Based Virtual Trial (no personal photo)
  // ────────────────────────────────────────────────────────────────────────────


  /// Generates an AI virtual trial image from an [AppearanceProfile] plus
  /// design-reference images.  No personal photo required.
  ///
  /// Returns a record of (imageBytes, fabricEstimates).
  static Future<(Uint8List, Map<String, String>)> generateVirtualTrialFromProfile({
    required String geminiApiKey,
    required String hfToken,
    required AppearanceProfile profile,
    required List<Uint8List> referenceImageBytes,
    required Map<String, TextEditingController> measurements,
    required List<String> stylePreferences,
    required String customInstructions,
    void Function(String status)? onStatus,
  }) async {
    // 1. Build measurement string
    final measurementString =
        measurements.entries.map((e) => '${e.key}: ${e.value.text}').join('\n');

    // 2. Build style string
    final styleString = stylePreferences.isEmpty
        ? 'No specific style preference'
        : stylePreferences.join(', ');

    // 3. System instructions + profile description
    final profileDesc = profile.toPromptString();
    final refNote = referenceImageBytes.isEmpty
        ? 'No design references uploaded.'
        : '${referenceImageBytes.length} design reference image(s) uploaded (garments / fabrics / embroidery / accessories / sketches / patterns).';

    // ── Build the analysis prompt ──────────────────────────────────────────────
    // Priority order: custom instructions → style preferences → measurements
    final hasCustom = customInstructions.isNotEmpty;
    final hasStyle  = stylePreferences.isNotEmpty;

    final geminiAnalysisPrompt =
        'You are a professional tailor and fashion designer.\n\n'
        '=== BODY MEASUREMENTS (inches) ===\n'
        '$measurementString\n\n'
        '=== STYLE PREFERENCES ===\n'
        '${hasStyle ? styleString : "Not specified"}\n\n'
        '${hasCustom ? "=== ADDITIONAL INSTRUCTIONS ===\n$customInstructions\n\n" : ""}'
        '=== DESIGN REFERENCES ===\n'
        '$refNote\n\n'
        '=== AI MODEL APPEARANCE ===\n'
        '$profileDesc\n\n'
        'TASK:\n'
        '1. Identify every garment piece required for this outfit. '
        'Use the Additional Instructions and Style Preferences to determine the pieces '
        '(e.g. Kameez, Salwar, Dupatta, Saree, Blouse, Lehenga, Jacket, Trousers, Shirt, '
        'Embroidery panel, Lining, etc.).\n'
        '2. For each piece, use the body measurements above to calculate the fabric '
        'quantity required. You MUST express the fabric quantity in BOTH Gauge and Meters together in the '
        'same quantity string (e.g., "2.5 Gauge / 2.3 meters"). For smaller garment pieces or accents (like embroidery borders, '
        'cuffs, patches, or smaller elements), express the quantity in inches (e.g., "15 inches").\n'
        '3. Write a vivid 80-word image-generation prompt describing the finished outfit '
        'on the AI fashion model. Focus on the outfit colours, fabric, silhouette, and styling.\n\n'
        'CRITICAL: Output ONLY a raw, valid JSON block. Do NOT wrap it in ```json or ``` tags. Do NOT add any introductory or trailing text. It must be valid JSON in this exact format:\n'
        '{"garments":[{"name":"Kameez","quantity":"2.5 Gauge / 2.3 meters"},{"name":"Salwar","quantity":"3 Gauge / 2.7 meters"},{"name":"Embroidery Border","quantity":"18 inches"}],"image_generation_prompt":"..."}';

    onStatus?.call('Analysing with Gemini — estimating fabric quantities...');

    Map<String, String> fabricEstimates = {};
    String imagePrompt =
        'A photorealistic full-body fashion shot. $profileDesc '
        'Wearing a beautifully tailored outfit. Style: $styleString. '
        'Clean, minimal background. Professional fashion photography lighting.';

    // Use first reference image as Gemini visual context if available
    final Uint8List? visualContext =
        referenceImageBytes.isNotEmpty ? referenceImageBytes.first : null;

    String geminiText = '';
    try {
      geminiText = await testGemini(
        apiKey: geminiApiKey,
        prompt: geminiAnalysisPrompt,
        imageBytes: visualContext,
      );

      debugPrint('[VirtualTrial] Gemini raw response: $geminiText');

      // Strip any markdown code fences Gemini might wrap around JSON
      String cleaned = geminiText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final startIdx = cleaned.indexOf('{');
      final endIdx   = cleaned.lastIndexOf('}');

      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        final jsonStr = cleaned.substring(startIdx, endIdx + 1);
        final parsed  = jsonDecode(jsonStr) as Map<String, dynamic>;

        // ── Parse garments array (type-safe: use toString on every value) ──
        final rawGarments = parsed['garments'];
        if (rawGarments is List && rawGarments.isNotEmpty) {
          fabricEstimates = {
            for (final g in rawGarments)
              if (g is Map)
                g['name'].toString().trim(): g['quantity'].toString().trim(),
          };
        }

        // ── Parse image prompt ─────────────────────────────────────────────
        final rawPrompt = parsed['image_generation_prompt'];
        if (rawPrompt != null && rawPrompt.toString().trim().isNotEmpty) {
          imagePrompt = rawPrompt.toString().trim();
        }
      } else {
        debugPrint('[VirtualTrial] No JSON object found in Gemini response. Trying regex fallback...');
        // Fallback regex parser in case Gemini returned text instead of proper JSON
        final matches = RegExp(r'"name"\s*:\s*"([^"]+)"\s*,\s*"quantity"\s*:\s*"([^"]+)"').allMatches(cleaned);
        if (matches.isNotEmpty) {
          fabricEstimates = {
            for (final m in matches)
              m.group(1)!: m.group(2)!,
          };
        }
      }
    } catch (e, st) {
      debugPrint('[VirtualTrial] Fabric estimation error: $e\n$st');
      // If JSON parse failed, try matching patterns inside the error text
      if (geminiText.isNotEmpty) {
        try {
          final cleaned = geminiText
              .replaceAll(RegExp(r'```json\s*'), '')
              .replaceAll(RegExp(r'```\s*'), '')
              .trim();
          final matches = RegExp(r'"name"\s*:\s*"([^"]+)"\s*,\s*"quantity"\s*:\s*"([^"]+)"').allMatches(cleaned);
          if (matches.isNotEmpty) {
            fabricEstimates = {
              for (final m in matches)
                m.group(1)!: m.group(2)!,
            };
          }
        } catch (_) {}
      }
    }

    if (fabricEstimates.isEmpty) {
      fabricEstimates = {
        'Kameez': '2.5 Gauge / 2.3 meters',
        'Salwar': '3.0 Gauge / 2.7 meters',
        'Dupatta': '2.0 Gauge / 1.8 meters',
        'Embroidery Lace': '18 inches',
        '_note': 'Estimated standard salwar kameez fabric requirements.'
      };
    }

    // 4. Generate image
    onStatus?.call('Generating try-on preview with Google Gemini...');
    Uint8List resultBytes;
    try {
      resultBytes = await generateImageWithGemini(
        apiKey: geminiApiKey,
        prompt: imagePrompt,
        inputImages: referenceImageBytes,
      );
    } catch (_) {
      onStatus?.call('Gemini image failed. Retrying with Hugging Face FLUX...');
      resultBytes = await testHuggingFace(
        token: hfToken,
        prompt: imagePrompt,
      );
    }

    return (resultBytes, fabricEstimates);
  }
}
