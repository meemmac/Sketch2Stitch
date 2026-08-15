import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../models/appearance_profile.dart';
import '../../models/user_role.dart';
import '../../services/ai_service.dart';
import '../../services/user_session.dart';
import '../../services/virtual_trial_service.dart';
import '../../models/customer.dart' show kVirtualTrialMonthlyLimit;
import '../../widgets/top_feedback_banner.dart';
import '../../utils/api_config.dart';
import '../../widgets/dashboard_drawer.dart';
import 'home_screen.dart';
import 'package:gal/gal.dart';
import '../../widgets/color_wheel_picker.dart';
import '../../widgets/color_picker_row.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette & tokens
// ─────────────────────────────────────────────────────────────────────────────
const _sage = Color(0xFF4E8B6F);
const _sageDark = Color(0xFF2C5C44);
const _sagePale = Color(0xFFEEF6F0);
const _ink = Color(0xFF1A2C22);
const _cardBg = Color(0xFFFBFDF9);
const _border = Color(0xFFDDEBE3);

// The monthly quota itself lives with the Customer model (`vtUsed` /
// `vtResetDate` are fields on that document) and is imported above — flat
// limit, no tiers.

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
  final List<String>?
  prefillAssetImages; // NEW — retailer/product asset paths from Cart
  const VirtualTrialScreen({super.key, this.prefillAssetImages});

  @override
  State<VirtualTrialScreen> createState() => _VirtualTrialScreenState();
}

