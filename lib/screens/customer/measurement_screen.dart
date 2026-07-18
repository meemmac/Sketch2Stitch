import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// NOTE: Adjust this import to match your project structure.
// The Measurement model, repository, and Firebase logic are assumed to
// already exist in the project and are NOT created here.
import '../../models/measurement.dart';

/// Supported measurement input units.
enum MeasurementUnit { inch, cm, mm, meter }

extension MeasurementUnitX on MeasurementUnit {
  String get label {
    switch (this) {
      case MeasurementUnit.inch:
        return 'in';
      case MeasurementUnit.cm:
        return 'cm';
      case MeasurementUnit.mm:
        return 'mm';
      case MeasurementUnit.meter:
        return 'm';
    }
  }

  /// Converts a value expressed in this unit to inches.
  double toInches(double value) {
    switch (this) {
      case MeasurementUnit.inch:
        return value;
      case MeasurementUnit.cm:
        return value / 2.54;
      case MeasurementUnit.mm:
        return value / 25.4;
      case MeasurementUnit.meter:
        return value * 39.3701;
    }
  }

  /// Converts a value expressed in inches to this unit.
  double fromInches(double inches) {
    switch (this) {
      case MeasurementUnit.inch:
        return inches;
      case MeasurementUnit.cm:
        return inches * 2.54;
      case MeasurementUnit.mm:
        return inches * 25.4;
      case MeasurementUnit.meter:
        return inches / 39.3701;
    }
  }
}

/// Local, non-Firebase guide content for a single measurement field.
/// Images are bundled app assets; no network or database call is made.
class MeasurementGuideContent {
  const MeasurementGuideContent({
    required this.text,
    required this.assetPath,
  });

  final String text;
  final String assetPath;
}

/// Static guide content keyed by the Measurement model's field name.
/// Each entry expects a matching image at assets/images/guides/<key>.png
/// (registered in pubspec.yaml).
const Map<String, MeasurementGuideContent> kMeasurementGuides = {
  'upperBustCircumference': MeasurementGuideContent(
    text:
        'Wrap the tape across the fullest part of your chest, just above the '
        'bust, keeping it horizontal and snug but not tight.',
    assetPath: 'assets/images/guides/upperBustCircumference.png',
  ),
  'roundShoulderCircumference': MeasurementGuideContent(
    text:
        'Measure around the widest part of your shoulders, going over both '
        'shoulder tips and across the upper back.',
    assetPath: 'assets/images/guides/roundShoulderCircumference.png',
  ),
  'bustCircumference': MeasurementGuideContent(
    text:
        'Wrap the tape around the fullest part of your bust, keeping it '
        'level all the way around your back.',
    assetPath: 'assets/images/guides/bustCircumference.png',
  ),
  'underBustCircumference': MeasurementGuideContent(
    text:
        'Measure directly beneath your bust, where the band of a bra would '
        'sit, keeping the tape snug and horizontal.',
    assetPath: 'assets/images/guides/underBustCircumference.png',
  ),
  'hipsCircumference': MeasurementGuideContent(
    text:
        'Wrap the tape around the fullest part of your hips and buttocks, '
        'keeping it level all the way around.',
    assetPath: 'assets/images/guides/hipsCircumference.png',
  ),
  'shoulderToBust': MeasurementGuideContent(
    text:
        'Measure vertically from the top of your shoulder down to the '
        'bust point.',
    assetPath: 'assets/images/guides/shoulderToBust.png',
  ),
  'shoulderToUnderBust': MeasurementGuideContent(
    text:
        'Measure vertically from the top of your shoulder down to just '
        'beneath the bust.',
    assetPath: 'assets/images/guides/shoulderToUnderBust.png',
  ),
  'waist': MeasurementGuideContent(
    text:
        'Wrap the tape around the narrowest part of your natural waist, '
        'usually just above the belly button.',
    assetPath: 'assets/images/guides/waist.png',
  ),
  'shoulderToKnee': MeasurementGuideContent(
    text:
        'Measure vertically from the top of your shoulder down to the '
        'center of your knee.',
    assetPath: 'assets/images/guides/shoulderToKnee.png',
  ),
  'thigh': MeasurementGuideContent(
    text:
        'Wrap the tape around the fullest part of your upper thigh, keeping '
        'it level and snug but not tight.',
    assetPath: 'assets/images/guides/thigh.png',
  ),
  'knee': MeasurementGuideContent(
    text: 'Wrap the tape around the center of your knee while standing.',
    assetPath: 'assets/images/guides/knee.png',
  ),
  'ankle': MeasurementGuideContent(
    text:
        'Wrap the tape around the narrowest part of your ankle, just above '
        'the ankle bone.',
    assetPath: 'assets/images/guides/ankle.png',
  ),
  'waistToAnkle': MeasurementGuideContent(
    text:
        'Measure vertically from your natural waist down to the ankle bone.',
    assetPath: 'assets/images/guides/waistToAnkle.png',
  ),
  'shoulderToAnkle': MeasurementGuideContent(
    text:
        'Measure vertically from the top of your shoulder all the way down '
        'to the ankle bone.',
    assetPath: 'assets/images/guides/shoulderToAnkle.png',
  ),
};

