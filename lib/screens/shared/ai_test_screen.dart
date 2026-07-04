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

  // Custom Prompt Instruction
  final TextEditingController _promptController = TextEditingController(
    text: "A premium white Kameez salwar suite with gorgeous pink and green floral embroidery details on the neck and matching white dupatta (orna) drape, worn by a South Asian female model in studio lighting.",
  );

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

    String generatedPrompt = _promptController.text;

    try {
      // 1. Prepare image bytes (prefer reference images first, then personal image, then mock assets)
      Uint8List? refImageBytes;
      if (_referenceImages.isNotEmpty) {
        refImageBytes = await File(_referenceImages.first.path).readAsBytes();
      } else if (_personalImage != null) {
        refImageBytes = await File(_personalImage!.path).readAsBytes();
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

      try {
        // Call Gemini for structured estimation and image prompt generation
        final geminiResponse = await AIService.testGemini(
          apiKey: geminiKey,
          prompt: geminiPrompt,
          imageBytes: refImageBytes,
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
        generatedPrompt = parsed['image_generation_prompt'] ?? _promptController.text;
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

      // 3. Call Hugging Face to generate the virtual trial image
      setState(() {
        _statusMessage = "Generating try-on trial image using Stable Diffusion...";
      });

      final hfBytes = await AIService.testHuggingFace(
        token: hfToken,
        prompt: generatedPrompt,
      );

      setState(() {
        _generatedImageBytes = hfBytes;
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
                  
                  // Image inputs layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal image slot
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Personal Image",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Reference Images",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
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
                  Icon(Icons.add_a_photo, color: themeColor, size: 28),
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
