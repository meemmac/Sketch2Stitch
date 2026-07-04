import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ai_service.dart';
import '../../utils/api_config.dart';

class AITestScreen extends StatefulWidget {
  const AITestScreen({super.key});

  @override
  State<AITestScreen> createState() => _AITestScreenState();
}

class _AITestScreenState extends State<AITestScreen> {
  final ImagePicker _picker = ImagePicker();

  // Uploaded images
  XFile? _personalImage;
  List<XFile> _referenceImages = [];

  // 13 Measurement Controllers
  final Map<String, TextEditingController> _measurements = {
    'Upper Bust / Over Bust': TextEditingController(text: '34"'),
    'Round Shoulder': TextEditingController(text: '38"'),
    'Hips': TextEditingController(text: '36"'),
    'Under Bust': TextEditingController(text: '30"'),
    'Bust': TextEditingController(text: '35"'),
    'Bust Span': TextEditingController(text: '7.5"'),
    'Shoulder to Hips': TextEditingController(text: '22"'),
    'Shoulder to Knee': TextEditingController(text: '38"'),
    'Shoulder to Under Bust': TextEditingController(text: '13.5"'),
    'Shoulder to Bust': TextEditingController(text: '9.5"'),
    'Thigh': TextEditingController(text: '20"'),
    'Knee': TextEditingController(text: '14"'),
    'Ankle': TextEditingController(text: '9"'),
  };

  // Custom Prompt Instruction (empty by default — user fills this in)
  final TextEditingController _promptController = TextEditingController();

  // Status and Results
  bool _isLoading = false;
  String _statusMessage = "";
  Uint8List? _generatedImageBytes;

  // Fabric Requirements structure
  Map<String, String> _fabricRequirements = {
    'Orna': '1 Gauge',
    'Kameez': '2 Gauge',
    'Salwar': '2.5 Gauge',
    'Embroidery': '1 pcs',
  };

