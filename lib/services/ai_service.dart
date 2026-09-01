import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/appearance_profile.dart';
import '../utils/api_config.dart';


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
      // 'gemini-2.0-flash' removed: model was shut down June 1, 2026 and
      // dropped from the free tier June 9, 2026 — calls to it now 404.
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
      'gemini-2.5-flash-image', // confirmed free tier (500 RPD) as of Aug 2026.
      // Note: gemini-2.5-flash-image is scheduled to shut down Oct 2, 2026 —
      // revisit this list before then.

      // Everything below has NO free tier (paid-only, or unconfirmed) as of
      // Aug 2026 — commented out so a billed account never gets silently
      // charged. Uncomment individually if/when you decide to pay for them:
      // 'gemini-3.1-flash-lite-image', // free-tier status unconfirmed for the image variant
      // 'gemini-3.1-flash-image',      // confirmed paid-only, no free tier
      // 'gemini-3-pro-image',          // confirmed paid-only, no free tier (429 limit:0)
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
            debugPrint('[VirtualTrial] $lastError');
            break; // no point retrying same model, move to next model
          } else if (response.statusCode == 429) {
            lastError = 'Model $model quota exceeded (429): ${response.body}';
            debugPrint('[VirtualTrial] $lastError');
            if (attempt == 0) {
              debugPrint('[VirtualTrial] $model hit 429, waiting 3s before one retry...');
              await Future.delayed(const Duration(seconds: 3));
              continue; // retry same model once
            }
            break; // give up on this model, try next
          } else {
            lastError = 'Model $model returned (${response.statusCode}): ${response.body}';
            debugPrint('[VirtualTrial] $lastError');
            break; // non-retryable error, move to next model
          }
        } catch (e) {
          lastError = 'Model $model threw: ${e.toString()}';
          debugPrint('[VirtualTrial] $lastError');
          break;
        }
      }
    }

    throw Exception('Gemini image generation failed after all models. Last error: $lastError');
  }

  /// Downscales [bytes] so neither side exceeds [maxSide], returning PNG bytes.
  ///
  /// Cloudflare rejects input images that are 512x512 or larger, so every
  /// reference photo has to be shrunk before it goes into the multipart body.
  /// Uses `dart:ui` rather than the `image` package so this needs no new
  /// dependency.
  static Future<Uint8List> _downscaleForCloudflare(
    Uint8List bytes, {
    int maxSide = 480,
  }) async {
    final descriptor = await ui.ImageDescriptor.encoded(
      await ui.ImmutableBuffer.fromUint8List(bytes),
    );
    final w = descriptor.width;
    final h = descriptor.height;
    descriptor.dispose();

    // Already small enough — send as-is.
    if (w <= maxSide && h <= maxSide) return bytes;

    final scale = maxSide / (w > h ? w : h);
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: (w * scale).round(),
      targetHeight: (h * scale).round(),
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();

    if (data == null) return bytes;
    return data.buffer.asUint8List();
  }

  /// Generates an image with Cloudflare Workers AI (FLUX.2 [klein] 4B).
  ///
  /// Unlike Gemini's image models — which have no free tier as of Sep 2026 —
  /// Workers AI includes 10,000 neurons/day at no charge on the free plan.
  /// A 1024x1024 edit costs roughly 126 neurons, so this supports on the order
  /// of 75 try-ons per day across all users before the daily quota resets.
  ///
  /// The model takes multipart/form-data (NOT JSON): a `prompt` field plus up
  /// to four binary images named `input_image_0` .. `input_image_3`, each of
  /// which must be smaller than 512x512. It returns the result as a base64
  /// string under `result.image`.
  static Future<Uint8List> generateImageWithCloudflare({
    required String accountId,
    required String apiToken,
    required String prompt,
    List<Uint8List> inputImages = const [],
    int width = 1024,
    int height = 1024,
    String model = '@cf/black-forest-labs/flux-2-klein-4b',
  }) async {
    if (accountId.isEmpty || apiToken.isEmpty) {
      throw Exception(
        'Cloudflare credentials missing — set CF_ACCOUNT_ID and CF_API_TOKEN.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudflare.com/client/v4/accounts/$accountId/ai/run/$model',
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiToken'
      ..fields['prompt'] = prompt
      ..fields['width'] = width.toString()
      ..fields['height'] = height.toString();

    // The model accepts at most 4 input images.
    final images = inputImages.take(4).toList();
    for (var i = 0; i < images.length; i++) {
      final resized = await _downscaleForCloudflare(images[i]);
      request.files.add(
        http.MultipartFile.fromBytes(
          'input_image_$i',
          resized,
          filename: 'input_image_$i.png',
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(
        'Cloudflare returned ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception('Cloudflare reported failure: ${response.body}');
    }

    final base64Img = data['result']?['image'] as String?;
    if (base64Img == null || base64Img.isEmpty) {
      throw Exception('Cloudflare returned no image: ${response.body}');
    }

    return base64Decode(base64Img);
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
        '3. For each identified garment piece, calculate the fabric quantity required using the body measurements provided. Express the quantity in BOTH Gauge and Inches (e.g., "2.5 Gauge / 90 inches").\n'
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

    // 4. Generate image — Cloudflare Workers AI first, Gemini as fallback.
    //
    // Cloudflare leads because it is the only genuinely free option: the free
    // Workers plan includes 10,000 neurons/day with no card on file. Gemini's
    // image models are all paid-only (verified against Google's pricing page,
    // Sep 2026 — every Nano Banana variant lists Free Tier "Not available"),
    // so the Gemini call below only succeeds on a billed account and is kept
    // purely as a fallback.
    //
    // No Hugging Face call: HF's free serverless inference API no longer
    // serves any image models (confirmed 410/400 across FLUX and Stable
    // Diffusion checkpoints), so calling it only adds delay before an
    // inevitable failure.
    Uint8List resultBytes;
    try {
      onStatus?.call('Generating try-on preview with Cloudflare Workers AI...');
      resultBytes = await generateImageWithCloudflare(
        accountId: APIConfig.cfAccountId,
        apiToken: APIConfig.cfApiToken,
        prompt: imagePrompt,
        inputImages: referenceImageBytes,
      );
    } catch (e) {
      debugPrint('[VirtualTrial] Cloudflare image generation failed: $e');
      onStatus?.call('Cloudflare unavailable — falling back to Google Gemini...');
      resultBytes = await generateImageWithGemini(
        apiKey: geminiApiKey,
        prompt: imagePrompt,
        inputImages: referenceImageBytes,
      );
    }

    return (resultBytes, fabricEstimates);
  }

  /// Estimate required fabric via Gemini based explicitly on mentioned garments.
  /// If insufficient style info is found, returns a map containing a `_error` key.
  static Future<Map<String, String>> estimateFabricWithGemini({
    required String geminiApiKey,
    required Map<String, TextEditingController> measurements,
    required List<String> stylePreferences,
    required String customInstructions,
  }) async {
    final measurementString =
        measurements.entries.map((e) => '${e.key}: ${e.value.text}').join('\n');

    final styleString = stylePreferences.isEmpty
        ? 'No specific style preference'
        : stylePreferences.join(', ');

    final geminiAnalysisPrompt =
        'You are a professional tailor, fashion designer, and garment estimator.\n\n'
        '=== BODY MEASUREMENTS (inches) ===\n'
        '$measurementString\n\n'
        '=== STYLE PREFERENCES & CUSTOM INSTRUCTIONS ===\n'
        'Preferences: $styleString\n'
        'Custom Instructions: $customInstructions\n\n'
        'TASK:\n'
        '1. Identify ALL components, elements, and accessories explicitly mentioned by the user in the style preferences or custom instructions. This includes but is not limited to: garment pieces (shirt, salwar, kameez, dupatta, skirt, etc.), trims and embellishments (lace, buttons, embroidery, ribbon, etc.).\n'
        '2. Do NOT assume, guess, or add any items that were NOT explicitly mentioned by the user.\n'
        '3. If the user\'s preferences and instructions are empty, too vague, or do not contain enough information to confidently identify any specific components, you MUST set the "error" key in the JSON response to exactly: "The provided style information is insufficient to generate a fabric estimation." and the "garments" list to an empty array [].\n'
        '4. If there is sufficient information, estimate the required quantity for EACH mentioned item:\n'
        '   - Give estimation only on the basis of body measurment given by the user. Do not add extra estimation.\n'
        '   - For fabric-based garments (salwar, kameez, shirt, etc.): Express in BOTH Gauge and Inches (e.g., "2.5 Gauge / 90 inches").\n'
        '   - For trims and lace: Express in Inches (e.g., "48 inches").\n'
        '   - For accessories (shoes, bag etc): Avoid them in fabric estimation unless they can be made of fabric and have value as measurement that enables to estimate.\n'
        '   - In this case, set "error" to null.\n\n'
        'CRITICAL: Output ONLY a raw, valid JSON block. Do NOT wrap it in markdown. Do NOT add explanation text. Format exactly like this:\n'
        '{"garments":[{"name":"[Item Name]","quantity":"[Value]"}],"error":null}';

    final responseText = await testGemini(
      apiKey: geminiApiKey,
      prompt: geminiAnalysisPrompt,
    );

    // Parse logic
    String cleaned = responseText
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final startIdx = cleaned.indexOf('{');
    final endIdx   = cleaned.lastIndexOf('}');

    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      final jsonStr = cleaned.substring(startIdx, endIdx + 1);
      final parsed  = jsonDecode(jsonStr) as Map<String, dynamic>;

      final errorMsg = parsed['error'];
      if (errorMsg != null && errorMsg.toString().trim().isNotEmpty) {
        return {
          '_error': errorMsg.toString().trim(),
        };
      }

      final rawGarments = parsed['garments'];
      if (rawGarments is List) {
        final Map<String, String> estimates = {};
        for (final g in rawGarments) {
          if (g is Map) {
            estimates[g['name'].toString().trim()] = g['quantity'].toString().trim();
          }
        }
        if (estimates.isEmpty) {
          return {
            '_error': 'The provided style information is insufficient to generate a fabric estimation.',
          };
        }
        return estimates;
      }
    }

    return {
      '_error': 'The provided style information is insufficient to generate a fabric estimation.',
    };
  }
}