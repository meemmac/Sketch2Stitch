import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
// Local-only progress memory (no DB writes) so the screen can resume at the
// right step if the customer navigates away before a tailor job exists.
// Add `shared_preferences` to pubspec.yaml if it isn't already a dependency.
import 'package:shared_preferences/shared_preferences.dart';

// TODO: point this at your real Measurement model
// (the same one used by MeasurementScreen / DashboardDrawer).
import '../../models/measurement.dart';
import 'measurement_screen.dart';
import 'browsing/browse_shell.dart';

/// ─── Backend Sync Contract ──────────────────────────────────────────────
///
/// This screen doesn't talk to Firestore directly — it reports the exact
/// state changes described in the workflow via `TailoringSetupCallbacks`,
/// so whoever owns the Orders/Sub-orders/Tailor-jobs writes can plug them
/// in without this screen needing to know about your backend client.
class TailoringSetupCallbacks {
  /// Orders.status = 'processing'; every Sub-orders.deliveryDestination = 'customer'.
  final Future<void> Function() onSkipTailoring;

  /// Orders.status = 'awaiting_tailor_search';
  /// tailorSelectionDeadline = orderDate + 72h.
  final Future<void> Function(DateTime tailorSelectionDeadline)
  onContinueToTailor;

  /// Creates a Tailor-jobs doc (status='pending', quoteStatus='not_sent',
  /// requestedAt=now, quoteResponseDeadline=now+72h) with
  /// measurementId/designIds, then sets Orders.status = 'tailor_pending'
  /// and every Sub-orders.deliveryDestination = 'tailor'. Returns the new
  /// job id. Called once per tailor request (may be called again if a
  /// previous job was rejected and the customer picks another tailor).
  final Future<String> Function({
    required String measurementId,
    required List<String> designIds,
    required String tailorId,
  })
  onCreateTailorJob;

  /// Payments.targetType = 'tailor' payment flow for a confirmed job.
  final Future<void> Function(String tailorJobId) onPayTailor;

  /// 72h deadline passed with no confirmed tailor: every
  /// Sub-orders.deliveryDestination = 'customer'.
  final Future<void> Function() onTailorSearchExpired;

  /// Reads back the current state for this order so the screen can resume
  /// correctly if the customer left and came back (app restart, backed out
  /// of the flow, etc). Should look up:
  ///   - Orders.tailorSelectionDeadline (for the deadline banner)
  ///   - the most recent Tailor-jobs doc where orderId == this order
  /// and map it onto `TailorJobSnapshot`. Return null if there's no
  /// tailor job yet (e.g. customer hasn't reached step 4, or skipped
  /// tailoring entirely). This performs no writes — read-only.
  final Future<OrderResumeState?> Function() onFetchResumeState;

  const TailoringSetupCallbacks({
    required this.onSkipTailoring,
    required this.onContinueToTailor,
    required this.onCreateTailorJob,
    required this.onPayTailor,
    required this.onTailorSearchExpired,
    required this.onFetchResumeState,
  });
}

/// A design reference — either picked from the gallery or exported from the
/// sketch canvas. Both are just images once saved, so nothing downstream
/// needs to know which source it came from.
class DesignItem {
  final String path;

  const DesignItem({required this.path});
}

/// Mirrors Tailor-jobs.status for the *current* job being tracked on this
/// screen. The schema's Tailor-jobs.status enum has more granularity
/// ("quoted", "in_progress", "completed", "cancelled", ...) than this
/// screen currently renders distinct UI for — see `_mapSchemaStatus` for
/// how each value collapses onto one of these four screen states.
enum _JobStatus { pending, confirmed, rejected, expired }

/// What `onFetchResumeState` hands back to rehydrate this screen. Field
/// names deliberately mirror the Tailor-jobs / Orders schema so mapping
/// your Firestore doc into this is a straight copy.
class OrderResumeState {
  final DateTime? tailorSelectionDeadline; // Orders.tailorSelectionDeadline
  final String? tailorJobId; // Tailor-jobs doc id
  final String? tailorId; // Tailor-jobs.tailorId
  final String? status; // Tailor-jobs.status (raw schema value)
  final DateTime? requestedAt; // Tailor-jobs.requestedAt
  final double? quoteAmount; // Tailor-jobs.quoteAmount
  final DateTime? estimatedDeliveryDate; // Tailor-jobs.estimatedDeliveryDate
  final String? rejectionReason; // Tailor-jobs.rejectionReason