  Future<void> _pickPersonalImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _personalImage = image;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking personal image: $e")),
      );
    }
  }

  Future<void> _pickReferenceImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _referenceImages.add(image);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking reference image: $e")),
      );
    }
  }

  void _removeReferenceImage(int index) {
    setState(() {
      _referenceImages.removeAt(index);
    });
  }

  Future<void> _generateVirtualTrial() async {
    const geminiKey = APIConfig.geminiApiKey;
    const hfToken = APIConfig.hfToken;

    if (geminiKey.isEmpty || geminiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please make sure Gemini API Key is set in lib/utils/api_config.dart")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Analyzing measurements & fabric elements using Gemini...";
      _generatedImageBytes = null;
    });

    // Hidden system prompt prepended before user's prompt
    final hiddenSystemPrompt = "System Instructions:\n"
        "- Use the uploaded personal image as the primary reference for the person's identity, body shape, pose, and proportions.\n"
        "- Generate a realistic, full-body image whenever possible.\n"
        "- Preserve the person's facial features, hairstyle, skin tone, and overall appearance.\n"
        "- Use all uploaded reference images (garment, fabric, embroidery, accessories, etc.) as design references only.\n"
        "- Incorporate the uploaded design elements and fabrics into a single coherent outfit.\n"
        "- Respect the provided body measurements to achieve a realistic fit.\n"
        "- Produce a clean, high-quality, photorealistic result.\n"
        "- Keep the background simple and uncluttered unless the user explicitly requests otherwise.\n"
        "- Follow any additional instructions provided by the user, but treat the uploaded images as the highest-priority references.\n\n"
        "User Prompt: ${_promptController.text}";

    String generatedPrompt = hiddenSystemPrompt;

    try {
      // 1. Collect all image bytes: personal image + all reference images
      Uint8List? primaryImageBytes;  // personal image for HF try-on
      Uint8List? geminiImageBytes;   // first available image sent to Gemini for visual context

      if (_personalImage != null) {
        primaryImageBytes = await File(_personalImage!.path).readAsBytes();
        geminiImageBytes = primaryImageBytes;
      }

      // Build list of all reference image bytes for context descriptions
      final List<Uint8List> allRefBytes = [];
      for (final ref in _referenceImages) {
        allRefBytes.add(await File(ref.path).readAsBytes());
      }
      // Use first reference image as Gemini visual context if no personal image
      if (geminiImageBytes == null && allRefBytes.isNotEmpty) {
        geminiImageBytes = allRefBytes.first;
      }
      // Fallback to bundled asset if nothing is uploaded
      if (geminiImageBytes == null) {
        final ByteData data = await rootBundle.load('assets/images/silk.jpg');
        geminiImageBytes = data.buffer.asUint8List();
      }

      // 2. Prepare structured measurement prompt details
      final measurementString = _measurements.entries.map((e) => "${e.key}: ${e.value.text}").join("\n");
      final refImageNote = allRefBytes.isNotEmpty
          ? "${allRefBytes.length} reference image(s) of garment/fabric/embroidery have been uploaded for design context."
          : "No reference images uploaded.";

      final geminiPrompt = "You are a professional tailor and clothing assistant.\n"
          "Analyze the body measurements and instructions provided to estimate fabric requirements and write an image prompt.\n\n"
          "Tailor Measurements:\n$measurementString\n\n"
          "Reference Images Context: $refImageNote\n\n"
          "Style Prompt/Instructions:\n$hiddenSystemPrompt\n\n"
          "Please output a valid JSON block containing exactly these fields:\n"
          "- 'orna': Estimated fabric required for Orna (e.g. '1 Gauge' or '2 meters')\n"
          "- 'kameez': Estimated fabric required for Kameez (e.g. '2 Gauge' or '2.5 meters')\n"
          "- 'salwar': Estimated fabric required for Salwar (e.g. '2.5 Gauge' or '3 meters')\n"
          "- 'embroidery': Estimated fabric/embroidery elements (e.g. '1 pcs' or 'Not required')\n"
          "- 'image_generation_prompt': A detailed prompt (up to 80 words) describing the finished tailored outfit on a model for the virtual trial image generator.\n\n"
          "Format your response as pure JSON like: {\"orna\": \"...\", \"kameez\": \"...\", \"salwar\": \"...\", \"embroidery\": \"...\", \"image_generation_prompt\": \"...\"}";

      try {
        // Call Gemini with personal/first reference image for visual context
        final geminiResponse = await AIService.testGemini(
          apiKey: geminiKey,
          prompt: geminiPrompt,
          imageBytes: geminiImageBytes,
        );

        // Parse JSON response from Gemini
        final rawJson = geminiResponse.substring(
          geminiResponse.indexOf('{'),
          geminiResponse.lastIndexOf('}') + 1,
        );
        final parsed = jsonDecode(rawJson);
        setState(() {
          _fabricRequirements = {
            'Orna': parsed['orna'] ?? '1 Gauge',
            'Kameez': parsed['kameez'] ?? '2 Gauge',
            'Salwar': parsed['salwar'] ?? '2.5 Gauge',
            'Embroidery': parsed['embroidery'] ?? '1 pcs',
          };
        });
        generatedPrompt = parsed['image_generation_prompt'] ?? hiddenSystemPrompt;
      } catch (geminiError) {
        // Log Gemini failure but proceed using fallback fabric requirements and user style instructions
        debugPrint("Gemini failed, using fallback fabric requirements: $geminiError");
        setState(() {
          _fabricRequirements = {
            'Orna': '1 Gauge',
            'Kameez': '2 Gauge',
            'Salwar': '2.5 Gauge',
            'Embroidery': '1 pcs',
          };
        });
      }

      // 3. Generate the virtual trial image
      Uint8List resultBytes;

      if (primaryImageBytes != null && allRefBytes.isNotEmpty) {
        // --- IDM-VTON path: person image + garment image → real try-on ---
        setState(() {
          _statusMessage =
              "Sending images to Virtual Try-On model (IDM-VTON)...\nThis may take 30–120 seconds if the model is waking up.";
        });

        resultBytes = await AIService.callVirtualTryOn(
          personImageBytes: primaryImageBytes,
          garmentImageBytes: allRefBytes.first,    // first reference = garment
          garmentDescription: generatedPrompt,     // Gemini's refined description
          hfToken: hfToken,
        );
      } else {
        // --- FLUX fallback: text-to-image only ---
        setState(() {
          _statusMessage =
              "No personal image or reference uploaded — generating from text via FLUX...";
        });

        resultBytes = await AIService.testHuggingFace(
          token: hfToken,
          prompt: generatedPrompt,
        );
      }

      setState(() {
        _generatedImageBytes = resultBytes;
        _isLoading = false;
        _statusMessage = "";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error generating virtual trial: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF6C9985); // Sage/Greenish-gray theme color
    const secondaryBgColor = Color(0xFFEEF6E9);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // Future dashboard drawer trigger
          },
        ),
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/transparent_logo.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        backgroundColor: secondaryBgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Back to Home",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Banner
                  const Text(
                    "Welcome to our\nvirtual trial.",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: Color(0xFF1E392A),
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Steps list
                  const Text(
                    "Steps",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  _buildStepItem("Upload at least one clear image of yourself", _personalImage != null),
                  _buildStepItem("Upload all elements and fabric", _referenceImages.isNotEmpty),
                  _buildStepItem("Review and edit your body measurements before generating the virtual trial", true),
                  _buildStepItem("Write clear instructions about the elements you have given and your preferences", _promptController.text.trim().isNotEmpty),

                  const SizedBox(height: 32),

                  // Uploads Hub
                  const Text(
                    "Attachment & Reference Upload",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E392A)),
                  ),
                  const SizedBox(height: 12),
                  
                  // Image inputs layout — fixed equal labels then equal cards
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal image slot
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(
                              height: 20,
                              child: Text(
                                "Personal Image",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildUploadCard(
                              "Your Photo",
                              _personalImage,
                              _pickPersonalImage,
                              themeColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Reference images list slot
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(
                              height: 20,
                              child: Text(
                                "Reference Images",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildUploadCard(
                              "Add Reference",
                              null,
                              _pickReferenceImage,
                              themeColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Render scrollable picked reference images if list is not empty
                  if (_referenceImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Uploaded references:",
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _referenceImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.file(
                                    File(_referenceImages[index].path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 14,
                                child: InkWell(
                                  onTap: () => _removeReferenceImage(index),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Measurements Form
                  const Text(
                    "Body Measurements (inches)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E392A)),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFFAFDF9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.6,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _measurements.length,
                        itemBuilder: (context, index) {
                          final key = _measurements.keys.elementAt(index);
                          final controller = _measurements[key]!;
                          return TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: key,
                              labelStyle: const TextStyle(fontSize: 11),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Instructions Prompt
                  const Text(
                    "Outfit Preferences & Instructions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E392A)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Describe the outfit details, colors, fabrics...",
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 32),

                  // Loading and Status
                  if (_isLoading) ...[
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(themeColor)),
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ] else if (_statusMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(color: Colors.red.shade800),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : _generateVirtualTrial,
                      icon: const Icon(Icons.auto_awesome, color: Colors.white),
                      label: const Text(
                        "Generate Virtual Trial",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Results Block
                  if (_generatedImageBytes != null) ...[
                    const Text(
                      "Try-On & Fabric Estimate Results",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E392A)),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Stack image and overlay source
                          Image.memory(
                            _generatedImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 350,
                          ),

                          // Fabric ledger
                          Container(
                            color: const Color(0xFFF1F5EE),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Estimated fabric required",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF2C4A3E),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._fabricRequirements.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                        ),
                                        Text(
                                          entry.value,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E392A),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // Disclaimer Link
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text(
                        "This bases on Google Gemini and Hugging Face generative AI models, please read the terms and conditions of https://gemini.google.com/policy-guidelines",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.close,
            color: isDone ? Colors.green.shade600 : Colors.black87,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF333333),
                fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(String label, XFile? file, VoidCallback onTap, Color themeColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140, // Consistent fixed height for equal dimensions
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0x07000000),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: themeColor, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
