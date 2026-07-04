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

  // Credentials controllers
  final TextEditingController _geminiKeyController = TextEditingController(
    text: APIConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE' ? '' : APIConfig.geminiApiKey,
  );
  final TextEditingController _hfTokenController = TextEditingController(
    text: APIConfig.hfToken == 'YOUR_HF_TOKEN_HERE' ? '' : APIConfig.hfToken,
  );

  // Uploaded images
  XFile? _selfPhoto;
  XFile? _garmentRef;
  XFile? _fabricRef;

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

  // Custom Prompt Instruction
  final TextEditingController _promptController = TextEditingController(
    text: "A premium white Kameez salwar suite with gorgeous pink and green floral embroidery details on the neck and matching white dupatta (orna) drape, worn by a South Asian female model in studio lighting.",
  );

  // Status and Results
  bool _isLoading = false;
  String _statusMessage = "";
  Uint8List? _generatedImageBytes;
  String? _imageSource;

  // Fabric Requirements structure
  Map<String, String> _fabricRequirements = {
    'Orna': '1 Gauge',
    'Kameez': '2 Gauge',
    'Salwar': '2.5 Gauge',
    'Embroidery': '1 pcs',
  };

  Future<void> _pickImage(int type) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          if (type == 1) _selfPhoto = image;
          if (type == 2) _garmentRef = image;
          if (type == 3) _fabricRef = image;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  Future<void> _generateVirtualTrial() async {
    final geminiKey = _geminiKeyController.text.trim();
    final hfToken = _hfTokenController.text.trim();

    if (geminiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please make sure Gemini API Key is set in credentials / api_config.dart")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Analyzing measurements & fabric elements using Gemini...";
      _generatedImageBytes = null;
    });

    try {
      // 1. Prepare image bytes (prefer fabric image first, then garment reference, then mock assets)
      Uint8List? refImageBytes;
      if (_fabricRef != null) {
        refImageBytes = await File(_fabricRef!.path).readAsBytes();
      } else if (_garmentRef != null) {
        refImageBytes = await File(_garmentRef!.path).readAsBytes();
      } else {
        // Fallback to loaded asset bytes if no custom image is uploaded
        final ByteData data = await rootBundle.load('assets/images/silk.jpg');
        refImageBytes = data.buffer.asUint8List();
      }

      // 2. Prepare structured measurement prompt details
      final measurementString = _measurements.entries.map((e) => "${e.key}: ${e.value.text}").join("\n");

      final geminiPrompt = "You are a professional tailor and clothing assistant.\n"
          "Analyze the body measurements and instructions provided to estimate fabric requirements and write an image prompt.\n\n"
          "Tailor Measurements:\n$measurementString\n\n"
          "Style Prompt/Instructions:\n${_promptController.text}\n\n"
          "Please output a valid JSON block containing exactly these fields:\n"
          "- 'orna': Estimated fabric required for Orna (e.g. '1 Gauge' or '2 meters')\n"
          "- 'kameez': Estimated fabric required for Kameez (e.g. '2 Gauge' or '2.5 meters')\n"
          "- 'salwar': Estimated fabric required for Salwar (e.g. '2.5 Gauge' or '3 meters')\n"
          "- 'embroidery': Estimated fabric/embroidery elements (e.g. '1 pcs' or 'Not required')\n"
          "- 'image_generation_prompt': A detailed prompt (up to 80 words) describing the finished tailored outfit on a model for the virtual trial image generator.\n\n"
          "Format your response as pure JSON like: {\"orna\": \"...\", \"kameez\": \"...\", \"salwar\": \"...\", \"embroidery\": \"...\", \"image_generation_prompt\": \"...\"}";

      // Call Gemini for structured estimation and image prompt generation
      final geminiResponse = await AIService.testGemini(
        apiKey: geminiKey,
        prompt: geminiPrompt,
        imageBytes: refImageBytes,
      );

      // Parse JSON response from Gemini
      String generatedPrompt = _promptController.text;
      try {
        final rawJson = geminiResponse.substring(
          geminiResponse.indexOf('{'),
          geminiResponse.lastIndexOf('}') + 1,
        );
        final parsed = jsonDecode(rawJson);
        setState(() {
          _fabricRequirements = {
            'Orna': parsed['orna'] ?? '1.5 Gauge',
            'Kameez': parsed['kameez'] ?? '2 Gauge',
            'Salwar': parsed['salwar'] ?? '2.5 Gauge',
            'Embroidery': parsed['embroidery'] ?? '1 pcs',
          };
        });
        generatedPrompt = parsed['image_generation_prompt'] ?? _promptController.text;
      } catch (e) {
        // Fallback: search for fabric requirements in text if JSON parsing fails
        print("Could not parse Gemini JSON, using fallback parsing: $e");
      }

      // 3. Call Hugging Face / Pollinations to generate the virtual trial image
      setState(() {
        _statusMessage = "Generating try-on trial image using Stable Diffusion...";
      });

      final hfResult = await AIService.testHuggingFace(
        token: hfToken,
        prompt: generatedPrompt,
      );

      setState(() {
        _generatedImageBytes = hfResult['bytes'] as Uint8List;
        _imageSource = hfResult['source'] as String;
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
    final primaryColor = Colors.green.shade800;
    final secondaryBgColor = const Color(0xFFEEF6E9);

    return Scaffold(
      backgroundColor: secondaryBgColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.checkroom, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              "Sketch2Stitch",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade50,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home, color: Colors.white, size: 18),
            label: const Text(
              "Back to Home",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Configuration/Credentials drawer
            ExpansionTile(
              title: const Text(
                "⚙️ Credentials Configuration",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _geminiKeyController,
                        decoration: const InputDecoration(
                          labelText: "Google Gemini API Key",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _hfTokenController,
                        decoration: const InputDecoration(
                          labelText: "Hugging Face Access Token (Optional)",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                )
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Banner matching the mockup
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
                  _buildStepItem("Upload at least one clear image of yourself"),
                  _buildStepItem("Upload all elements and fabric"),
                  _buildStepItem("Upload your customized designs"),
                  _buildStepItem("Fill up your information and insert your attachments with just one click"),
                  _buildStepItem("Write clear instructions about the elements you have given and your preferences"),

                  const SizedBox(height: 32),

                  // Uploads Hub
                  const Text(
                    "📤 Attachment & Reference Uploads",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildUploadCard("Your Photo", _selfPhoto, () => _pickImage(1))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildUploadCard("Garment Ref", _garmentRef, () => _pickImage(2))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildUploadCard("Fabric/Emb", _fabricRef, () => _pickImage(3))),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Measurements Form
                  const Text(
                    "📏 Body Measurements (inches)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    "✍️ Desired Outfit Preferences & Instructions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(primaryColor)),
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
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
                        backgroundColor: primaryColor,
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
                      "🎉 Try-On & Fabric Estimate Results",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Stack image and overlay source
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Image.memory(
                                _generatedImageBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 350,
                              ),
                              if (_imageSource != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  color: Colors.black54,
                                  child: Text(
                                    _imageSource!,
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                            ],
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
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
                      child: Text(
                        "This bases on generative AI model, please read the terms and conditions of https://gemini.google.com/policy-guidelines",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

  Widget _buildStepItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(String label, XFile? file, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: Colors.green.shade800, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