  const OrderResumeState({
    this.tailorSelectionDeadline,
    this.tailorJobId,
    this.tailorId,
    this.status,
    this.requestedAt,
    this.quoteAmount,
    this.estimatedDeliveryDate,
    this.rejectionReason,
  });
}

class _TailorJobState {
  final String jobId;
  final String tailorId;
  final _JobStatus status;
  final DateTime requestedAt;
  final double? quoteAmount;
  final DateTime? estimatedDeliveryDate;
  final String? rejectionReason;

  const _TailorJobState({
    required this.jobId,
    required this.tailorId,
    required this.status,
    required this.requestedAt,
    this.quoteAmount,
    this.estimatedDeliveryDate,
    this.rejectionReason,
  });

  _TailorJobState copyWith({
    _JobStatus? status,
    double? quoteAmount,
    DateTime? estimatedDeliveryDate,
    String? rejectionReason,
  }) {
    return _TailorJobState(
      jobId: jobId,
      tailorId: tailorId,
      status: status ?? this.status,
      requestedAt: requestedAt,
      quoteAmount: quoteAmount ?? this.quoteAmount,
      estimatedDeliveryDate:
          estimatedDeliveryDate ?? this.estimatedDeliveryDate,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

/// Maps the schema's Tailor-jobs.status enum
/// ("pending" | "rejected" | "quoted" | "confirmed" | "in_progress" |
///  "completed" | "expired" | "cancelled") onto the four states this
/// screen currently has distinct UI for. "quoted" and "pending" both read
/// as "waiting on tailor" here; "confirmed"/"in_progress"/"completed" all
/// read as "confirmed" (payment already happened by the time a job is
/// in_progress/completed, so the payment card is harmless to re-show
/// briefly, but you may want to branch further once you add dedicated
/// in-progress/completed UI). "cancelled" falls back to expired-style
/// messaging since there's no dedicated card for it yet.
_JobStatus _mapSchemaStatus(String raw) {
  switch (raw) {
    case 'pending':
    case 'quoted':
      return _JobStatus.pending;
    case 'confirmed':
    case 'in_progress':
    case 'completed':
      return _JobStatus.confirmed;
    case 'rejected':
      return _JobStatus.rejected;
    case 'expired':
    case 'cancelled':
      return _JobStatus.expired;
    default:
      return _JobStatus.pending;
  }
}

String _formatDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour12:$minute $period';
}

/// ─── Tailoring Setup Screen ─────────────────────────────────────────────

class TailoringSetupScreen extends StatefulWidget {
  final String orderId;
  final DateTime orderDate;
  final List<Measurement> savedMeasurements;
  final TailoringSetupCallbacks callbacks;

  const TailoringSetupScreen({
    super.key,
    required this.orderId,
    required this.orderDate,
    required this.savedMeasurements,
    required this.callbacks,
  });

  @override
  State<TailoringSetupScreen> createState() => _TailoringSetupScreenState();
}

class _TailoringSetupScreenState extends State<TailoringSetupScreen> {
  static const List<String> _stepLabels = [
    "Tailoring",
    "Measurements",
    "Design",
    "Find Tailor",
    "Completed",
  ];

  // (asset path, display label)
  static const List<(String, String)> _templates = [
    ('assets/images/templates/man_diagram.png', 'Man'),
    ('assets/images/templates/woman_diagram.png', 'Woman'),
    ('assets/images/templates/child_diagram.png', 'Child'),
  ];

  final ImagePicker _picker = ImagePicker();

  int _currentStep = 0;
  bool _loading = false;
  bool _resuming = true;
  Measurement? _selectedMeasurement;
  final List<DesignItem> _designs = [];

  DateTime? _tailorSelectionDeadline;
  _TailorJobState? _tailorJob;

  // ── Editable measurement grid (mirrors VirtualTrialScreen's layout) ──
  // Field order/labels match the Measurement schema. Editing here is a
  // local override for this order only — wire onCreateTailorJob (or a
  // dedicated callback) to persist edits if you want them to update the
  // saved profile.
  static const List<(String, String)> _measurementFields = [
    ('bustCircumference', 'Bust'),
    ('waist', 'Waist'),
    ('hipsCircumference', 'Hips'),
    ('upperBustCircumference', 'Upper Bust / Over Bust'),
    ('underBustCircumference', 'Under Bust'),
    ('roundShoulderCircumference', 'Round Shoulder'),
    ('shoulderToBust', 'Shoulder to Bust'),
    ('shoulderToUnderBust', 'Shoulder to Under Bust'),
    ('shoulderToKnee', 'Shoulder to Knee'),
    ('shoulderToAnkle', 'Shoulder to Ankle'),
    ('waistToAnkle', 'Waist to Ankle'),
    ('thigh', 'Thigh'),
    ('knee', 'Knee'),
    ('ankle', 'Ankle'),
  ];

  late Map<String, TextEditingController> _measurementControllers;

  double? _measurementValue(Measurement m, String field) {
    switch (field) {
      case 'bustCircumference':
        return m.bustCircumference;
      case 'waist':
        return m.waist;
      case 'hipsCircumference':
        return m.hipsCircumference;
      case 'upperBustCircumference':
        return m.upperBustCircumference;
      case 'underBustCircumference':
        return m.underBustCircumference;
      case 'roundShoulderCircumference':
        return m.roundShoulderCircumference;
      case 'shoulderToBust':
        return m.shoulderToBust;
      case 'shoulderToUnderBust':
        return m.shoulderToUnderBust;
      case 'shoulderToKnee':
        return m.shoulderToKnee;
      case 'shoulderToAnkle':
        return m.shoulderToAnkle;
      case 'waistToAnkle':
        return m.waistToAnkle;
      case 'thigh':
        return m.thigh;
      case 'knee':
        return m.knee;
      case 'ankle':
        return m.ankle;
      default:
        return null;
    }
  }

  void _initMeasurementControllers() {
    final m = _selectedMeasurement;
    _measurementControllers = {
      for (final (field, _) in _measurementFields)
        field: TextEditingController(
          text: m == null
              ? ''
              : () {
                  final v = _measurementValue(m, field);
                  return v == null ? '' : v.toStringAsFixed(1);
                }(),
        ),
    };
  }

  // ── Local-only progress memory ──────────────────────────────────────
  // Keys are scoped to this order so multiple in-flight orders don't
  // collide. This is purely device-local (SharedPreferences) — no DB
  // writes — so it only helps the *same device* resume; it's a stopgap
  // until step/measurement/design state is written to Orders/Tailor-jobs
  // for real.
  String get _stepPrefKey => 'tailoring_step_${widget.orderId}';
  String get _designsPrefKey => 'tailoring_designs_${widget.orderId}';

  Future<void> _saveLocalProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepPrefKey, _currentStep);
      await prefs.setStringList(
        _designsPrefKey,
        _designs.map((d) => d.path).toList(),
      );
    } catch (_) {
      // Best-effort only — losing local resume state shouldn't block flow.
    }
  }

  Future<void> _clearLocalProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stepPrefKey);
      await prefs.remove(_designsPrefKey);
    } catch (_) {
      // Nothing to clean up, or storage unavailable — either way, fine.
    }
  }

  Future<void> _loadLocalProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final step = prefs.getInt(_stepPrefKey);
      final designPaths = prefs.getStringList(_designsPrefKey);
      if (step != null) _currentStep = step;
      if (designPaths != null) {
        _designs.addAll(designPaths.map((p) => DesignItem(path: p)));
      }
    } catch (_) {
      // No local progress saved yet — fine, start fresh.
    }
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Only one measurement profile per customer — pre-select it.
    if (widget.savedMeasurements.isNotEmpty) {
      _selectedMeasurement = widget.savedMeasurements.first;
    }
    _initMeasurementControllers();
    _resumeFromBackend();
  }

  @override
  void dispose() {
    for (final c in _measurementControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Read-only rehydration: if the customer already progressed past step 1
  /// on a previous visit (e.g. they requested a tailor, then closed the
  /// app before hearing back), pick this screen back up at the right step
  /// and state instead of starting over. Makes no writes — if there's
  /// nothing to resume, this is a no-op and the screen behaves exactly as
  /// before (starts at step 0).
  Future<void> _resumeFromBackend() async {
    // Local-only step memory first — this is what lets someone who never
    // requested a tailor (so there's no Tailor-jobs doc yet) come back to
    // wherever they left off, e.g. mid-way through Measurements or Design.
    await _loadLocalProgress();

    try {
      final resume = await widget.callbacks.onFetchResumeState();
      if (!mounted) return;

      if (resume == null) return;

      setState(() {
        if (resume.tailorSelectionDeadline != null) {
          _tailorSelectionDeadline = resume.tailorSelectionDeadline;
        }

        if (resume.tailorJobId != null && resume.status != null) {
          _tailorJob = _TailorJobState(
            jobId: resume.tailorJobId!,
            tailorId: resume.tailorId ?? '',
            status: _mapSchemaStatus(resume.status!),
            requestedAt: resume.requestedAt ?? DateTime.now(),
            quoteAmount: resume.quoteAmount,
            estimatedDeliveryDate: resume.estimatedDeliveryDate,
            rejectionReason: resume.rejectionReason,
          );
          // A tailor job only ever exists once the customer reached step 4
          // — this overrides local step memory since a real backend job
          // is more authoritative than "last step tapped on this device."
          _currentStep = 3;
        }
        // If there's no tailor job yet, we deliberately leave _currentStep
        // as whatever _loadLocalProgress restored (or 0, if nothing was
        // saved) rather than forcing step 3.
      });
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  // ─── Step 1 actions ────────────────────────────────────────────────

  Future<void> _skipTailoring() async {
    await _withLoading(() async {
      await widget.callbacks.onSkipTailoring();
    });
    if (!mounted) return;
    _showOrderCompleteDialog("Your order was sent for direct delivery.");
  }

  Future<void> _continueToTailor() async {
    final deadline = widget.orderDate.add(const Duration(hours: 72));
    await _withLoading(() async {
      await widget.callbacks.onContinueToTailor(deadline);
    });
    if (!mounted) return;
    setState(() {
      _tailorSelectionDeadline = deadline;
      _currentStep = 1;
    });
    _saveLocalProgress();
  }

  // ─── Step 2 actions ────────────────────────────────────────────────

  void _goToMeasurementScreen() {
    // Reuses your existing Measurement screen for creating/editing profiles;
    // returns here once the customer has one to pick from.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementScreen(
          measurement: widget.savedMeasurements.isNotEmpty
              ? widget.savedMeasurements.first
              : Measurement(id: '', customerId: ''),
          onSave: (_) async {},
        ),
      ),
    );
  }

  // ─── Step 3 actions ────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _designs.add(DesignItem(path: image.path));
    });
    _saveLocalProgress();
  }

  Future<void> _openTemplateForDrawing(String templatePath) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _DesignCanvasScreen(templateAsset: templatePath),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _designs.add(DesignItem(path: result));
    });
    _saveLocalProgress();
  }

  void _removeDesign(DesignItem item) {
    setState(() => _designs.remove(item));
    _saveLocalProgress();
  }

  // ─── Step 4 actions ────────────────────────────────────────────────

  Future<void> _findTailor() async {
  final selectedTailorId = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => BrowseShell(
        initialIndex: 2,
        onTailorSelected: (tailorId) => Navigator.pop(context, tailorId),
      ),
    ),
  );
  if (!mounted || selectedTailorId == null) return;
  await _requestTailorJob(tailorId: selectedTailorId);
}

