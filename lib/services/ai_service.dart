import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/appearance_profile.dart';
import '../utils/api_config.dart';


class AIService {
  /// Test the Google Gemini API with a prompt and optional image bytes.
  ///
  /// Set [jsonOutput] when the prompt asks for a JSON block: it switches the
  /// model into strict JSON mode and drops the temperature, so the response
  /// no longer needs to be scraped out of prose with regex fallbacks.
  static Future<String> testGemini({
    required String apiKey,
    required String prompt,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
    bool jsonOutput = false,
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
      ],
      if (jsonOutput)
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.2,
        },
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

  /// Bolt width assumed for every fabric estimate, in inches.
  ///
  /// Yardage depends on bolt width more than on any single body measurement,
  /// and the app never asks for it — so it is fixed here and surfaced to the
  /// customer as a note under the estimate rather than left implicit.
  static const int kAssumedFabricWidthInches = 44;

  /// 1 gaj (gauge) == 36 inches == 1 yard.
  static const int kInchesPerGaj = 36;

  /// Renders one garment row as `2.5 gaj / 90 inches`.
  ///
  /// The inch figure is computed here rather than asked of the model, so the
  /// two halves of the string can never disagree with each other.
  static String _formatGaj(num gaj) {
    final inches = (gaj * kInchesPerGaj).round();
    final gajStr =
        gaj == gaj.roundToDouble() ? gaj.toStringAsFixed(0) : gaj.toString();
    return '$gajStr gaj / $inches inches';
  }

  /// Parses the `garments` array shared by both estimation prompts.
  ///
  /// Each entry carries either a `gaj` number (fabric pieces) or an `inches`
  /// number (trims such as lace or piping). A legacy `quantity` string is
  /// still accepted so an older-shaped response is not thrown away.
  static Map<String, String> _parseGarments(dynamic rawGarments) {
    final estimates = <String, String>{};
    if (rawGarments is! List) return estimates;

    for (final g in rawGarments) {
      if (g is! Map) continue;
      final name = g['name']?.toString().trim();
      if (name == null || name.isEmpty) continue;

      final gaj = g['gaj'];
      final inches = g['inches'];

      if (gaj is num && gaj > 0) {
        estimates[name] = _formatGaj(gaj);
      } else if (inches is num && inches > 0) {
        estimates[name] = '${inches.round()} inches';
      } else {
        final legacy = g['quantity']?.toString().trim();
        if (legacy != null && legacy.isNotEmpty) estimates[name] = legacy;
      }
    }
    return estimates;
  }

  /// Extracts the first balanced-looking JSON object from [raw].
  ///
  /// Strict JSON mode makes this a no-op in the normal case; it still guards
  /// against a model that wraps the object in markdown fences.
  static Map<String, dynamic>? _extractJson(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }


