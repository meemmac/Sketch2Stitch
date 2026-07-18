import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/appearance_profile.dart';
import '../../services/ai_service.dart';
import '../../utils/api_config.dart';
import '../../widgets/dashboard_drawer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette & tokens
// ─────────────────────────────────────────────────────────────────────────────
const _sage = Color(0xFF4E8B6F);
const _sageDark = Color(0xFF2C5C44);
const _sagePale = Color(0xFFEEF6F0);
const _ink = Color(0xFF1A2C22);
const _cardBg = Color(0xFFFBFDF9);
const _border = Color(0xFFDDEBE3);

// ─────────────────────────────────────────────────────────────────────────────
// Style-preference chip data
// ─────────────────────────────────────────────────────────────────────────────
const _styleChips = [
  'Traditional',
  'Modern',
  'Casual',
  'Formal',
  'Luxury',
  'Minimal',
  'Wedding',
  'Party Wear',
  'Office',
  'Summer',
  'Winter',
  'Vibrant Colors',
  'Neutral Colors',
  'Loose Fit',
  'Tailored Fit',
];

// Skin-tone swatches (display colour, label enum value)
const _skinSwatches = [
  (Color(0xFFF5D7B5), SkinTone.fair),
  (Color(0xFFEDC08A), SkinTone.light),
  (Color(0xFFD49A6A), SkinTone.medium),
  (Color(0xFFB87944), SkinTone.tan),
  (Color(0xFF8B5A2B), SkinTone.brown),
  (Color(0xFF4A2508), SkinTone.deep),
];

// Hair-colour swatches
const _hairSwatches = [
  (Color(0xFF1A1A1A), HairColor.black),
  (Color(0xFF6B3A2A), HairColor.brown),
  (Color(0xFFE8C97A), HairColor.blonde),
  (Color(0xFFB83A2A), HairColor.red),
  (Color(0xFF9E9E9E), HairColor.gray),
  (Color(0xFFF5F5F5), HairColor.white),
  (Color(0xFF9C27B0), HairColor.colorful),
];

