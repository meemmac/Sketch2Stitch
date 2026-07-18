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
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
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

  /// Generate an image using Gemini's native image generation capability.
  /// Uses the same API key as the text Gemini call.
  /// Accepts an optional list of input images (person, garment, references).
  ///
  /// Model list confirmed via ListModels against a real API key (July 2026).
  /// Ordered to put the model most likely to have free-tier quota headroom
  /// first. On a 429 (quota exceeded) for one model, we move on to the next
  /// rather than giving up, and retry once with a short backoff before
  /// declaring total failure.
  static Future<Uint8List> generateImageWithGemini({
    required String apiKey,
    required String prompt,
    List<Uint8List> inputImages = const [],
    String mimeType = 'image/jpeg',
  }) async {
    final List<String> imageModels = [
      'gemini-2.5-flash-image',
      'gemini-3.1-flash-lite-image',
      'gemini-3.1-flash-image',
      'gemini-3-pro-image',
    ];

    String lastError = '';

    for (final model in imageModels) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );

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
            for (final part in parts2) {
              if (part['inlineData'] != null) {
                final base64Img = part['inlineData']['data'] as String;
                return base64Decode(base64Img);
              }
            }
            lastError = 'Model $model returned 200 but no image part in response';
            break; // no point retrying same model, move to next model
          } else if (response.statusCode == 429) {
            lastError = 'Model $model quota exceeded (429): ${response.body}';
            if (attempt == 0) {
              debugPrint('[VirtualTrial] $model hit 429, waiting 3s before one retry...');
              await Future.delayed(const Duration(seconds: 3));
              continue; // retry same model once
            }
            break; // give up on this model, try next
          } else {
            lastError = 'Model $model returned (${response.statusCode}): ${response.body}';
            break; // non-retryable error, move to next model
          }
        } catch (e) {
          lastError = 'Model $model threw: ${e.toString()}';
          break;
        }
      }
    }

    throw Exception('Gemini image generation failed after all models. Last error: $lastError');
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
    required String hfToken, // kept for signature compatibility; unused now
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
        '1. Carefully inspect the Additional Instructions and Style Preferences to identify what specific garment parts are being requested (e.g. Saree, Blouse, Shirt, Dress, Trousers, Lehenga, Kameez, Salwar, etc.).\n'
        '2. If the user\'s instructions and style preferences are empty, vague, or do not describe any garments to make, return an empty array [] for the "garments" key.\n'
        '3. For each identified garment piece, calculate the fabric quantity required using the body measurements provided. Express the quantity in BOTH Gauge and Meters (e.g., "2.5 Gauge / 2.3 meters"). For smaller parts, accents, or trims, use inches.\n'
        '4. Write a vivid 80-word image-generation prompt describing the finished outfit on the model.\n\n'
        'CRITICAL: Output ONLY a raw, valid JSON block. Do NOT wrap it in markdown. Do NOT add explanation text. Format exactly like this:\n'
        '{"garments":[{"name":"[Garment Name]","quantity":"[Value]"}],"image_generation_prompt":"[Prompt]"}';

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
        if (rawGarments is List) {
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
        'Garment Piece': 'No enough data',
        '_note': 'Estimated standard fabric requirements could not be determined due to insufficient description.'
      };
    }

    // 4. Generate image — Gemini only (free tier). No Hugging Face call:
    // HF's free serverless inference API no longer serves any image models
    // (confirmed 410/400 across FLUX and Stable Diffusion checkpoints), so
    // calling it only adds delay before an inevitable failure.
    onStatus?.call('Generating try-on preview with Google Gemini...');
    final resultBytes = await generateImageWithGemini(
      apiKey: geminiApiKey,
      prompt: imagePrompt,
      inputImages: referenceImageBytes,
    );

    return (resultBytes, fabricEstimates);
  }
}