class _VirtualTrialScreenState extends State<VirtualTrialScreen>
    with TickerProviderStateMixin {
  // ── Pickers ────────────────────────────────────────────────────────────────
  final _picker = ImagePicker();

  // ── Design reference uploads ────────────────────────────────────────────────
  final List<XFile> _referenceImages = [];
  final List<String> _prefilledAssetImages = [];

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
  Color _hairBaseColor = _hairSwatches.first.$1;
  double _hairAdjustDelta = 0;
  Color _skinBaseColor =
      _skinSwatches[2].$1; // matches AppearanceProfile's default (medium)
  double _skinAdjustDelta = 0;
  Color? _customSkinColorValue; // set when user picks from the skin wheel
  final _customAccessoriesController = TextEditingController();

  // =========================================================================
  // FUTURE INTEGRATION PLACEHOLDER:
  // When linking Virtual Trial to Cart / Order details, these variables
  // will hold passed garment item parts, sketches, or measurements.
  // Example call: VirtualTrialScreen(prefillGarments: ['Kameez', 'Salwar'], measurements: ...)
  // =========================================================================
  final List<String> _prefilledGarmentParts = [];

  // ── Virtual Trial quota state ──────────────────────────────────────────────
  // Mirrors the signed-in customer's `vtUsed` / `vtResetDate` fields. Loaded
  // in initState and re-read from the server after every increment, so this is
  // a cache of Firestore rather than the source of truth.
  final VirtualTrialService _vtService = VirtualTrialService();

  String get _customerId => UserSession.instance.uid ?? '';

  int _vtUsed = 0;
  DateTime? _vtResetDate;

  int get _vtRemaining =>
      (kVirtualTrialMonthlyLimit - _vtUsed).clamp(0, kVirtualTrialMonthlyLimit);
  bool get _vtLimitReached => _vtUsed >= kVirtualTrialMonthlyLimit;

  @override
  void initState() {
    super.initState();
    // In future dev, bind these passed values to selection controllers:
    debugPrint('Autofill parts loaded: ${_prefilledGarmentParts.length}');

    if (widget.prefillAssetImages != null) {
      _prefilledAssetImages.addAll(widget.prefillAssetImages!);
    }

    _loadQuota();
  }

  /// Pulls the real quota off the Customer document, rolling the monthly
  /// window over first if it has elapsed.
  Future<void> _loadQuota() async {
    if (_customerId.isEmpty) return;
    try {
      final customer = await _vtService.resetVTUsageIfExpired(_customerId);
      if (!mounted) return;
      setState(() {
        _vtUsed = customer.vtUsed;
        _vtResetDate = customer.vtResetDate;
      });
    } on VirtualTrialServiceException catch (e) {
      // A quota we couldn't read shouldn't block the screen; generation
      // re-checks server-side before it spends anything.
      debugPrint('[VirtualTrial] Could not load quota: ${e.message}');
    }
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
  // ── Appearance mode toggle ──────────────────────────────────────
  // true = "Custom" tab (full picker shown), false = "Default" tab (collapsed)
  bool _isCustomAppearance = false;

  // ── Scroll & Animations ──────────────────────────────────────────────────────
  final _scrollController = ScrollController();

  late final AnimationController _resultAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _resultFade = CurvedAnimation(
    parent: _resultAnim,
    curve: Curves.easeOut,
  );

  // ── Pick helpers ─────────────────────────────────────────────────────────────
  Future<void> _pickReferenceImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;

      const validImageExtensions = {
        'jpg',
        'jpeg',
        'png',
        'heic',
        'heif',
        'webp',
        'gif',
        'bmp',
      };

      final images = picked.where((file) {
        final ext = file.path.split('.').last.toLowerCase();
        return validImageExtensions.contains(ext);
      }).toList();

      final rejectedCount = picked.length - images.length;

      if (images.isNotEmpty) {
        setState(() => _referenceImages.addAll(images));
      }

      if (rejectedCount > 0) {
        _showSnack(
          rejectedCount == 1
              ? 'Videos are not supported — 1 file was skipped.'
              : 'Videos are not supported — $rejectedCount files were skipped.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error picking images: $e');
    }
  }

  void _removeReference(int index) =>
      setState(() => _referenceImages.removeAt(index));

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    AppFeedback.show(context, msg, isError: isError);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  // ── Generation ─────────────────────────────────────────────────────────────
  /// Reads every reference image into bytes for the Gemini call, in the order
  /// they're shown: the cart's chosen colour options (Cloudinary URLs, or
  /// bundled asset paths for seeded demo products) followed by the customer's
  /// own uploads. Any single image that fails to load is skipped rather than
  /// failing the whole generation.
  Future<List<Uint8List>> _loadReferenceBytes() async {
    final bytes = <Uint8List>[];

    for (final path in _prefilledAssetImages) {
      try {
        if (path.startsWith('http')) {
          final response = await http
              .get(Uri.parse(path))
              .timeout(const Duration(seconds: 20));
          if (response.statusCode == 200) bytes.add(response.bodyBytes);
        } else {
          final data = await rootBundle.load(path);
          bytes.add(data.buffer.asUint8List());
        }
      } catch (e) {
        debugPrint('[VirtualTrial] Skipped reference "$path": $e');
      }
    }

    for (final file in _referenceImages) {
      try {
        bytes.add(await file.readAsBytes());
      } catch (e) {
        debugPrint('[VirtualTrial] Skipped upload "${file.path}": $e');
      }
    }

    return bytes;
  }

  Future<void> _generate() async {
    // ── Quota guard ────────────────────────────────────────────────────────
    // Checked against the cached value first (instant feedback), then against
    // Firestore, since the cache can be stale if a trial ran on another device.
    if (_vtLimitReached) {
      _showSnack(
        'You\'ve used all $kVirtualTrialMonthlyLimit trials this month. '
        'Your limit resets on ${_formatDate(_vtResetDate)}.',
      );
      return;
    }

    if (_customerId.isEmpty) {
      _showSnack('Please sign in again to run a virtual trial.');
      return;
    }

    try {
      final eligibility = await _vtService.checkVTEligibility(_customerId);
      if (!mounted) return;
      if (!eligibility.eligible) {
        setState(() => _vtUsed = eligibility.used);
        _showSnack(
          'You\'ve used all ${eligibility.limit} trials this month. '
          'Your limit resets on ${_formatDate(_vtResetDate)}.',
        );
        return;
      }
    } on VirtualTrialServiceException catch (e) {
      _showSnack(e.message);
      return;
    }

    const geminiKey = APIConfig.geminiApiKey;

    if (geminiKey.isEmpty || geminiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      _showSnack('Please set your Gemini API key in lib/utils/api_config.dart');
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
      customAccessories: _customAccessoriesController.text.trim(),
      customHairColor: _profile.customHairColor,
      customHairColorValue: _profile.customHairColorValue,
      customSkinColor: _profile.customSkinColor,
      customSkinColorValue: _profile.customSkinColorValue,
    );

    try {
      // 1. Load the reference images the result must actually be based on:
      //    the garments the customer picked in the cart (their chosen colour
      //    option) first, then any references they uploaded here.
      setState(() {
        _statusMessage = 'Loading your selected designs...';
      });
      final referenceBytes = await _loadReferenceBytes();

      // 2. One call: Gemini estimates the fabric AND generates the try-on
      //    image from those same references, so the preview shows the garment
      //    the customer chose rather than an unrelated stock photo.
      final (imageBytes, fabric) =
          await AIService.generateVirtualTrialFromProfile(
        geminiApiKey: geminiKey,
        hfToken: APIConfig.hfToken,
        profile: profileSnapshot,
        referenceImageBytes: referenceBytes,
        measurements: _measurements,
        stylePreferences: _selectedStyles.toList(),
        customInstructions: _customInstructionsController.text.trim(),
        onStatus: (status) {
          if (mounted) setState(() => _statusMessage = status);
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

      // ── Consume one trial on success ─────────────────────────────────────
      // Persisted first, then mirrored locally from what the server actually
      // stored — so the counter can never drift from the Customer document.
      try {
        final customer = await _vtService.incrementVTUsage(_customerId);
        if (mounted) {
          setState(() {
            _vtUsed = customer.vtUsed;
            _vtResetDate = customer.vtResetDate;
          });
        }
      } on VirtualTrialServiceException catch (e) {
        debugPrint('[VirtualTrial] Could not record usage: ${e.message}');
      }

      // Scroll down to results
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController
            .animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            )
            .catchError((_) {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        _showSnack('Error generating mock preview: $e');
      }
    }
  }

  Future<void> _downloadImage() async {
    if (_generatedImageBytes == null) return;
    try {
      // Check and request photo library access
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          _showSnack(
            'Gallery permission denied. Please enable permission to save.',
          );
          return;
        }
      }
      await Gal.putImageBytes(_generatedImageBytes!);
      _showSnack('Successfully saved to device photo gallery!');
    } catch (e) {
      _showSnack('Failed to save to gallery: $e');
    }
  }

  @override
  void dispose() {
    for (final c in _measurements.values) {
      c.dispose();
    }
    _customInstructionsController.dispose();
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
      drawer: const DashboardDrawer(initialRole: UserRole.customer),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildQuotaBanner(),
            const SizedBox(height: 20),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        tooltip: 'Back',
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UnifiedHomeScreen()),
            );
          }
        },
      ),
      automaticallyImplyLeading: false,
      backgroundColor: _sagePale,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: const Text(
        'AI Virtual Trial',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
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
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'See your imagination come true',
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
            'Design your perfect outfit on an AI-generated fashion model , no photo required.',
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

  // ── Quota banner ─────────────────────────────────────────────────────────
  Widget _buildQuotaBanner() {
    final remaining = _vtRemaining;
    final resetLabel = _formatDate(_vtResetDate);

    if (_vtLimitReached) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lock_clock_rounded,
              color: Colors.red.shade700,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your monthly limit of $kVirtualTrialMonthlyLimit trials has ended. '
                'It resets on $resetLabel.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool isLow = remaining <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLow ? Colors.amber.shade50 : _sagePale,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isLow ? Colors.amber.shade200 : _border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: isLow ? Colors.amber.shade800 : _sage,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$remaining of $kVirtualTrialMonthlyLimit trial${remaining == 1 ? '' : 's'} left this month'
              '${isLow ? ' — running low' : ''} · resets $resetLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isLow ? Colors.amber.shade900 : _sageDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Design References ───────────────────────────────────────────────────────
  // ── Design References ───────────────────────────────────────────────────────
  Widget _buildDesignReferences() {
    final bool hasImages =
        _referenceImages.isNotEmpty || _prefilledAssetImages.isNotEmpty;
    final int totalCount =
        _prefilledAssetImages.length + _referenceImages.length;
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
                        '$totalCount item${totalCount == 1 ? '' : 's'} added',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: totalCount,
                  itemBuilder: (_, i) {
                    if (i < _prefilledAssetImages.length) {
                      final path = _prefilledAssetImages[i];
                      // Cart lines carry Cloudinary URLs for real products
                      // and bundled asset paths for seeded demo data.
                      final isRemote = path.startsWith('http');
                      final provider = isRemote
                          ? NetworkImage(path) as ImageProvider
                          : AssetImage(path);
                      return _enlargeable(
                        provider,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image(image: provider, fit: BoxFit.cover),
                        ),
                      );
                    }
                    return _referenceThumb(i - _prefilledAssetImages.length);
                  },
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
                  border: Border.all(color: _sage.withAlpha(90), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _sage,
                      size: 32,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to add design references',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'garments · fabrics · sketches · patterns · accessories',
                      style: TextStyle(fontSize: 10, color: Colors.black38),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Wraps a thumbnail so tapping it opens the image full-screen, with a small
  /// corner badge so the affordance is visible. Grid thumbs are ~100pt wide,
  /// which is too small to judge a fabric or a print by.
  Widget _enlargeable(ImageProvider image, {required Widget child}) {
    return GestureDetector(
      onTap: () => _openImageViewer(image),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(
                Icons.zoom_out_map,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Full-screen, pinch-zoomable view of a single reference image.
  void _openImageViewer(ImageProvider image) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image(image: image, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(dialogContext).padding.top + 8,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceThumb(int index) {
    final image = FileImage(File(_referenceImages[index].path));
    return Stack(
      fit: StackFit.expand,
      children: [
        _enlargeable(
          image,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(image: image, fit: BoxFit.cover),
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
              child: const Icon(Icons.close, size: 13, color: Colors.white),
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
          _buildAppearanceTabs(),
          if (_isCustomAppearance) ...[
            const SizedBox(height: 16),
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
              child: ColorPickerRow(
                swatches: _skinSwatches.map((s) => s.$1).toList(),
                baseColor: _skinBaseColor,
                adjustDelta: _skinAdjustDelta,
                wheelPalette: _skinSwatches.map((s) => s.$1).toList(),
                wheelDialogTitle: 'Pick a Skin Tone',
                accent: _sage,
                pale: Colors.white,
                border: _border,
                onBaseChanged: (c) => setState(() {
                  _skinBaseColor = c;
                  final nearest = _skinSwatches.reduce(
                    (a, b) =>
                        (a.$1.value - c.value).abs() <
                            (b.$1.value - c.value).abs()
                        ? a
                        : b,
                  );
                  _profile.skinTone = nearest.$2;
                  _profileConfigured = true;
                }),
                onAdjustChanged: (d) => setState(() {
                  _skinAdjustDelta = d;
                  final hsl = HSLColor.fromColor(_skinBaseColor);
                  final adjusted = hsl
                      .withLightness((hsl.lightness + d).clamp(0.0, 1.0))
                      .toColor();
                  _profile.customSkinColorValue = adjusted;
                  _profile.customSkinColor = AppearanceProfile.colorToHex(
                    adjusted,
                  );
                  _profileConfigured = true;
                }),
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
                    selected: (v) =>
                        _profile.hairLength != HairLength.bald &&
                        _profile.hairStyle == v,
                    onTap: (v) => setState(() {
                      _profile.hairStyle = v;
                      _profileConfigured = true;
                    }),
                  ),
                ),
              ),
            ),

            // Hair Color
            _profileRow(
              label: 'Hair Color',
              child: ColorPickerRow(
                swatches: _hairSwatches.map((s) => s.$1).toList(),
                baseColor: _hairBaseColor,
                adjustDelta: _hairAdjustDelta,
                wheelPalette: null, // full hue wheel for hair
                wheelDialogTitle: 'Pick a Hair Color',
                accent: _sage,
                pale: Colors.white,
                border: _border,
                onBaseChanged: (c) => setState(() {
                  _hairBaseColor = c;
                  final match = _hairSwatches.where(
                    (s) => s.$1.value == c.value,
                  );
                  _profile.hairColor = match.isNotEmpty
                      ? match.first.$2
                      : HairColor.colorful;
                  _profileConfigured = true;
                }),
                onAdjustChanged: (d) => setState(() {
                  _hairAdjustDelta = d;
                  final hsl = HSLColor.fromColor(_hairBaseColor);
                  final adjusted = hsl
                      .withLightness((hsl.lightness + d).clamp(0.0, 1.0))
                      .toColor();
                  _profile.customHairColorValue = adjusted;
                  _profile.customHairColor = AppearanceProfile.colorToHex(
                    adjusted,
                  );
                  _profileConfigured = true;
                }),
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
                              color: selected ? _sage : _border,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                pi.$1,
                                size: 20,
                                color: selected ? Colors.white : _sage,
                              ),
                              Text(
                                pi.$2.displayName,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: selected
                                      ? Colors.white
                                      : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
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
                labels: (v) =>
                    v == FacialExpression.neutral ? '😐 Neutral' : '😊 Smile',
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
                      final selected = _profile.accessories.contains(acc);
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
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? _sage : _sagePale,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? _sage : _border,
                            ),
                          ),
                          child: Text(
                            acc.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Colors.black54,
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
                        hintText:
                            'Other custom accessories (e.g. Earrings, Bracelet, Tiara)...',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _sagePale,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.straighten_rounded, color: _sage, size: 18),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 10) / 2;
                final keys = _measurements.keys.toList();
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(keys.length, (i) {
                    final key = keys[i];
                    return SizedBox(
                      width: cellWidth,
                      height: 72,
                      child: TextField(
                        controller: _measurements[key],
                        decoration: InputDecoration(
                          labelText: key,
                          labelStyle: const TextStyle(fontSize: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _sage),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
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
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _sage : _sagePale,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: selected ? _sage : _border),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.black54,
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
                  'Describe your preferences and garment parts (e.g. "Kameez, Dupatta") for the best look and an accurate fabric estimation.',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
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
                horizontal: 14,
                vertical: 12,
              ),
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
              valueColor: AlwaysStoppedAnimation<Color>(_sage),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _sage, fontWeight: FontWeight.w600),
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
    final limitReached = _vtLimitReached;
    final disabled = _isLoading || limitReached;

    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? _sage.withAlpha(120) : _sage,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: disabled ? null : _generate,
        icon: Icon(
          limitReached ? Icons.lock_clock_rounded : Icons.auto_awesome_rounded,
          color: Colors.white,
        ),
        label: Text(
          limitReached
              ? 'Limit Reached · Resets ${_formatDate(_vtResetDate)}'
              : (_isLoading ? 'Generating…' : 'Generate AI Preview'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your AI Preview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              IconButton.filledTonal(
                onPressed: _downloadImage,
                icon: const Icon(Icons.download_rounded, color: _sageDark),
                style: IconButton.styleFrom(
                  backgroundColor: _sagePale,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                tooltip: 'Download Try-On Image',
              ),
            ],
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
          if (_fabricEstimates != null) _buildFabricLedger(_fabricEstimates!),
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
      (
        'Skin Tone',
        p.customSkinColorValue != null ? 'Custom shade' : p.skinTone.label,
      ),
      (
        'Hair',
        p.customHairColorValue != null
            ? '${p.hairLength.label} ${p.hairStyle.label} custom shade'
            : '${p.hairLength.label} ${p.hairStyle.label} ${p.hairColor.label}',
      ),
      ('Pose', p.pose.displayName),
      ('Expression', p.expression.label),
      (
        'Accessories',
        p.accessories.isEmpty
            ? 'None'
            : p.accessories.map((a) => a.label).join(', '),
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
              const Icon(Icons.person_pin_rounded, color: _sage, size: 18),
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
          ...rows.map(
            (row) => Padding(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabricLedger(Map<String, String> fabric) {
    if (fabric.containsKey('_error')) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fabric['_error']!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB45309),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
              Icon(Icons.content_cut_rounded, color: _sageDark, size: 18),
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
                    fontStyle: FontStyle.italic,
                  ),
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
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: parts.map((part) {
                      final isInch = part.toLowerCase().contains('inch');
                      final isGauge = part.toLowerCase().contains('gauge');
                      Color bg, border, fg;
                      if (isInch) {
                        bg = const Color(0xFFE8F0FE);
                        border = const Color(0xFFADC8F5);
                        fg = const Color(0xFF2558C1);
                      } else if (isGauge) {
                        bg = _sagePale;
                        border = _border;
                        fg = _sageDark;
                      } else {
                        bg = const Color(0xFFF3F4F6);
                        border = const Color(0xFFD1D5DB);
                        fg = const Color(0xFF374151);
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildAppearanceTabs() {
    Widget tab(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _sage : _sagePale,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? _sage : _border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Any', !_isCustomAppearance, () {
          setState(() {
            _isCustomAppearance = false;
            // reset profile back to defaults when leaving Custom
            _profile.ageGroup = AgeGroup.adult;
            _profile.gender = GenderPresentation.feminine;
            _profile.bodyShape = BodyShape.regular;
            _profile.height = ModelHeight.average;
            _profile.skinTone = SkinTone.medium;
            _profile.hairLength = HairLength.medium;
            _profile.hairStyle = HairStyle.straight;
            _profile.hairColor = HairColor.black;
            _profile.pose = ModelPose.standingFront;
            _profile.expression = FacialExpression.neutral;
            _profile.accessories.clear();
            _profile.customHairColorValue = null;
            _profile.customSkinColorValue = null;
            _profile.customHairColor = '';
            _profile.customSkinColor = '';
            _skinBaseColor = _skinSwatches[2].$1;
            _hairBaseColor = _hairSwatches.first.$1;
            _skinAdjustDelta = 0;
            _hairAdjustDelta = 0;
            _customAccessoriesController.clear();
          });
        }),
        const SizedBox(width: 8),
        tab('Custom', _isCustomAppearance, () {
          setState(() {
            _isCustomAppearance = true;
            _profileConfigured = true;
          });
        }),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
