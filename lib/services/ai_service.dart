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

    final geminiAnalysisPrompt =
        'You are a professional fashion designer and tailor assistant.\n'
        'An AI fashion model is being generated with the following appearance:\n'
        '$profileDesc\n\n'
        'Style preferences: $styleString\n\n'
        'Body Measurements (inches):\n$measurementString\n\n'
        'Design References: $refNote\n\n'
        '${customInstructions.isNotEmpty ? "Additional instructions: $customInstructions\n\n" : ""}'
        'TASK: Based on the STYLE PREFERENCES above, determine which garment pieces '
        'are needed for this outfit (e.g. Kameez, Salwar, Dupatta, Saree, Blouse, '
        'Lehenga, Jacket, Trousers, Shirt, Skirt, etc.). '
        'For each piece, estimate the fabric quantity in gauge or inches. '
        'If the style preferences are too vague or non-specific to determine the '
        'garment pieces and quantities, set the "insufficient" flag to true.\n\n'
        'Output a valid JSON block with EXACTLY these fields:\n'
        '- "insufficient": true or false\n'
        '- "garments": an array of objects, each with "name" (garment piece) and '
        '"quantity" (e.g. "2.5 Gauge", "3 meters", "1.5 inches"). Empty array if insufficient.\n'
        '- "image_generation_prompt": a concise 80-word vivid prompt describing the '
        'finished outfit on the AI fashion model. Focus on outfit design, colours, '
        'fabric, and styling. Keep model description brief.\n\n'
        'Format:\n'
        '{"insufficient":false,"garments":[{"name":"Kameez","quantity":"2.5 Gauge"},{"name":"Salwar","quantity":"3 Gauge"}],"image_generation_prompt":"..."}';

    onStatus?.call('Analysing design references with Gemini...');

    Map<String, String> fabricEstimates = {};
    String imagePrompt =
        'A photorealistic full-body fashion shot. $profileDesc '
        'Wearing a beautifully tailored outfit. Style: $styleString. '
        'Clean, minimal background. Professional fashion photography lighting.';

    // Use first reference image as Gemini visual context if available
    final Uint8List? visualContext =
        referenceImageBytes.isNotEmpty ? referenceImageBytes.first : null;

    try {
      final geminiText = await testGemini(
        apiKey: geminiApiKey,
        prompt: geminiAnalysisPrompt,
        imageBytes: visualContext,
      );
      final startIdx = geminiText.indexOf('{');
      final endIdx = geminiText.lastIndexOf('}');
      if (startIdx != -1 && endIdx != -1) {
        final parsed = jsonDecode(geminiText.substring(startIdx, endIdx + 1))
            as Map<String, dynamic>;

        final isInsufficient = parsed['insufficient'] as bool? ?? false;
        if (isInsufficient) {
          fabricEstimates = {
            '_note':
                'Not enough style description to estimate fabric quantities.',
          };
        } else {
          final garments = parsed['garments'] as List<dynamic>? ?? [];
          if (garments.isEmpty) {
            fabricEstimates = {
              '_note':
                  'Not enough style description to estimate fabric quantities.',
            };
          } else {
            fabricEstimates = {
              for (final g in garments)
                (g['name'] as String? ?? 'Piece'):
                    (g['quantity'] as String? ?? '—'),
            };
          }
        }

        if (parsed['image_generation_prompt'] != null) {
          imagePrompt = parsed['image_generation_prompt'] as String;
        }
      }
    } catch (e) {
      // Non-fatal: leave fabricEstimates empty and continue with image generation
      fabricEstimates = {
        '_note': 'Could not estimate fabric requirements at this time.',
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