/// Theme colors used across the measurement screen.
class _MeasurementColors {
  static const Color primaryGreen = Color(0xFF4CAF6D);
  static const Color darkGreen = Color(0xFF2E7D4F);
  static const Color background = Color(0xFFF6F9F7);
  static const Color cardWhite = Colors.white;
  static const Color labelText = Color(0xFF2B2B2B);
  static const Color subtleText = Color(0xFF8A8F8C);
  static const Color borderColor = Color(0xFFE2E8E4);
  static const Color errorRed = Color(0xFFE05353);
}

/// Screen that allows a user to view and update their body measurements.
///
/// This widget only handles UI state and unit conversion. Persistence is
/// delegated to [onSave], which should call into the existing
/// repository/update method with a fully-populated [Measurement] (in inches).
class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({
    super.key,
    required this.measurement,
    required this.onSave,
  });

  /// The current measurement record, with all values stored in inches.
  final Measurement measurement;

  /// Called when the user taps Save. Should persist [updated] via the
  /// existing repository. The screen does not perform persistence itself.
  final Future<void> Function(Measurement updated) onSave;

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  late final List<_MeasurementEntry> _entries;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entries = [
      _MeasurementEntry(
        label: 'Upper Bust Circumference',
        fieldKey: 'upperBustCircumference',
        initialInches: widget.measurement.upperBustCircumference,
      ),
      _MeasurementEntry(
        label: 'Round Shoulder Circumference',
        fieldKey: 'roundShoulderCircumference',
        initialInches: widget.measurement.roundShoulderCircumference,
      ),
      _MeasurementEntry(
        label: 'Bust Circumference',
        fieldKey: 'bustCircumference',
        initialInches: widget.measurement.bustCircumference,
      ),
      _MeasurementEntry(
        label: 'Under Bust Circumference',
        fieldKey: 'underBustCircumference',
        initialInches: widget.measurement.underBustCircumference,
      ),
      _MeasurementEntry(
        label: 'Hips Circumference',
        fieldKey: 'hipsCircumference',
        initialInches: widget.measurement.hipsCircumference,
      ),
      _MeasurementEntry(
        label: 'Shoulder to Bust',
        fieldKey: 'shoulderToBust',
        initialInches: widget.measurement.shoulderToBust,
      ),
      _MeasurementEntry(
        label: 'Shoulder to Under Bust',
        fieldKey: 'shoulderToUnderBust',
        initialInches: widget.measurement.shoulderToUnderBust,
      ),
      _MeasurementEntry(
        label: 'Waist',
        fieldKey: 'waist',
        initialInches: widget.measurement.waist,
      ),
      _MeasurementEntry(
        label: 'Shoulder to Knee',
        fieldKey: 'shoulderToKnee',
        initialInches: widget.measurement.shoulderToKnee,
      ),
      _MeasurementEntry(
        label: 'Thigh',
        fieldKey: 'thigh',
        initialInches: widget.measurement.thigh,
      ),
      _MeasurementEntry(
        label: 'Knee',
        fieldKey: 'knee',
        initialInches: widget.measurement.knee,
      ),
      _MeasurementEntry(
        label: 'Ankle',
        fieldKey: 'ankle',
        initialInches: widget.measurement.ankle,
      ),
      _MeasurementEntry(
        label: 'Waist to Ankle',
        fieldKey: 'waistToAnkle',
        initialInches: widget.measurement.waistToAnkle,
      ),
      _MeasurementEntry(
        label: 'Shoulder to Ankle',
        fieldKey: 'shoulderToAnkle',
        initialInches: widget.measurement.shoulderToAnkle,
      ),
    ];
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    // Validate every field before saving.
    bool allValid = true;
    for (final entry in _entries) {
      if (!entry.validate()) {
        allValid = false;
      }
    }
    setState(() {}); // refresh error text on all fields

    if (!allValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the highlighted fields before saving.'),
          backgroundColor: _MeasurementColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final updated = widget.measurement.copyWith(
      upperBustCircumference: _valueFor('Upper Bust Circumference'),
      roundShoulderCircumference: _valueFor('Round Shoulder Circumference'),
      bustCircumference: _valueFor('Bust Circumference'),
      underBustCircumference: _valueFor('Under Bust Circumference'),
      hipsCircumference: _valueFor('Hips Circumference'),
      shoulderToBust: _valueFor('Shoulder to Bust'),
      shoulderToUnderBust: _valueFor('Shoulder to Under Bust'),
      waist: _valueFor('Waist'),
      shoulderToKnee: _valueFor('Shoulder to Knee'),
      thigh: _valueFor('Thigh'),
      knee: _valueFor('Knee'),
      ankle: _valueFor('Ankle'),
      waistToAnkle: _valueFor('Waist to Ankle'),
      shoulderToAnkle: _valueFor('Shoulder to Ankle'),
    );

    try {
      await widget.onSave(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Measurements saved successfully.'),
            backgroundColor: _MeasurementColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save measurements: $e'),
            backgroundColor: _MeasurementColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showGuideSheet(_MeasurementEntry entry) {
    final guide = kMeasurementGuides[entry.fieldKey];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _MeasurementColors.cardWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _MeasurementColors.labelText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (guide != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 1.1,
                      child: Container(
                        color: _MeasurementColors.background,
                        child: Image.asset(
                          guide.assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('ERROR LOADING IMAGE: $error');
                            return const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: _MeasurementColors.subtleText,
                                size: 28,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    guide.text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: _MeasurementColors.labelText,
                    ),
                  ),
                ] else
                  const Text(
                    'Guide content for this measurement is coming soon.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _MeasurementColors.subtleText,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _valueFor(String label) {
    final entry = _entries.firstWhere((e) => e.label == label);
    return entry.currentInches;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _MeasurementColors.background,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keep your measurements up to date for the most accurate fit.',
                style: TextStyle(
                  fontSize: 13,
                  color: _MeasurementColors.subtleText,
                ),
              ),
              const SizedBox(height: 16),
              for (final entry in _entries) ...[
                MeasurementField(
                  entry: entry,
                  onGuideTap: () => _showGuideSheet(entry),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _MeasurementColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: _MeasurementColors.labelText, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'My Measurements',
        style: TextStyle(
          color: _MeasurementColors.labelText,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: _MeasurementColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Holds the mutable state for a single measurement row: its controller,
/// currently selected unit, and validation error.
class _MeasurementEntry {
  _MeasurementEntry({
    required this.label,
    required this.fieldKey,
    required double initialInches,
  })  : storedInches = initialInches,
        unit = MeasurementUnit.inch,
        controller = TextEditingController(
          text: _formatNumber(initialInches),
        );

  final String label;

  /// Matches the Measurement model's field name and the guide asset key
  /// (e.g. assets/images/guides/<fieldKey>.png).
  final String fieldKey;

  /// The last known-good value, always kept in inches.
  double storedInches;

  MeasurementUnit unit;
  final TextEditingController controller;
  String? errorText;

  /// Returns the current field value converted to inches, or the last
  /// valid stored value if the current text is invalid.
  double get currentInches {
    final parsed = double.tryParse(controller.text.trim());
    if (parsed == null) return storedInches;
    return unit.toInches(parsed);
  }

  /// Validates the current text field content.
  /// Rule: positive numbers only, equivalent to 1-300 cm.
  bool validate() {
    final text = controller.text.trim();
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      errorText = 'Please enter a valid number';
      return false;
    }

    final inches = unit.toInches(parsed);
    final cmEquivalent = inches * 2.54;
    if (cmEquivalent < 1 || cmEquivalent > 300) {
      errorText = 'Please enter a valid number';
      return false;
    }

    errorText = null;
    storedInches = inches;
    return true;
  }

  static String _formatNumber(double value) {
    // Trim trailing zeros for a cleaner default display.
    String s = value.toStringAsFixed(2);
    if (s.endsWith('.00')) {
      s = s.substring(0, s.length - 3);
    } else if (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  void dispose() {
    controller.dispose();
  }
}

/// A reusable row widget for a single measurement: label, numeric input,
/// unit dropdown, live inch conversion preview, and a Guide button.
class MeasurementField extends StatefulWidget {
  const MeasurementField({
    super.key,
    required this.entry,
    required this.onGuideTap,
  });

  final _MeasurementEntry entry;
  final VoidCallback onGuideTap;

  @override
  State<MeasurementField> createState() => _MeasurementFieldState();
}

class _MeasurementFieldState extends State<MeasurementField> {
  late double _convertedInches;

  @override
  void initState() {
    super.initState();
    _convertedInches = widget.entry.storedInches;
    widget.entry.controller.addListener(_recalculate);
  }

  @override
  void dispose() {
    widget.entry.controller.removeListener(_recalculate);
    super.dispose();
  }

  void _recalculate() {
    final entry = widget.entry;
    final parsed = double.tryParse(entry.controller.text.trim());
    setState(() {
      if (parsed == null) {
        entry.errorText = entry.controller.text.trim().isEmpty
            ? null
            : 'Please enter a valid number';
        return;
      }
      entry.errorText = null;
      _convertedInches = entry.unit.toInches(parsed);
    });
  }

  void _onUnitChanged(MeasurementUnit? newUnit) {
    if (newUnit == null) return;
    final entry = widget.entry;

    // Preserve the physical measurement: convert the current displayed
    // value into the newly selected unit.
    final parsed = double.tryParse(entry.controller.text.trim());
    final currentInches =
        parsed != null ? entry.unit.toInches(parsed) : entry.storedInches;

    setState(() {
      entry.unit = newUnit;
      final newDisplayValue = newUnit.fromInches(currentInches);
      entry.controller.text = _MeasurementEntry._formatNumber(
        double.parse(newDisplayValue.toStringAsFixed(2)),
      );
      entry.errorText = null;
      _convertedInches = currentInches;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _MeasurementColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _MeasurementColors.labelText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: entry.controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: _MeasurementColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _MeasurementColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _MeasurementColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: _MeasurementColors.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _MeasurementColors.errorRed),
                    ),
                    errorText: entry.errorText,
                    errorStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 42,
                  decoration: BoxDecoration(
                    color: _MeasurementColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: _MeasurementColors.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MeasurementUnit>(
                      value: entry.unit,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      style: const TextStyle(
                        fontSize: 14,
                        color: _MeasurementColors.labelText,
                      ),
                      items: MeasurementUnit.values
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Text(u.label),
                            ),
                          )
                          .toList(),
                      onChanged: _onUnitChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      color: _MeasurementColors.subtleText,
                    ),
                    children: [
                      const TextSpan(text: 'Automatically stored: '),
                      TextSpan(
                        text: '≈ ${_convertedInches.toStringAsFixed(2)} in',
                        style: const TextStyle(
                          color: _MeasurementColors.darkGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onGuideTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Guide',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _MeasurementColors.primaryGreen,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: _MeasurementColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}