  /// Generates an AI virtual trial image from an [AppearanceProfile] plus
  /// design-reference images.  No personal photo required.
  ///
  /// Returns a record of (imageBytes, fabricEstimates).
  static Future<(Uint8List, Map<String, String>)> generateVirtualTrialFromProfile({
    required String geminiApiKey,
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
    //
    // The garment pieces come from `customInstructions` — free text, with no
    // structured input anywhere in the UI. So the prompt asks Gemini to read
    // it the way a tailor would read a customer's message: a sentence, a
    // comma list, Bangla or Banglish, a composite name like "salwar kameez",
    // or nothing at all with only a design photo to go on. The style chips are
    // moods ('Traditional', 'Loose Fit'), never pieces, so they are given to
    // Gemini for the look but explicitly excluded as a source of components.
    final components = customInstructions.trim();
    final hasComponents = components.isNotEmpty;
    final hasReference = referenceImageBytes.isNotEmpty;

    final geminiAnalysisPrompt =
        'You are a professional tailor and garment estimator in Bangladesh.\n\n'
        '=== WHAT THE CUSTOMER WROTE (free text — may be a sentence, a list, '
        'Bangla, Banglish, or a mix) ===\n'
        '${hasComponents ? components : "(nothing written)"}\n\n'
        '=== BODY MEASUREMENTS (inches) ===\n'
        '$measurementString\n\n'
        '=== STYLE / MOOD (affects the look only, never the piece list) ===\n'
        '$styleString\n\n'
        '=== DESIGN REFERENCES ===\n'
        '$refNote\n\n'
        '=== MODEL APPEARANCE (context only — do NOT describe it back) ===\n'
        '$profileDesc\n\n'
        'STEP 1 — WORK OUT WHICH PIECES TO MAKE:\n'
        'a. Read the free text as a tailor would read a customer message. '
        'There is no fixed format: accept full sentences ("I want a long '
        'kameez with three-quarter sleeves and a matching dupatta"), bare '
        'lists ("kameez, salwar, orna"), Bangla or Banglish spellings '
        '(orna/urna = dupatta, jama = kameez/dress, pant/pyjama = trousers, '
        'panjabi = mens kurta, borka = burqa), plurals, typos and shorthand.\n'
        'b. Expand composite or set names into the pieces they are actually '
        'made of — e.g. "salwar kameez" or "three piece" gives Kameez + '
        'Salwar + Dupatta; "saree set" gives Saree + Blouse + Petticoat; '
        '"lehenga set" gives Lehenga + Choli + Dupatta. This is normalisation, '
        'not invention.\n'
        'c. Treat described features as part of the piece they belong to, not '
        'as separate pieces — sleeves, collar, neckline, pleats, lining and '
        'flare change that piece\'s quantity instead of adding a row. Trims '
        'bought by length (lace, piping, ribbon, border) DO get their own row.\n'
        'd. Normalise every name to its standard English garment name, '
        'capitalised (Kameez, Salwar, Dupatta, Saree, Blouse, Petticoat, '
        'Shirt, Trousers, Kurta, Panjabi, Lehenga, Choli, Skirt, Dress, Abaya).\n'
        '${hasReference ? "e. If the text names no piece at all, identify the garment from the attached design reference image and use that.\n" : ""}'
        'f. Do NOT derive a piece from the style/mood words alone, and do not '
        'add a piece the customer neither wrote nor showed you.\n'
        'g. Only if you still have nothing — no piece in the text'
        '${hasReference ? ", and none identifiable in the image" : ""} — return '
        '"garments": [] and set "error" to exactly: "Tell us what you want '
        'made (e.g. \\"a long kameez with a matching dupatta\\") so the fabric '
        'quantity can be estimated."\n\n'
        'STEP 2 — ESTIMATE FABRIC FOR EACH PIECE:\n'
        'h. Assume a bolt width of $kAssumedFabricWidthInches inches.\n'
        'i. Base every number strictly on the body measurements above, using '
        'only the measurements relevant to that piece, adjusted for the length, '
        'sleeve and fullness the customer described, plus normal seam and hem '
        'allowance. Do not pad beyond that.\n'
        'j. For fabric pieces return the quantity as a NUMBER of gaj in the '
        '"gaj" key (1 gaj = $kInchesPerGaj inches). For trims measured by '
        'length only return a NUMBER of inches in the "inches" key instead. '
        'Never write units inside the number.\n'
        'k. Skip non-fabric accessories (shoes, bags, jewellery) entirely.\n\n'
        'STEP 3 — IMAGE PROMPT:\n'
        'l. Write "image_generation_prompt" as an 80-word description of the '
        'FINISHED OUTFIT ONLY — fabric, colour, drape, cut, embroidery, '
        'silhouette. Do NOT describe the person: no face, skin, hair, body '
        'shape, height or pose. Those are added separately.\n\n'
        'Return a single JSON object, no markdown, in exactly this shape:\n'
        '{"garments":[{"name":"Kameez","gaj":2.5},{"name":"Lace trim","inches":48}],'
        '"error":null,"image_generation_prompt":"..."}';

    onStatus?.call('Analysing with Gemini — estimating fabric quantities...');

    Map<String, String> fabricEstimates = {};
    String? estimateError;
    String outfitPrompt =
        'a beautifully tailored outfit. Style: $styleString.';

    // Use first reference image as Gemini visual context if available
    final Uint8List? visualContext =
        referenceImageBytes.isNotEmpty ? referenceImageBytes.first : null;

    try {
      final geminiText = await testGemini(
        apiKey: geminiApiKey,
        prompt: geminiAnalysisPrompt,
        imageBytes: visualContext,
        jsonOutput: true,
      );

      final parsed = _extractJson(geminiText);
      if (parsed != null) {
        fabricEstimates = _parseGarments(parsed['garments']);

        final rawError = parsed['error']?.toString().trim();
        if (rawError != null && rawError.isNotEmpty && rawError != 'null') {
          estimateError = rawError;
        }

        final rawPrompt = parsed['image_generation_prompt']?.toString().trim();
        if (rawPrompt != null && rawPrompt.isNotEmpty) {
          outfitPrompt = rawPrompt;
        }
      } else {
        debugPrint('[VirtualTrial] No JSON object found in Gemini response.');
      }
    } catch (e, st) {
      debugPrint('[VirtualTrial] Fabric estimation error: $e\n$st');
    }

    if (fabricEstimates.isEmpty) {
      fabricEstimates = {
        '_error': estimateError ??
            'Tell us what you want made (e.g. "a long kameez with a matching '
                'dupatta") so the fabric quantity can be estimated.',
      };
    } else {
      fabricEstimates['_note'] =
          'Assumes $kAssumedFabricWidthInches" fabric width. '
          '1 gaj = $kInchesPerGaj inches.';
    }

    // The appearance profile is prepended verbatim instead of being left to
    // Gemini's rewrite. Previously the rewritten prompt was the only thing the
    // image model saw, so skin tone, hair, pose and body shape survived only
    // when Gemini happened to repeat them — and often they did not.
    final imagePrompt =
        'Full-body photorealistic fashion photograph, single subject. '
        '$profileDesc '
        'The model is wearing $outfitPrompt '
        'Render the model exactly as described above — skin tone, hair, body '
        'shape, height, pose and expression must match. '
        'Clean minimal studio background, professional fashion lighting.';

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
}