// Pose icon data
const _poseIcons = [
  (Icons.accessibility_new_rounded, ModelPose.standingFront),
  (Icons.directions_walk, ModelPose.fortyFive),
  (Icons.switch_left_rounded, ModelPose.sideView),
  (Icons.directions_run_rounded, ModelPose.walking),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen widget
// ─────────────────────────────────────────────────────────────────────────────
class VirtualTrialScreen extends StatefulWidget {
  const VirtualTrialScreen({super.key});

  @override
  State<VirtualTrialScreen> createState() => _VirtualTrialScreenState();
}

class _VirtualTrialScreenState extends State<VirtualTrialScreen>
    with TickerProviderStateMixin {
  // ── Pickers ────────────────────────────────────────────────────────────────
  final _picker = ImagePicker();

  // ── Design reference uploads ────────────────────────────────────────────────
  final List<XFile> _referenceImages = [];

  // ── Appearance profile ──────────────────────────────────────────────────────
  final AppearanceProfile _profile = AppearanceProfile();

  // ── Measurements ────────────────────────────────────────────────────────────
  final Map<String, TextEditingController> _measurements = {
    'Upper Bust / Over Bust': TextEditingController(text: '34"'),
    'Round Shoulder': TextEditingController(text: '38"'),
    'Hips': TextEditingController(text: '36"'),
    'Under Bust': TextEditingController(text: '30"'),
    'Bust': TextEditingController(text: '35"'),
    'Waist': TextEditingController(text: '28"'),
    'Shoulder to Knee': TextEditingController(text: '38"'),
    'Shoulder to Under Bust': TextEditingController(text: '13.5"'),
    'Shoulder to Bust': TextEditingController(text: '9.5"'),
    'Thigh': TextEditingController(text: '20"'),
    'Knee': TextEditingController(text: '14"'),
    'Ankle': TextEditingController(text: '9"'),
    'Waist to Ankle': TextEditingController(text: '40"'),
    'Shoulder to Ankle': TextEditingController(text: '57"'),
  };

  final Set<String> _selectedStyles = {};
  final _customInstructionsController = TextEditingController();
  final _customHairColorController = TextEditingController();
  final _customAccessoriesController = TextEditingController();

  // =========================================================================
  // FUTURE INTEGRATION PLACEHOLDER:
  // When linking Virtual Trial to Cart / Order details, these variables
  // will hold passed garment item parts, sketches, or measurements.
  // Example call: VirtualTrialScreen(prefillGarments: ['Kameez', 'Salwar'], measurements: ...)
  // =========================================================================
  final List<String> _prefilledGarmentParts = []; 

  @override
  void initState() {
    super.initState();
    // In future dev, bind these passed values to selection controllers:
    debugPrint('Autofill parts loaded: ${_prefilledGarmentParts.length}');
  }

  // ── Generation state ────────────────────────────────────────────────────────
  bool _isLoading = false;
  String _statusMessage = '';
  Uint8List? _generatedImageBytes;
  Map<String, String>? _fabricEstimates;
  AppearanceProfile? _usedProfile; // snapshot shown in summary card

  // ── Progress tracking ──────────────────────────────────────────
  /// True once the user has tapped any appearance-profile control.
  bool _profileConfigured = false;
  /// True once the user has expanded the Advanced Measurements tile.
  bool _measurementsReviewed = false;

  // ── Scroll & Animations ──────────────────────────────────────────────────────
  final _scrollController = ScrollController();

  late final AnimationController _resultAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final Animation<double> _resultFade =
      CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut);

  // ── Pick helpers ─────────────────────────────────────────────────────────────
  Future<void> _pickReferenceImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() => _referenceImages.addAll(images));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error picking images: $e');
    }
  }

  void _removeReference(int index) =>
      setState(() => _referenceImages.removeAt(index));

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Generation ─────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    const geminiKey = APIConfig.geminiApiKey;
    const hfToken = APIConfig.hfToken;

    if (geminiKey.isEmpty || geminiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      _showSnack(
          'Please set your Gemini API key in lib/utils/api_config.dart');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparing your AI model...';
      _generatedImageBytes = null;
      _fabricEstimates = null;
      _usedProfile = null;
    });
    _resultAnim.reset();

    // Snapshot the profile so the summary card is stable
    final profileSnapshot = AppearanceProfile(
      ageGroup: _profile.ageGroup,
      gender: _profile.gender,
      bodyShape: _profile.bodyShape,
      height: _profile.height,
      skinTone: _profile.skinTone,
      hairLength: _profile.hairLength,
      hairStyle: _profile.hairStyle,
      hairColor: _profile.hairColor,
      pose: _profile.pose,
      expression: _profile.expression,
      accessories: Set.from(_profile.accessories),
      customHairColor: _customHairColorController.text.trim(),
      customAccessories: _customAccessoriesController.text.trim(),
    );

    try {
      // Collect reference image bytes
      final List<Uint8List> refBytes = [];
      for (final f in _referenceImages) {
        refBytes.add(await File(f.path).readAsBytes());
      }

      final (imageBytes, fabric) =
          await AIService.generateVirtualTrialFromProfile(
        geminiApiKey: geminiKey,
        hfToken: hfToken,
        profile: profileSnapshot,
        referenceImageBytes: refBytes,
        measurements: _measurements,
        stylePreferences: _selectedStyles.toList(),
        customInstructions: _customInstructionsController.text.trim(),
        onStatus: (s) {
          if (mounted) setState(() => _statusMessage = s);
        },
      );

      if (!mounted) return;
      setState(() {
        _generatedImageBytes = imageBytes;
        _fabricEstimates = fabric;
        _usedProfile = profileSnapshot;
        _isLoading = false;
        _statusMessage = '';
      });
      _resultAnim.forward();

      // Scroll down to results
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    for (final c in _measurements.values) {
      c.dispose();
    }
    _customInstructionsController.dispose();
    _customHairColorController.dispose();
    _customAccessoriesController.dispose();
    _resultAnim.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const DashboardDrawer(initialRole: AppUserRole.customer),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStepsList(),
            const SizedBox(height: 32),
            _buildDesignReferences(),
            const SizedBox(height: 28),
            _buildAppearanceProfile(),
            const SizedBox(height: 28),
            _buildAdvancedMeasurements(),
            const SizedBox(height: 28),
            _buildStylePreferences(),
            const SizedBox(height: 36),
            _buildStatusArea(),
            _buildGenerateButton(),
            const SizedBox(height: 40),
            if (_generatedImageBytes != null) _buildResultsBlock(),
            const SizedBox(height: 16),
            _buildDisclaimer(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: Builder(builder: (ctx) => IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
      )),
      automaticallyImplyLeading: false,
      title: Image.asset('assets/images/transparent_logo.png',
          height: 36, fit: BoxFit.contain),
      backgroundColor: _sagePale,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.black87),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _sage,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Back',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C5C44), Color(0xFF4E8B6F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Virtual Trial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Design your perfect outfit on an AI-generated fashion model — no photo required.',
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Steps list ─────────────────────────────────────────────────────────────
  Widget _buildStepsList() {
    final steps = [
      (
        'Upload design reference images (garments, fabrics, sketches…)',
        _referenceImages.isNotEmpty
      ),
      (
        'Configure your AI model appearance profile',
        _profileConfigured,
      ),
      (
        'Review body measurements if needed',
        _measurementsReviewed,
      ),
      (
        'Choose style preferences',
        _selectedStyles.isNotEmpty
      ),
      (
        'Generate AI Preview',
        _generatedImageBytes != null
      ),
    ];

    return _sectionCard(
      title: 'Getting Started',
      icon: Icons.checklist_rounded,
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final (text, done) = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done ? _sage : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : Text(
                            '${idx + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      color: done ? _ink : Colors.black54,
                      fontWeight:
                          done ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Design References ───────────────────────────────────────────────────────
  Widget _buildDesignReferences() {
    final bool hasImages = _referenceImages.isNotEmpty;
    return _sectionCard(
      title: 'Design References',
      icon: Icons.collections_outlined,
      subtitle:
          'Upload garments, fabrics, embroidery, patterns, accessories, sketches, inspiration photos, or colour palettes.',
      child: hasImages
          // ── Filled: count + Add More + grid ──────────────────────────────
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_referenceImages.length} item${_referenceImages.length == 1 ? '' : 's'} added',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    _smallButton(
                      icon: Icons.add_photo_alternate_outlined,
                      label: 'Add More',
                      onTap: _pickReferenceImages,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: _referenceImages.length,
                  itemBuilder: (_, i) => _referenceThumb(i),
                ),
              ],
            )
          // ── Empty: single centred upload card ────────────────────────────
          : GestureDetector(
              onTap: _pickReferenceImages,
              child: Container(
                width: double.infinity,
                height: 110,
                decoration: BoxDecoration(
                  color: _sagePale,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: _sage.withAlpha(90), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: _sage, size: 32),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to add design references',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black45),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'garments · fabrics · sketches · patterns · accessories',
                      style:
                          TextStyle(fontSize: 10, color: Colors.black38),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _referenceThumb(int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_referenceImages[index].path),
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeReference(index),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close,
                  size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ── Appearance Profile ──────────────────────────────────────────────────────
  Widget _buildAppearanceProfile() {
    return _sectionCard(
      title: 'Appearance Profile',
      icon: Icons.person_outline_rounded,
      subtitle: 'Configure how your AI fashion model looks.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age Group
          _profileRow(
            label: 'Age Group',
            child: _chipRow(
              values: AgeGroup.values,
              labels: (v) => v.label,
              selected: (v) => _profile.ageGroup == v,
              onTap: (v) => setState(() {
                _profile.ageGroup = v;
                _profileConfigured = true;
              }),
            ),
          ),

          // Gender Presentation
          _profileRow(
            label: 'Gender Presentation',
            child: _chipRow(
              values: GenderPresentation.values,
              labels: (v) => v.label,
              selected: (v) => _profile.gender == v,
              onTap: (v) => setState(() {
                _profile.gender = v;
                _profileConfigured = true;
              }),
            ),
          ),

          // Body Shape
          _profileRow(
            label: 'Body Shape',
            child: _chipRow(
              values: BodyShape.values,
              labels: (v) => v.label,
              selected: (v) => _profile.bodyShape == v,
              onTap: (v) => setState(() {
                _profile.bodyShape = v;
                _profileConfigured = true;
              }),
            ),
          ),

          // Height
          _profileRow(
            label: 'Height',
            child: _chipRow(
              values: ModelHeight.values,
              labels: (v) => v.label,
              selected: (v) => _profile.height == v,
              onTap: (v) => setState(() {
                _profile.height = v;
                _profileConfigured = true;
              }),
            ),
          ),

          // Skin Tone
          _profileRow(
            label: 'Skin Tone',
            child: _swatchRow(
              items: _skinSwatches
                  .map((s) => (s.$1, s.$2 == _profile.skinTone,
                      () => setState(() {
                            _profile.skinTone = s.$2;
                            _profileConfigured = true;
                          })))
                  .toList(),
              tooltip: (i) => _skinSwatches[i].$2.label,
              bordered: (i) => _skinSwatches[i].$2 == SkinTone.fair,
            ),
          ),

          // Hair Length
          _profileRow(
            label: 'Hair Length',
            child: _chipRow(
              values: HairLength.values,
              labels: (v) => v.label,
              selected: (v) => _profile.hairLength == v,
              onTap: (v) => setState(() {
                _profile.hairLength = v;
                _profileConfigured = true;
              }),
            ),
          ),

          // Hair Style (Disabled if Bald is selected)
          _profileRow(
            label: 'Hair Style',
            child: IgnorePointer(
              ignoring: _profile.hairLength == HairLength.bald,
              child: Opacity(
                opacity: _profile.hairLength == HairLength.bald ? 0.4 : 1.0,
                child: _chipRow(
                  values: HairStyle.values,
                  labels: (v) => v.label,
                  selected: (v) => _profile.hairLength != HairLength.bald && _profile.hairStyle == v,
                  onTap: (v) => setState(() {
                    _profile.hairStyle = v;
                    _profileConfigured = true;
                  }),
                ),
              ),
            ),
          ),

          // Hair Color (Only first 3 options as color swatches, otherwise text input)
          _profileRow(
            label: 'Hair Color',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _swatchRow(
                  items: _hairSwatches.take(3).map((s) => (
                    s.$1,
                    _profile.hairColor == s.$2,
                    () => setState(() {
                      _profile.hairColor = s.$2;
                      _profileConfigured = true;
                    })
                  )).toList(),
                  tooltip: (i) => _hairSwatches[i].$2.label,
                  bordered: (i) => false,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _profile.hairColor = HairColor.colorful;
                      _profileConfigured = true;
                    });
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _profile.hairColor == HairColor.colorful ? _sage : _border,
                            width: _profile.hairColor == HairColor.colorful ? 2 : 1,
                          ),
                          gradient: const SweepGradient(
                            colors: [Colors.red, Colors.yellow, Colors.blue, Colors.red],
                          ),
                        ),
                        child: _profile.hairColor == HairColor.colorful
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Other Custom Color',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (_profile.hairColor == HairColor.colorful) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _customHairColorController,
                      decoration: InputDecoration(
                        hintText: 'Enter hair color (e.g. Auburn, Silver, Pink)...',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _sage),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (val) {
                        setState(() {
                          _profileConfigured = true;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Pose
          _profileRow(
            label: 'Pose',
            child: Row(
              children: _poseIcons.map((pi) {
                final selected = _profile.pose == pi.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: pi.$2.displayName,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _profile.pose = pi.$2;
                        _profileConfigured = true;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected ? _sage : _sagePale,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: selected
                                  ? _sage
                                  : _border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(pi.$1,
                                size: 20,
                                color: selected
                                    ? Colors.white
                                    : _sage),
                            Text(
                              pi.$2.displayName,
                              style: TextStyle(
                                  fontSize: 8,
                                  color: selected
                                      ? Colors.white
                                      : Colors.black54,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Facial Expression
          _profileRow(
            label: 'Expression',
            child: _chipRow(
              values: FacialExpression.values,
              labels: (v) => v == FacialExpression.neutral
                  ? '😐 Neutral'
                  : '😊 Smile',
              selected: (v) => _profile.expression == v,
              onTap: (v) => setState(() {
                _profile.expression = v;
                _profileConfigured = true;
              }),
            ),
          ),

          // Accessories (multi-select + custom accessory text input)
          _profileRow(
            label: 'Accessories',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ModelAccessory.values.map((acc) {
                    final selected =
                        _profile.accessories.contains(acc);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _profile.accessories.remove(acc);
                        } else {
                          _profile.accessories.add(acc);
                        }
                        _profileConfigured = true;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? _sage : _sagePale,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected ? _sage : _border),
                        ),
                        child: Text(
                          acc.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _customAccessoriesController,
                    decoration: InputDecoration(
                      hintText: 'Other custom accessories (e.g. Earrings, Bracelet, Tiara)...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _sage),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (val) {
                      setState(() {
                        _profileConfigured = true;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Advanced Measurements ───────────────────────────────────────────────────
  Widget _buildAdvancedMeasurements() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _sagePale,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.straighten_rounded,
                color: _sage, size: 18),
          ),
          title: const Text(
            'Advanced Measurements',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          subtitle: const Text(
            'Tap to expand — pre-filled with standard measurements',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          onExpansionChanged: (expanded) {
            if (expanded && !_measurementsReviewed) {
              setState(() => _measurementsReviewed = true);
            }
          },
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _measurements.length,
              itemBuilder: (_, i) {
                final key =
                    _measurements.keys.elementAt(i);
                return TextField(
                  controller: _measurements[key],
                  decoration: InputDecoration(
                    labelText: key,
                    labelStyle: const TextStyle(fontSize: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _sage),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Style Preferences ───────────────────────────────────────────────────────
  Widget _buildStylePreferences() {
    return _sectionCard(
      title: 'Style Preferences',
      icon: Icons.style_outlined,
      subtitle: 'Select all that apply — these guide the outfit generation.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notice banner explaining order page / dress parts for fabric calculation
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If you did not come from an order page, please mention the specific dress parts you want to buy (e.g., "Dupatta, Kameez, Salwar") in the box below so the AI can estimate the correct quantities.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withAlpha(180),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _styleChips.map((chip) {
              final selected = _selectedStyles.contains(chip);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedStyles.remove(chip);
                  } else {
                    _selectedStyles.add(chip);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? _sage : _sagePale,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: selected ? _sage : _border),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : Colors.black54,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customInstructionsController,
            decoration: InputDecoration(
              hintText:
                  'Any additional instructions (optional)…',
              hintStyle: const TextStyle(
                  fontSize: 13, color: Colors.black38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _sage),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Status / Loading ────────────────────────────────────────────────────────
  Widget _buildStatusArea() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(_sage)),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _sage, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    if (_statusMessage.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Text(
            _statusMessage,
            style: TextStyle(color: Colors.red.shade700),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Generate button ─────────────────────────────────────────────────────────
  Widget _buildGenerateButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLoading ? _sage.withAlpha(120) : _sage,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isLoading ? null : _generate,
        icon: const Icon(Icons.auto_awesome_rounded,
            color: Colors.white),
        label: Text(
          _isLoading ? 'Generating…' : 'Generate AI Preview',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      ),
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────────
  Widget _buildResultsBlock() {
    return FadeTransition(
      opacity: _resultFade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your AI Preview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 16),

          // Preview image
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Image.memory(
              _generatedImageBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 20),

          // Model summary card
          if (_usedProfile != null) _buildModelSummaryCard(_usedProfile!),
          const SizedBox(height: 16),

          // Fabric ledger
          if (_fabricEstimates != null)
            _buildFabricLedger(_fabricEstimates!),
        ],
      ),
    );
  }

  Widget _buildModelSummaryCard(AppearanceProfile p) {
    final rows = <(String, String)>[
      ('Age Group', p.ageGroup.label),
      ('Gender', p.gender.label),
      ('Body Shape', p.bodyShape.label),
      ('Height', p.height.label),
      ('Skin Tone', p.skinTone.label),
      ('Hair',
          '${p.hairLength.label} ${p.hairStyle.label} ${p.hairColor.label}'),
      ('Pose', p.pose.displayName),
      ('Expression', p.expression.label),
      (
        'Accessories',
        p.accessories.isEmpty
            ? 'None'
            : p.accessories.map((a) => a.label).join(', ')
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _sagePale,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_rounded,
                  color: _sage, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Model Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        row.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFabricLedger(Map<String, String> fabric) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.content_cut_rounded,
                  color: _sageDark, size: 18),
              SizedBox(width: 8),
              Text(
                'Estimated Fabric Required',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...fabric.entries.map((e) {
            // Special: a note row (no garment, just informational text)
            if (e.key == '_note') {
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Text(
                  e.value,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                      fontStyle: FontStyle.italic),
                ),
              );
            }
            // Normal garment row: name + quantity chips
            final parts = e.value
                .split('/')
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: parts.map((part) {
                      final isInch  = part.toLowerCase().contains('inch');
                      final isMeter = part.toLowerCase().contains('meter');
                      Color bg, border, fg;
                      if (isInch) {
                        bg = const Color(0xFFE8F0FE);
                        border = const Color(0xFFADC8F5);
                        fg = const Color(0xFF2558C1);
                      } else if (isMeter) {
                        bg = const Color(0xFFFFF8E1);
                        border = const Color(0xFFFFCC80);
                        fg = const Color(0xFFBF7800);
                      } else {
                        // Gauge
                        bg = _sagePale;
                        border = _border;
                        fg = _sageDark;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          part,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: fg,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Disclaimer ──────────────────────────────────────────────────────────────
  Widget _buildDisclaimer() {
    return const Text(
      'Powered by Google Gemini and Hugging Face generative AI. '
      'Results are AI-generated and intended as creative references only. '
      'Please review google.com/gemini/policy-guidelines for usage terms.',
      style: TextStyle(fontSize: 10, color: Colors.black38),
      textAlign: TextAlign.center,
    );
  }

  // ── Helpers / primitives ────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _sagePale,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _sage, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _profileRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }

  Widget _chipRow<T>({
    required List<T> values,
    required String Function(T) labels,
    required bool Function(T) selected,
    required void Function(T) onTap,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: values.map((v) {
        final sel = selected(v);
        return GestureDetector(
          onTap: () => onTap(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? _sage : _sagePale,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? _sage : _border),
            ),
            child: Text(
              labels(v),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.black54,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _swatchRow({
    required List<(Color, bool, VoidCallback)> items,
    required String Function(int) tooltip,
    bool Function(int)? bordered,
  }) {
    return Row(
      children: items.asMap().entries.map((e) {
        final i = e.key;
        final (color, selected, onTap) = e.value;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: tooltip(i),
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? _sage
                        : (bordered?.call(i) ?? false)
                            ? Colors.grey.shade300
                            : Colors.transparent,
                    width: selected ? 3 : 1.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _sage.withAlpha(100),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check,
                        size: 15, color: Colors.white)
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _sagePale,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _sage),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _sage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
