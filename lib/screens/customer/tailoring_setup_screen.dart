import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

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
    _resumeFromBackend();
  }

  /// Read-only rehydration: if the customer already progressed past step 1
  /// on a previous visit (e.g. they requested a tailor, then closed the
  /// app before hearing back), pick this screen back up at the right step
  /// and state instead of starting over. Makes no writes — if there's
  /// nothing to resume, this is a no-op and the screen behaves exactly as
  /// before (starts at step 0).
  Future<void> _resumeFromBackend() async {
    try {
      final resume = await widget.callbacks.onFetchResumeState();
      if (!mounted || resume == null) return;

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
          // A tailor job only ever exists once the customer reached step 4.
          _currentStep = 3;
        } else if (_tailorSelectionDeadline != null) {
          // They opted into tailoring but haven't requested a job yet —
          // resume wherever they'd naturally continue (step 4, since
          // measurements/design are quick to redo/skip if needed).
          _currentStep = 3;
        }
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
  }

  void _removeDesign(DesignItem item) {
    setState(() => _designs.remove(item));
  }

  // ─── Step 4 actions ────────────────────────────────────────────────

  Future<void> _findTailor() async {
    // TODO: replace this with your real tailor-selection flow (e.g. a
    // version of BrowseShell's Tailors tab that returns a chosen Tailor
    // instead of just opening TailorDetailScreen).
    //
    // BrowseShell tab order: 0=Fabrics, 1=Elements, 2=Tailors, 3=Retailers.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BrowseShell(initialIndex: 2)),
    );
    if (!mounted) return;
    await _requestTailorJob();
  }

  Future<void> _requestTailorJob() async {
    String? jobId;
    await _withLoading(() async {
      jobId = await widget.callbacks.onCreateTailorJob(
        measurementId: _selectedMeasurement?.id ?? '',
        designIds: _designs.map((d) => d.path).toList(),
        tailorId: 'demo_tailor_id', // TODO: real selected tailor id
      );
    });
    if (!mounted || jobId == null) return;
    setState(() {
      _tailorJob = _TailorJobState(
        jobId: jobId!,
        tailorId: 'demo_tailor_id',
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

  /// Shown once the order has actually reached a terminal, "you're done
  /// here" state (skipped tailoring, or paid a confirmed tailor). Surfaces
  /// the order id and lets the customer jump straight to tracking instead
  /// of just flashing a snackbar and popping immediately.
  void _showOrderCompleteDialog(String message) {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: List.generate(_stepLabels.length, (index) {
          final bool isActive = index == _currentStep;
          final bool isDone = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isActive || isDone
                        ? Colors.green.shade800
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : Colors.black45,
                          ),
                        ),
                ),
                if (index != _stepLabels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: isDone
                          ? Colors.green.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          );
        }),
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
      default:
        return _buildFindTailorStep();
    }
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
          Expanded(
            child: widget.savedMeasurements.isEmpty
                ? _buildEmptyMeasurementsCard()
                : ListView.separated(
                    itemCount: widget.savedMeasurements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final m = widget.savedMeasurements[index];
                      final isSelected = _selectedMeasurement?.id == m.id;
                      return _buildMeasurementCard(m, isSelected);
                    },
                  ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _goToMeasurementScreen,
            icon: Icon(Icons.edit_outlined, color: Colors.green.shade800),
            label: Text(
              "Edit measurement profile",
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
              onPressed: _selectedMeasurement == null
                  ? null
                  : () => setState(() => _currentStep = 2),
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

  Widget _buildMeasurementCard(Measurement m, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? Colors.green.shade800 : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.straighten_rounded,
                color: Colors.green.shade800, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Saved profile",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _measurementChip("Bust", m.bustCircumference),
                    _measurementChip("Waist", m.waist),
                    _measurementChip("Hips", m.hipsCircumference),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green.shade800),
        ],
      ),
    );
  }

  Widget _measurementChip(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "$label: ${value.toStringAsFixed(1)}\"",
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(fontSize: 11, color: Colors.green.shade800),
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
              onPressed: () => setState(() => _currentStep = 3),
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
          label: "Quote",
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
        children: [
          Icon(icon, size: 18, color: Colors.green.shade800),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade900,
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.right,
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
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}