Future<void> _requestTailorJob({required String tailorId}) async {
  String? jobId;
  await _withLoading(() async {
    jobId = await widget.callbacks.onCreateTailorJob(
      measurementId: _selectedMeasurement?.id ?? '',
      designIds: _designs.map((d) => d.path).toList(),
      tailorId: tailorId,
    );
  });
  if (!mounted || jobId == null) return;
  setState(() {
    _tailorJob = _TailorJobState(
      jobId: jobId!,
      tailorId: tailorId,
      status: _JobStatus.pending,
      requestedAt: DateTime.now(),
    );
  });
}

  void _onTailorConfirmed() {
    if (_tailorJob == null) return;
    setState(() {
      _tailorJob = _tailorJob!.copyWith(
        status: _JobStatus.confirmed,
        quoteAmount: 4500, // TODO: real Tailor-jobs.quoteAmount
        estimatedDeliveryDate:
            DateTime.now().add(const Duration(days: 10)), // TODO: real value
      );
    });
  }

  void _onTailorRejected() {
    if (_tailorJob == null) return;
    setState(() {
      _tailorJob = _tailorJob!.copyWith(
        status: _JobStatus.rejected,
        rejectionReason:
            'The tailor is fully booked this week.', // TODO: real Tailor-jobs.rejectionReason
      );
    });
  }

  Future<void> _simulateDeadlineExpired() async {
    await _withLoading(() => widget.callbacks.onTailorSearchExpired());
    if (!mounted) return;
    setState(() {
      _tailorJob = (_tailorJob ??
              _TailorJobState(
                jobId: '',
                tailorId: '',
                status: _JobStatus.expired,
                requestedAt: DateTime.now(),
              ))
          .copyWith(status: _JobStatus.expired);
    });
  }

  void _promptTailorPayment(String tailorJobId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Pay Tailor"),
        content: const Text(
          "Your tailor confirmed the job. Complete payment to continue.",
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _withLoading(
                () => widget.callbacks.onPayTailor(tailorJobId),
              );
              if (!mounted) return;
              _showOrderCompleteDialog(
                "Payment complete. Your tailor is on it.",
              );
            },
            child: const Text("Pay Now"),
          ),
        ],
      ),
    );
  }

  void _promptCancelConfirmedJob(_TailorJobState job) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text("Cancel this tailor?"),
      content: const Text(
        "The tailor confirmed this job, but you haven't paid yet. "
        "Cancelling will let you browse and request a different tailor.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Keep This Tailor"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            // TODO: wire a real callback (e.g. onCancelTailorJob(job.jobId))
            // to set Tailor-jobs.status = 'cancelled' on the backend.
            setState(() => _tailorJob = null);
          },
          child: const Text("Cancel Job"),
        ),
      ],
    ),
  );
}

  /// Shown once the order has actually reached a terminal, "you're done
  /// here" state (skipped tailoring, or paid a confirmed tailor). Surfaces
  /// the order id and lets the customer jump straight to tracking instead
  /// of just flashing a snackbar and popping immediately.
  void _showOrderCompleteDialog(String message) {
    _clearLocalProgress();
    setState(() => _currentStep = 4);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Order Confirmed"),
        content: Text(
          "$message\n\nOrder ID: ${widget.orderId}",
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog only
              Navigator.of(context).pop(); // leave setup screen
            },
            child: const Text("Stay Here"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.of(context).pop(); // leave setup screen
              // TODO: route to your real track-order screen, e.g.
              // Navigator.pushReplacement(context, MaterialPageRoute(
              //   builder: (_) => TrackOrderScreen(orderId: widget.orderId),
              // ));
            },
            child: const Text("Track Order"),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text(
          "Tailoring Setup",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          if (_resuming)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          else
            Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_currentStep),
                      child: _buildStepBody(),
                    ),
                  ),
                ),
              ],
            ),
          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
  const double circleSize = 26;
  const double connectorWidth = 36;

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_stepLabels.length, (index) {
          final bool isActive = index == _currentStep;
          final bool isLastStep = index == _stepLabels.length - 1;
          final bool isDone =
              index < _currentStep || (isLastStep && index <= _currentStep);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: isActive || isDone
                      ? Colors.green.shade800
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? (index == _stepLabels.length - 1
                        ? TweenAnimationBuilder<double>(
                            key: const ValueKey('completed_check'),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) =>
                                Transform.scale(scale: value, child: child),
                            child: const Icon(Icons.check,
                                size: 14, color: Colors.white),
                          )
                        : const Icon(Icons.check,
                            size: 14, color: Colors.white))
                    : Text(
                        "${index + 1}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : Colors.black45,
                        ),
                      ),
              ),
              if (!isLastStep)
                Container(
                  width: connectorWidth,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: isDone ? Colors.green.shade800 : Colors.grey.shade200,
                ),
            ],
          );
        }),
      ),
    ),
  );
}

  Widget _buildStepBody() {
    switch (_currentStep) {
      case 0:
        return _buildTailoringStep();
      case 1:
        return _buildMeasurementsStep();
      case 2:
        return _buildDesignStep();
      case 3:
        return _buildFindTailorStep();
      default:
        return _buildCompletedStep();
    }
  }

  Widget _buildCompletedStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  color: Colors.green.shade800, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Order Complete",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // ─── Step 1 ────────────────────────────────────────────────────────

  Widget _buildTailoringStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.content_cut_rounded,
                color: Colors.green.shade800,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Would you like to send this order to a tailor?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "We'll help you pick measurements, design references, and "
              "match with a tailor. Or skip this and have items delivered "
              "straight to you.",
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continueToTailor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _skipTailoring,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Skip Tailoring",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 2 ────────────────────────────────────────────────────────

  Widget _buildMeasurementsStep() {
    if (widget.savedMeasurements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your measurement profile",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Your tailor will use this to fit your garment.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            _buildEmptyMeasurementsCard(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your measurement profile",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tap any field to adjust it for this order.",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.straighten_rounded,
                    size: 14, color: Colors.green.shade800),
                const SizedBox(width: 6),
                Text(
                  "All measurements are in inches",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // Same 2-column editable-field grid as VirtualTrialScreen's
            // Advanced Measurements section.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _measurementFields.map((entry) {
                    final (field, label) = entry;
                    return SizedBox(
                      width: cellWidth,
                      height: 72,
                      child: TextField(
                        controller: _measurementControllers[field],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: label,
                          labelStyle: const TextStyle(fontSize: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.green.shade800),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _goToMeasurementScreen,
            icon: Icon(Icons.edit_outlined, color: Colors.green.shade800),
            label: Text(
              "Edit saved profile",
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _currentStep = 2);
                _saveLocalProgress();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Continue",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMeasurementsCard() {
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.straighten_rounded, size: 40, color: Colors.green.shade200),
          const SizedBox(height: 12),
          const Text(
            "No saved measurement profile yet.",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _goToMeasurementScreen,
            child: const Text("Add measurement profile"),
          ),
        ],
      ),
    );
  }

  // ─── Step 3 ────────────────────────────────────────────────────────

  Widget _buildDesignStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Add design references",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Optional — upload inspiration photos or sketch on a body "
            "diagram. You can skip this and continue without any.",
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text("Upload from Gallery"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade800,
                side: BorderSide(color: Colors.green.shade200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Or sketch on a body diagram",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final (path, label) = _templates[index];
                return GestureDetector(
                  onTap: () => _openTemplateForDrawing(path),
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          path,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.checkroom_rounded,
                            color: Colors.green.shade200,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          if (_designs.isNotEmpty) ...[
            const Text(
              "Added References",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: _designs.isEmpty
                ? Center(
                    child: Text(
                      "No references added — that's okay, you can skip this.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: _designs.length,
                    itemBuilder: (context, index) =>
                        _buildDesignThumb(_designs[index]),
                  ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _currentStep = 3);
                _saveLocalProgress();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                _designs.isEmpty ? "Skip and Continue" : "Continue",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignThumb(DesignItem item) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(item.path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeDesign(item),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 4 ────────────────────────────────────────────────────────

  Widget _buildFindTailorStep() {
    final job = _tailorJob;
    final showDeadlineBanner = job == null ||
        job.status == _JobStatus.pending ||
        job.status == _JobStatus.rejected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDeadlineBanner) _buildDeadlineBanner(),
          if (showDeadlineBanner) const SizedBox(height: 14),
          if (job == null)
            _buildNoTailorCard()
          else
            switch (job.status) {
              _JobStatus.pending => _buildPendingCard(job),
              _JobStatus.confirmed => _buildConfirmedCard(job),
              _JobStatus.rejected => _buildRejectedCard(job),
              _JobStatus.expired => _buildExpiredCard(),
            },
        ],
      ),
    );
  }

  Widget _buildDeadlineBanner() {
    final deadline = _tailorSelectionDeadline;
    if (deadline == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.access_time_rounded,
              color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Select a tailor by ${_formatDateTime(deadline)}. If no "
              "tailor is confirmed by then, this order will be delivered "
              "directly to you instead.",
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.amber.shade900,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    List<Widget> children = const [],
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, height: 1.5),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildNoTailorCard() {
    return _statusCard(
      icon: Icons.search_rounded,
      iconBg: Colors.green.shade50,
      iconColor: Colors.green.shade800,
      title: "You haven't selected a tailor yet",
      subtitle:
          "Browse tailors and send a job request. We'll show their quote "
          "and estimated delivery date once they confirm.",
      children: [
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _findTailor,
            icon: const Icon(Icons.storefront_rounded),
            label: const Text(
              "Browse Tailors",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCard(_TailorJobState job) {
    return _statusCard(
      icon: Icons.hourglass_top_rounded,
      iconBg: Colors.blue.shade50,
      iconColor: Colors.blue.shade700,
      title: "Waiting for tailor response",
      subtitle:
          "Requested ${_formatDateTime(job.requestedAt)}. We'll update this "
          "page as soon as the tailor responds — including if you come back "
          "later.",
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Container(height: 1, color: Colors.grey.shade200),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "DEMO CONTROLS",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            Expanded(
              child: Container(height: 1, color: Colors.grey.shade200),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _onTailorConfirmed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade800,
                  side: BorderSide(color: Colors.green.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Confirm",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _onTailorRejected,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Reject",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _simulateDeadlineExpired,
            style: TextButton.styleFrom(foregroundColor: Colors.black45),
            child: const Text("Simulate 72h deadline expired"),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmedCard(_TailorJobState job) {
  return _statusCard(
    icon: Icons.check_circle_rounded,
    iconBg: Colors.green.shade50,
    iconColor: Colors.green.shade800,
    title: "Tailor confirmed!",
    subtitle: "Complete payment to lock in your job.",
    children: [
      const SizedBox(height: 18),
      _infoRow(
        icon: Icons.payments_outlined,
        label: "Total Cost",
        value: job.quoteAmount != null
            ? "Tk ${job.quoteAmount!.toStringAsFixed(0)}"
            : "—",
      ),
      const SizedBox(height: 10),
      _infoRow(
        icon: Icons.local_shipping_outlined,
        label: "Estimated delivery",
        value: job.estimatedDeliveryDate != null
            ? _formatDateTime(job.estimatedDeliveryDate!)
            : "—",
      ),
      const SizedBox(height: 22),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _promptTailorPayment(job.jobId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            "Pay Now",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _promptCancelConfirmedJob(job),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            "Cancel",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildRejectedCard(_TailorJobState job) {
    return _statusCard(
      icon: Icons.cancel_outlined,
      iconBg: Colors.red.shade50,
      iconColor: Colors.red.shade700,
      title: "Tailor declined this job",
      subtitle: job.rejectionReason ?? "No reason was given.",
      children: [
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _findTailor,
            icon: const Icon(Icons.storefront_rounded),
            label: const Text(
              "Browse More Tailors",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiredCard() {
    return _statusCard(
      icon: Icons.timer_off_outlined,
      iconBg: Colors.grey.shade200,
      iconColor: Colors.black54,
      title: "Tailor selection window closed",
      subtitle:
          "No tailor was confirmed within 72 hours, so this order will be "
          "delivered directly to you instead.",
      children: [
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              _showOrderCompleteDialog(
                "Your order was sent for direct delivery.",
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              "Got it",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.green.shade800),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade900,
            ),
          ),
          const SizedBox(width: 10),
          // Value gets the rest of the row and wraps to a second line
          // instead of being cut off — this is what was clipping the
          // estimated delivery date before.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.green.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Design Canvas (Step 3 drawing tool) ────────────────────────────────

enum _DrawTool { pencil, eraser }

class _DrawStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  _DrawStroke({required this.points, required this.color, required this.width});
}

class _DesignCanvasScreen extends StatefulWidget {
  final String templateAsset;

  const _DesignCanvasScreen({required this.templateAsset});

  @override
  State<_DesignCanvasScreen> createState() => _DesignCanvasScreenState();
}

class _DesignCanvasScreenState extends State<_DesignCanvasScreen> {
  static const List<Color> _palette = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  final GlobalKey _boundaryKey = GlobalKey();
  final List<_DrawStroke> _strokes = [];

  _DrawTool _tool = _DrawTool.pencil;
  Color _color = Colors.black;
  double _brushSize = 4;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _strokes.add(
        _DrawStroke(
          points: [details.localPosition],
          color: _tool == _DrawTool.eraser ? Colors.white : _color,
          width: _tool == _DrawTool.eraser ? _brushSize * 3 : _brushSize,
        ),
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _strokes.last.points.add(details.localPosition);
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  Future<String?> _exportImage() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;

      final Uint8List bytes = byteData.buffer.asUint8List();
      final file = File(
        '${Directory.systemTemp.path}/design_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _upload() async {
    final path = await _exportImage();
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save the sketch. Try again.")),
      );
      return;
    }
    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text(
          "Sketch Design",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _undo,
            icon: const Icon(Icons.undo_rounded),
            tooltip: "Undo",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        widget.templateAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade50,
                          child: Icon(
                            Icons.checkroom_rounded,
                            size: 60,
                            color: Colors.green.shade100,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        child: CustomPaint(
                          painter: _SketchPainter(_strokes),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: tools + brush size
            Row(
              children: [
                _toolButton(Icons.edit, _DrawTool.pencil, "Pencil"),
                const SizedBox(width: 8),
                _toolButton(Icons.auto_fix_normal, _DrawTool.eraser, "Eraser"),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _brushSize,
                    min: 1,
                    max: 20,
                    activeColor: Colors.green.shade800,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: (v) => setState(() => _brushSize = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: color palette (own scrollable row so it can never
            // collide with the action buttons on narrow screens)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _palette.map((c) {
                  final bool isSelected =
                      _color == c && _tool == _DrawTool.pencil;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _color = c;
                      _tool = _DrawTool.pencil;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.green.shade800
                              : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Row 3: action buttons, full width so they never get squeezed
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Upload"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, _DrawTool tool, String label) {
    final bool isSelected = _tool == tool;
    return GestureDetector(
      onTap: () => setState(() => _tool = tool),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  final List<_DrawStroke> strokes;

  _SketchPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final isEraser = stroke.color == Colors.white;

      if (isEraser) {
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        for (int i = 0; i < stroke.points.length - 1; i++) {
          canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
        }
        continue;
      }

      // Graphite/pencil texture: a handful of semi-transparent, slightly
      // jittered passes layered with multiply blending, so the stroke
      // reads as grainy pencil shading rather than a flat marker line.
      // The seed is derived from the stroke itself so a given stroke's
      // texture stays stable across repaints instead of flickering.
      final seed = stroke.points.length * 7 + stroke.color.toARGB32();
      final rand = Random(seed);

      for (int layer = 0; layer < 3; layer++) {
        final paint = Paint()
          ..color = stroke.color.withValues(alpha: 0.32)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.width * (0.65 + rand.nextDouble() * 0.5)
          ..blendMode = BlendMode.multiply;

        final jitterRange = stroke.width * 0.18;
        for (int i = 0; i < stroke.points.length - 1; i++) {
          final jitter = Offset(
            (rand.nextDouble() - 0.5) * jitterRange,
            (rand.nextDouble() - 0.5) * jitterRange,
          );
          canvas.drawLine(
            stroke.points[i] + jitter,
            stroke.points[i + 1] + jitter,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}