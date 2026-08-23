import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/order.dart';
import '../../models/sub_order.dart';
import '../../models/tailor_job.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'messaging/chat_screen.dart'; // adjust path to match your folder structure
// Local-only progress memory (no DB writes) so the screen can resume at the
// right step if the customer navigates away before a tailor job exists.
// Add `shared_preferences` to pubspec.yaml if it isn't already a dependency.
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/bkash_service.dart';
import '../../widgets/top_feedback_banner.dart';
import '../../services/measurement_service.dart';
import '../../services/retailer_service.dart';
import '../../services/tailor_service.dart';
import '../../services/tailoring_service.dart';
import '../../services/user_session.dart';
import 'bkash_payment_screen.dart';

import '../../models/measurement.dart';
import 'measurement_page.dart';
import 'browsing/browse_shell.dart';
import 'track_order.dart';

/// ─── Backend Sync Contract ──────────────────────────────────────────────
///
/// This screen doesn't talk to Firestore directly — it reports the exact
/// state changes described in the workflow via `TailoringSetupCallbacks`,
/// so whoever owns the Orders/Sub-orders/Tailor-jobs writes can plug them
/// in without this screen needing to know about your backend client.
///
/// One tailor job per ORDER (not per sub-order) — matches the Tailor-jobs
/// schema, which has an orderId field but no subOrderId field. The
/// customer picks ONE tailor for the whole order, covering every
/// sub-order/retailer in it.
///
/// "Tailor submits quote" workflow: the TAILOR sets quoteAmount /
/// estimatedDeliveryDate / deliverCharge on the job (via
/// OrderStore.submitTailorQuote() on their own screen — not this one).
/// The CUSTOMER only ever accepts or declines what's already there —
/// onConfirmTailorJob and onRejectTailorJob both take no arguments.
class TailoringSetupCallbacks {
  final Future<void> Function() onSkipTailoring;
  final Future<void> Function(DateTime tailorSelectionDeadline)
  onContinueToTailor;

  final Future<String> Function({
    required String measurementId,
    required List<String> designIds,
    required String tailorId,
    required String instructions,
  })
  onCreateTailorJob;

  /// [transactionId] is the bKash trxID for the tailor's charge. Optional
  /// only because the no-amount legacy path confirms without a payment.
  final Future<void> Function({String? transactionId}) onConfirmTailorJob;

  final Future<void> Function() onRejectTailorJob;

  final Future<void> Function() onPayTailor;

  /// The 72h selection window closed with no confirmed tailor — the order
  /// falls back to direct retailer → customer delivery. Terminal.
  final Future<void> Function() onTailorSearchExpired;

  /// The tailor let their 12h response window lapse without quoting. NOT
  /// terminal: the job dies but the order goes back to
  /// `awaiting_tailor_search` so another tailor can be hired inside
  /// whatever is left of the 72h window.
  final Future<void> Function() onQuoteRequestExpired;

  final Future<OrderResumeState?> Function() onFetchResumeState;

  /// Live version of [onFetchResumeState]. The quote is written on the
  /// tailor's device, so this screen has to hear about it from Firestore
  /// rather than re-asking on a timer.
  final Stream<OrderResumeState?> Function() onWatchResumeState;

  const TailoringSetupCallbacks({
    required this.onSkipTailoring,
    required this.onContinueToTailor,
    required this.onCreateTailorJob,
    required this.onConfirmTailorJob,
    required this.onRejectTailorJob,
    required this.onPayTailor,
    required this.onTailorSearchExpired,
    required this.onQuoteRequestExpired,
    required this.onFetchResumeState,
    required this.onWatchResumeState,
  });
}

/// A design reference — either picked from the gallery or exported from the
/// sketch canvas. Both are just images once saved, so nothing downstream
/// needs to know which source it came from.
class DesignItem {
  final String path;

  const DesignItem({required this.path});
}

/// What `onFetchResumeState` hands back to rehydrate this screen. Field
/// names deliberately mirror the Tailor-jobs / Orders schema so mapping
/// your Firestore doc into this is a straight copy. One instance per
/// ORDER now (not one per sub-order).
///
/// rejectionReason is no longer collected (rejection is a plain "no
/// thanks" from the customer) — the field stays here only so older
/// resume payloads that still send it don't break deserialization; it's
/// never read by this screen anymore.
class OrderResumeState {
  final DateTime? tailorSelectionDeadline;
  final String? tailorJobId;
  final String? tailorId;
  final String? status;
  final DateTime? requestedAt;
  final double? quoteAmount;
  final double? deliverCharge;
  final DateTime? estimatedDeliveryDate;
  final String? rejectionReason;
  final String? tailorPaymentStatus;

  /// `Orders.status`. An 'expired' job means two different things depending
  /// on this: the 72h selection window closed (order 'processing' — direct
  /// delivery, nothing left to do) or the tailor let their 12h response
  /// window lapse (order back to 'awaiting_tailor_search' — pick someone
  /// else). Without it the screen showed "order complete" for both.
  final String? orderStatus;

  /// When the current tailor's 12h window to answer with a quote closes.
  final DateTime? quoteResponseDeadline;

  const OrderResumeState({
    this.tailorSelectionDeadline,
    this.tailorJobId,
    this.tailorId,
    this.status,
    this.requestedAt,
    this.quoteAmount,
    this.deliverCharge,
    this.estimatedDeliveryDate,
    this.rejectionReason,
    this.tailorPaymentStatus,
    this.orderStatus,
    this.quoteResponseDeadline,
  });
}

String _formatDateTime(DateTime dt) {
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
  final List<SubOrder> subOrders;
  final TailoringSetupCallbacks callbacks;

  const TailoringSetupScreen({
    super.key,
    required this.orderId,
    required this.orderDate,
    required this.savedMeasurements,
    required this.subOrders,
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

  /// Local copy of `widget.savedMeasurements`, so a profile saved from
  /// within this flow is reflected here without rebuilding the screen from
  /// its caller (Cart/Checkout or Running Orders).
  late List<Measurement> _savedMeasurements =
      List<Measurement>.of(widget.savedMeasurements);

  final List<DesignItem> _designs = [];

  DateTime? _tailorSelectionDeadline;

  /// When the current tailor's 12h window to answer with a quote closes.
  DateTime? _quoteResponseDeadline;

  /// Latest known `Orders.status`. Needed to tell the two kinds of expiry
  /// apart — see [OrderResumeState.orderStatus].
  String? _orderStatus;

  /// Live job/deadline updates. The tailor's quote is written on THEIR
  /// device, so the only way this screen learns about it is Firestore.
  ///
  /// This used to be a 20-second poll re-running `onFetchResumeState`,
  /// which meant a quote could sit unseen for most of a minute while the
  /// screen spent two reads per tick discovering nothing had changed.
  StreamSubscription<OrderResumeState?>? _resumeSub;

  /// Deadlines still need a clock: nothing is written to Firestore at the
  /// moment a window closes, so no snapshot fires. This ticks only to check
  /// the two deadlines — it does not re-read the job.
  Timer? _deadlineTimer;

  static const Duration _deadlineCheckInterval = Duration(seconds: 30);

  /// Guards against a slow expiry write overlapping the next tick.
  bool _checkingDeadlines = false;

  /// ONE tailor job for the whole order — null until a tailor is
  /// requested. Covers every sub-order listed below.
  TailorJob? _tailorJob;

  /// Has the order reached a resolved state? Drives the auto-complete
  /// dialog. Resolved = job confirmed+paid, or job expired, or every
  /// sub-order is going direct-to-customer anyway.
  bool get _isResolved {
    final job = _tailorJob;
    if (job != null) {
      final resolvedViaTailor =
          job.status == TailorJobStatus.confirmed &&
          job.tailorPaymentStatus == TailorPaymentStatus.paid;
      // An 'expired' job only ends the order when the ORDER went to direct
      // delivery with it. A job expired by the 12h quote window leaves the
      // order in awaiting_tailor_search with the customer free to hire
      // someone else — treating that as "resolved" popped the
      // order-complete dialog over a search that was still very much open.
      final resolvedViaExpiry = job.status == TailorJobStatus.expired &&
          _orderStatus == OrderStatus.processing.toValue;
      if (resolvedViaTailor || resolvedViaExpiry) return true;
    }
    // No job at all, and every sub-order is direct-to-customer anyway.
    if (job == null && widget.subOrders.isNotEmpty) {
      return widget.subOrders.every(
        (so) => so.deliveryDestination == SubOrderDeliveryDestination.customer,
      );
    }
    return false;
  }

  final TextEditingController _instructionsController = TextEditingController();

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

  String get _stepPrefKey => 'tailoring_step_${widget.orderId}';
  String get _designsPrefKey => 'tailoring_designs_${widget.orderId}';
  String get _instructionsPrefKey => 'tailoring_instructions_${widget.orderId}';

  Future<void> _saveLocalProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepPrefKey, _currentStep);
      await prefs.setStringList(
        _designsPrefKey,
        _designs.map((d) => d.path).toList(),
      );
      await prefs.setString(_instructionsPrefKey, _instructionsController.text);
    } catch (_) {}
  }

  Future<void> _clearLocalProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stepPrefKey);
      await prefs.remove(_designsPrefKey);
      await prefs.remove(_instructionsPrefKey);
    } catch (_) {}
  }

  /// Shop names for `widget.subOrders`, keyed by retailerId. Without this
  /// the order summary on the Find Tailor step printed the raw Firestore
  /// document id at the customer ("Retailer: 8kJx2mQp...").
  final Map<String, String> _retailerNames = {};

  Future<void> _loadRetailerNames() async {
    final ids = widget.subOrders.map((s) => s.retailerId).toSet()
      ..removeWhere((id) => id.isEmpty);
    if (ids.isEmpty) return;

    final service = RetailerService();
    for (final id in ids) {
      try {
        final retailer = await service.getRetailerProfile(id);
        final name = retailer?.shopName.trim();
        if (name != null && name.isNotEmpty) _retailerNames[id] = name;
      } catch (e) {
        debugPrint('[TailoringSetup] retailer name lookup failed for $id: $e');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadMeasurementFallback() async {
    final customerId = UserSession.instance.uid;
    if (customerId == null) return;
    try {
      final m = await MeasurementService().getMeasurement(customerId);
      if (!mounted || m == null) return;
      setState(() {
        _savedMeasurements = [m];
        _selectedMeasurement = m;
      });
    } catch (_) {
      // Step 2 still offers to create one, so a failed read is not fatal.
    }
  }

  Future<void> _loadLocalProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final step = prefs.getInt(_stepPrefKey);
      final designPaths = prefs.getStringList(_designsPrefKey);
      final instructions = prefs.getString(_instructionsPrefKey);
      if (step != null) _currentStep = step;
      if (designPaths != null)
        _designs.addAll(designPaths.map((p) => DesignItem(path: p)));
      if (instructions != null) _instructionsController.text = instructions;
    } catch (_) {}
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
    if (_savedMeasurements.isNotEmpty) {
      _selectedMeasurement = _savedMeasurements.first;
    } else {
      // Not every entry point has one to hand over — OrderDetailScreen passes
      // `const []`. Without this the customer reached the tailor step with no
      // measurement selected and the job was created with an empty
      // measurementId, so the tailor opened it and saw nothing to sew to.
      _loadMeasurementFallback();
    }
    _initMeasurementControllers();
    _loadRetailerNames();
    _resumeFromBackend();
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    _resumeSub?.cancel();
    for (final c in _measurementControllers.values) {
      c.dispose();
    }
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _resumeFromBackend() async {
    await _loadLocalProgress();

    try {
      final resume = await widget.callbacks.onFetchResumeState();
      if (!mounted) return;

      setState(() {
        if (resume != null) {
          _applyResume(resume);
          if (_tailorJob != null) {
            _currentStep = 3; // a job exists → jump to Find Tailor step
          }
        }
      });

      // NEW — a resumed job may already be resolved (confirmed = paid,
      // or expired). _isResolved won't have had a chance to trigger the
      // completion dialog yet since this is the first setState after
      // load, so check explicitly and surface it after this frame.
      if (_isResolved) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkResolvedAndMaybeComplete();
        });
      }
    } finally {
      if (mounted) setState(() => _resuming = false);
    }

    _startWatching();

    // Both windows may have closed while the app was shut. Settle them
    // now rather than waiting a full tick for the first timer fire.
    await _checkDeadlines();
  }

  // ─── Waiting-state updates ─────────────────────────────────────────

  /// Subscribes to live job/deadline changes and starts the deadline clock.
  /// Only worth running while the order is still undecided — once it is
  /// resolved (paid, or expired to direct delivery) there is nothing left
  /// to watch for.
  void _startWatching() {
    if (!mounted || _isResolved) return;

    _resumeSub?.cancel();
    _resumeSub = widget.callbacks.onWatchResumeState().listen(
      (resume) {
        if (!mounted || resume == null) return;
        // Only the job and the deadlines are refreshed here — NOT
        // _currentStep. The customer may be part-way through editing
        // designs or measurements, and yanking them to another step
        // mid-update would lose that work.
        setState(() => _applyResume(resume));

        if (_isResolved) {
          _stopWatching();
          _checkResolvedAndMaybeComplete();
        }
      },
      onError: (Object e) {
        // Not worth interrupting the customer over — the deadline timer
        // still runs, and reopening the screen re-reads everything.
        debugPrint('[TailoringSetup] resume stream failed: \$e');
      },
    );

    _deadlineTimer?.cancel();
    _deadlineTimer =
        Timer.periodic(_deadlineCheckInterval, (_) => _checkDeadlines());
  }

  void _stopWatching() {
    _deadlineTimer?.cancel();
    _resumeSub?.cancel();
    _resumeSub = null;
  }

  /// Copies a resume payload onto the screen's state. Call inside setState.
  void _applyResume(OrderResumeState resume) {
    _orderStatus = resume.orderStatus ?? _orderStatus;
    if (resume.tailorSelectionDeadline != null) {
      _tailorSelectionDeadline = resume.tailorSelectionDeadline;
    }
    _quoteResponseDeadline = resume.quoteResponseDeadline;

    if (resume.tailorJobId != null && resume.status != null) {
      _tailorJob = TailorJob(
        id: resume.tailorJobId!,
        orderId: widget.orderId,
        tailorId: resume.tailorId ?? '',
        measurementId: _selectedMeasurement?.id ?? '',
        status: TailorJobStatus.fromValue(resume.status!),
        requestedAt: resume.requestedAt,
        quoteAmount: resume.quoteAmount,
        deliveryCharge: resume.deliverCharge,
        estimatedDeliveryDate: resume.estimatedDeliveryDate,
        rejectionReason: resume.rejectionReason,
        quoteResponseDeadline: resume.quoteResponseDeadline,
        quoteStatus: QuoteStatus.notSent,
        tailorPaymentStatus: resume.tailorPaymentStatus != null
            ? TailorPaymentStatus.fromValue(resume.tailorPaymentStatus!)
            : TailorPaymentStatus.unpaid,
      );
    }
  }

  /// Nothing is written to Firestore at the instant a window closes, so no
  /// snapshot can announce it — a clock has to notice. On the free tier
  /// there is no scheduled server job either, which makes the customer's
  /// own device the scheduler for their own order.
  Future<void> _checkDeadlines() async {
    if (!mounted || _checkingDeadlines) return;

    if (_isResolved) {
      _stopWatching();
      return;
    }

    _checkingDeadlines = true;
    try {
      // 72h first — it is the terminal one and outranks the 12h window.
      if (await _maybeExpireTailorSearch()) return;
      await _maybeExpireQuoteRequest();
    } catch (e) {
      debugPrint('[TailoringSetup] deadline check failed: \$e');
    } finally {
      _checkingDeadlines = false;
    }
  }

  /// Fires the expiry the deadline banner has always promised: once the
  /// window closes with no confirmed tailor, the order falls back to direct
  /// delivery. Returns true if it expired the search.
  Future<bool> _maybeExpireTailorSearch() async {
    final deadline = _tailorSelectionDeadline;
    if (deadline == null || DateTime.now().isBefore(deadline)) return false;

    // A job the customer already paid for is settled, not expired. A quote
    // sitting unanswered is NOT exempt — the banner's whole promise is that
    // an order with no confirmed tailor ships direct.
    final job = _tailorJob;
    if (job != null &&
        (job.status == TailorJobStatus.confirmed ||
            job.status == TailorJobStatus.inProgress ||
            job.status == TailorJobStatus.jobCompleted)) {
      return false;
    }

    await widget.callbacks.onTailorSearchExpired();
    if (!mounted) return true;

    setState(() {
      _orderStatus = OrderStatus.processing.toValue;
      _tailorJob = job?.copyWith(status: TailorJobStatus.expired);
    });
    _stopWatching();
    _showOrderCompleteDialog(
      'No tailor was confirmed in time, so your order was sent for direct '
      'delivery.',
    );
    return true;
  }

  /// The tailor let their 12h window lapse without quoting. The job dies but
  /// the order does NOT — the customer is handed back to the tailor search
  /// with whatever is left of their 72h.
  Future<void> _maybeExpireQuoteRequest() async {
    final job = _tailorJob;
    if (job == null || job.status != TailorJobStatus.pending) return;

    final deadline = _quoteResponseDeadline ??
        job.requestedAt?.add(TailoringService.tailorQuoteWindow);
    if (deadline == null || DateTime.now().isBefore(deadline)) return;

    await widget.callbacks.onQuoteRequestExpired();
    if (!mounted) return;

    setState(() {
      _orderStatus = OrderStatus.awaitingTailorSearch.toValue;
      _quoteResponseDeadline = null;
      _tailorJob = job.copyWith(
        status: TailorJobStatus.expired,
        rejectionReason: 'The tailor did not respond in time.',
      );
    });
    AppFeedback.show(
      context,
      "This tailor didn't respond in time. You can request another one.",
      isError: true,
    );
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
    // Anchored to NOW, not to orderDate. An order sits in
    // 'awaiting_confirmation' until the customer opens this screen, so a
    // customer who came back two days after checking out was handed a
    // deadline that had already passed — the very next poll expired their
    // search and shipped the fabric direct before they could pick anyone.
    // An existing deadline is reused so re-entering this step can't quietly
    // extend a window that is already running — and since placeOrder() now
    // stamps one at checkout, that is the normal path.
    final deadline = _tailorSelectionDeadline ??
        DateTime.now().add(TailoringService.tailorSelectionWindow);
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

  /// Opens the measurements editor through `MeasurementPage`, which owns
  /// the fetch-or-create and the save against `MeasurementService`. Pushing
  /// `MeasurementScreen` directly from here used to mean edits made inside
  /// the tailoring flow were never persisted.
  ///
  /// On return the profile is re-read, so `measurementId` sent with the
  /// tailor job is the real document id — including the first-time case
  /// where the customer had no profile when this screen was opened.
  Future<void> _goToMeasurementScreen() async {
    final customerId = UserSession.instance.uid;
    if (customerId == null || customerId.isEmpty) {
      AppFeedback.show(
        context,
        'Please sign in again to edit your measurements.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementPage(customerId: customerId),
      ),
    );

    if (!mounted) return;

    try {
      final updated = await MeasurementService().getMeasurement(customerId);
      if (!mounted || updated == null) return;
      setState(() {
        _savedMeasurements = [updated];
        _selectedMeasurement = updated;
        // Step 2's fields read from these controllers, so they have to be
        // rebuilt against the saved values rather than the stale ones.
        for (final c in _measurementControllers.values) {
          c.dispose();
        }
        _initMeasurementControllers();
      });
    } catch (e) {
      debugPrint('[TailoringSetup] measurement reload failed: $e');
    }
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

  /// Single order-level "Find Tailor" flow — no subOrderId involved.
  /// One tailor is picked to cover every sub-order in this order. If the
  /// customer backs out of BrowseShell without picking anyone,
  /// selectedTailorId is null and this is a no-op — no job is created,
  /// no backend call happens, and they stay in awaiting_tailor_search.
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
    // An empty measurementId reaches the tailor as "no measurements at all",
    // which they cannot sew from — better to stop here than to create a job
    // that has to be cancelled.
    if (_selectedMeasurement == null) {
      AppFeedback.show(
        context,
        "Add your measurement profile before requesting a tailor.",
        isError: true,
      );
      return;
    }

    String? jobId;
    await _withLoading(() async {
      jobId = await widget.callbacks.onCreateTailorJob(
        measurementId: _selectedMeasurement?.id ?? '',
        designIds: _designs.map((d) => d.path).toList(),
        tailorId: tailorId,
        instructions: _instructionsController.text.trim(),
      );
    });
    if (!mounted || jobId == null) return;
    setState(() {
      _tailorJob = TailorJob(
        id: jobId!,
        orderId: widget.orderId,
        tailorId: tailorId,
        measurementId: _selectedMeasurement?.id ?? '',
        status: TailorJobStatus.pending,
        requestedAt: DateTime.now(),
        quoteStatus: QuoteStatus.notSent,
        tailorPaymentStatus: TailorPaymentStatus.unpaid,
      );
    });
  }

  /// The tailor has already submitted quoteAmount / estimatedDeliveryDate
  /// / deliverCharge (via OrderStore.submitTailorQuote on their own
  /// screen) — the customer is only accepting what's already on the job,
  /// so this is a plain confirm dialog with no input fields.
  ///
  Future<void> _openChatWithTailor(String tailorId) async {
    final customerId = UserSession.instance.uid ?? '';

    // The tailor's display name lives on their Tailor document — falling
    // back to a generic label only if the lookup fails, so a slow or
    // offline profile fetch never blocks the chat from opening.
    String tailorName = 'Your Tailor';
    try {
      final tailor = await TailorService().getTailorProfile(tailorId);
      if (tailor != null && tailor.name.isNotEmpty) {
        tailorName = tailor.name;
      }
    } catch (e) {
      debugPrint('[TailoringSetup] tailor name lookup failed: $e');
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          // Deterministic per (order, tailor) pair so reopening the chat
          // lands on the same thread. NOTE: messaging itself is still
          // running on local sample data — see MessagingService, which no
          // screen is wired to yet.
          conversationId: '${widget.orderId}_$tailorId',
          customerId: customerId,
          otherUserId: tailorId,
          otherUserName: tailorName,
          otherUserRole: UserRole.tailor,
          currentUserRole: UserRole.customer,
          orderId: widget.orderId,
        ),
      ),
    );
  }

  void _promptConfirmTailorJob() {
    final job = _tailorJob;
    if (job == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Confirm Tailor Job"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your tailor sent the following quote. Confirming will charge "
              "you the total amount immediately.",
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _infoRow(
              icon: Icons.payments_outlined,
              label: "Total Cost",
              value: "Tk ${job.totalAmount?.toStringAsFixed(0) ?? '-'}",
            ),
            if (job.estimatedDeliveryDate != null) ...[
              const SizedBox(height: 10),
              _infoRow(
                icon: Icons.event_available_outlined,
                label: "Est. Delivery",
                value: _formatDateTime(job.estimatedDeliveryDate!),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _confirmTailorJob();
            },
            child: const Text("Confirm & Pay"),
          ),
        ],
      ),
    );
  }

  // REPLACE _confirmTailorJob with this:
  Future<void> _confirmTailorJob() async {
    final job = _tailorJob;
    if (job == null) return;

    final amount = job.totalAmount;
    if (amount == null || amount <= 0) {
      // No amount on job — fall back to legacy no-payment confirm.
      await _withLoading(() async {
        await widget.callbacks.onConfirmTailorJob();
        await widget.callbacks.onPayTailor();
      });
      if (!mounted) return;
      setState(() {
        _tailorJob = job.copyWith(
          status: TailorJobStatus.confirmed,
          tailorPaymentStatus: TailorPaymentStatus.paid,
        );
      });
      _checkResolvedAndMaybeComplete();
      return;
    }

    // bKash payment flow via in-app WebView:
    // Step 1+2: grant token, create payment — get bkashURL.
    late final String paymentID;
    late final String idToken;
    late final String bkashURL;

    await _withLoading(() async {
      final pending = await BkashService.instance.initiatePayment(
        amount: amount,
        invoicePrefix: 'TAILOR_${widget.orderId.replaceAll(RegExp(r"[^A-Za-z0-9]"), "")}',
      );
      paymentID = pending.paymentID;
      idToken = pending.idToken;
      bkashURL = pending.bkashURL;
    });

    if (!mounted) return;

    // Step 3: open bKash in an in-app WebView (auto-closes on redirect).
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BkashPaymentScreen(bkashURL: bkashURL),
      ),
    );

    if (!mounted || completed != true) return;

    // Step 4: execute payment + mark confirmed.
    await _withLoading(() async {
      final executed = await BkashService.instance.executePayment(
        paymentID: paymentID,
        idToken: idToken,
      );
      // Carry the real bKash trxID onto the tailor's Payments row. Without
      // it that row was written with a null transactionId, so a tailor
      // payment could not be matched back to bKash in a dispute — the
      // retailer rows have recorded it since checkout.
      await widget.callbacks.onConfirmTailorJob(
        transactionId: executed.trxID,
      );
      await widget.callbacks.onPayTailor();
    });

    if (!mounted) return;
    setState(() {
      _tailorJob = job.copyWith(
        status: TailorJobStatus.confirmed,
        tailorPaymentStatus: TailorPaymentStatus.paid,
      );
    });
    _checkResolvedAndMaybeComplete();
  }

  /// No reason required — the customer can simply decline the tailor's
  /// quote without justifying it.
  void _promptRejectTailorJob() {
    final job = _tailorJob;
    if (job == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Reject this job?"),
        content: const Text(
          "You're declining this tailor's quote. You can browse and "
          "request a different tailor afterward.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _rejectTailorJob();
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectTailorJob() async {
    final job = _tailorJob;
    if (job == null) return;
    await _withLoading(() => widget.callbacks.onRejectTailorJob());
    if (!mounted) return;
    setState(() {
      _tailorJob = job.copyWith(status: TailorJobStatus.rejected);
    });
  }

  /// Checks whether the order has now reached a resolved state and, if
  /// so, surfaces the order-complete dialog.
  void _checkResolvedAndMaybeComplete() {
    if (_isResolved) {
      _showOrderCompleteDialog("Your order has been arranged.");
    }
  }

  /// Shown once the order has actually reached a terminal state (skipped
  /// tailoring, or job resolved).
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
              // Close the dialog ONLY — the button says "Stay Here", so
              // popping the setup screen as well made it behave exactly like
              // "Track Order" minus the tracking screen.
              Navigator.pop(context);
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderTrackScreen(
                    orderId: widget.orderId,
                    userRole: UserRole.customer,
                  ),
                ),
              );
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
                                child: const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ))
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
                    color: isDone
                        ? Colors.green.shade800
                        : Colors.grey.shade200,
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
              child: Icon(
                Icons.check_rounded,
                color: Colors.green.shade800,
                size: 40,
              ),
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

  Widget _buildTailorDeclinedCard(TailorJob job) {
    return _statusCard(
      icon: Icons.cancel_outlined,
      iconBg: Colors.red.shade50,
      iconColor: Colors.red.shade700,
      title: "Tailor declined this job",
      subtitle: job.rejectionReason?.isNotEmpty == true
          ? "Reason: ${job.rejectionReason}"
          : "Your tailor wasn't able to take this job.",
      children: [
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _findTailor,
            icon: const Icon(Icons.storefront_rounded),
            label: const Text(
              "Browse Another Tailor",
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
              "match with one tailor for this whole order. Or skip this "
              "and have items delivered straight to you.",
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
    if (_savedMeasurements.isEmpty) {
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
                Icon(
                  Icons.straighten_rounded,
                  size: 14,
                  color: Colors.green.shade800,
                ),
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
                            horizontal: 12,
                            vertical: 14,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.green.shade800,
                            ),
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
          Icon(
            Icons.straighten_rounded,
            size: 40,
            color: Colors.green.shade200,
          ),
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
    return SingleChildScrollView(
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
          _designs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "No references added — that's okay, you can skip this.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: _designs.length,
                  itemBuilder: (context, index) =>
                      _buildDesignThumb(_designs[index]),
                ),
          const SizedBox(height: 18),
          const Text(
            "Instructions for your tailor",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            "Required — describe any changes, fit preferences, or details you want followed.",
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _instructionsController,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText:
                  "e.g. Slightly loose fit around the waist, full sleeves, no embroidery on the collar…",
              hintStyle: const TextStyle(fontSize: 12.5, color: Colors.black38),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.green.shade800),
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (_) {
              _saveLocalProgress();
              setState(() {});
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _instructionsController.text.trim().isEmpty
                  ? null
                  : () {
                      setState(() => _currentStep = 3);
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

  /// Single order-level tailor status card, plus a read-only list of the
  /// sub-orders this job covers (for visibility only — not independently
  /// assignable anymore).
  Widget _buildFindTailorStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeadlineBanner(),
          const SizedBox(height: 14),
          _buildTailorStatusCard(),
          if (widget.subOrders.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              "Items in this order",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              "One tailor covers everything below.",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...widget.subOrders.map(
              (subOrder) => _buildSubOrderVisibilityRow(subOrder),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTailorStatusCard() {
    final job = _tailorJob;

    if (job == null) return _buildNoTailorCard();

    switch (job.status) {
      case TailorJobStatus.pending:
        return _buildPendingCard(job);
      case TailorJobStatus.quoted:
        return _buildQuotedCard(job);
      case TailorJobStatus.confirmed:
      case TailorJobStatus.inProgress:
      case TailorJobStatus.jobCompleted:
        return _buildFinalizingCard();
      case TailorJobStatus.rejected:
        return _buildRejectedCard(job);
      case TailorJobStatus.tailorDeclined:
        return _buildTailorDeclinedCard(job);
      case TailorJobStatus.expired:
      case TailorJobStatus.cancelled:
        // A job expired because its tailor never answered leaves the order
        // open — the customer keeps whatever is left of their 72h and can
        // hire someone else. Only a closed SELECTION window is terminal.
        return _orderStatus == OrderStatus.processing.toValue
            ? _buildExpiredCard()
            : _buildQuoteTimedOutCard();
    }
  }

  /// Read-only row — just shows the retailer is part of this order. No
  /// per-retailer actions live here anymore; everything routes through
  /// the single order-level tailor card above.
  Widget _buildSubOrderVisibilityRow(SubOrder subOrder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront_rounded,
            size: 16,
            color: Colors.green.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Retailer: ${_retailerNames[subOrder.retailerId] ?? 'Loading…'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                // Broken out of the row total so the customer can see what
                // this retailer's delivery actually costs them.
                Text(
                  "Items Tk ${subOrder.itemsSubtotal.toStringAsFixed(0)}  •  "
                  "Delivery Tk ${subOrder.deliveryCharge.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "Tk ${subOrder.total.toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
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
          Icon(
            Icons.access_time_rounded,
            color: Colors.amber.shade800,
            size: 20,
          ),
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
          "Browse tailors and send one job request that covers your whole order.",
      children: [
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _findTailor,
            icon: const Icon(Icons.storefront_rounded),
            label: const Text(
              "Find Tailor",
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
    );
  }

  Widget _buildPendingCard(TailorJob job) {
    final deadline = _quoteResponseDeadline ??
        job.requestedAt?.add(TailoringService.tailorQuoteWindow);

    return _statusCard(
      icon: Icons.hourglass_top_rounded,
      iconBg: Colors.blue.shade50,
      iconColor: Colors.blue.shade700,
      title: "Waiting for tailor response",
      subtitle:
          "Requested ${job.requestedAt != null ? _formatDateTime(job.requestedAt!) : ''}. "
          "You'll be able to review a quote here once your tailor responds.",
      children: deadline == null
          ? const []
          : [
              const SizedBox(height: 16),
              _infoRow(
                icon: Icons.timer_outlined,
                label: "Responds by",
                value: _formatDateTime(deadline),
              ),
              const SizedBox(height: 8),
              Text(
                "If they haven't quoted by then you can pick another tailor.",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
    );
  }

  Widget _buildQuotedCard(TailorJob job) {
    return _statusCard(
      icon: Icons.receipt_long_rounded,
      iconBg: Colors.blue.shade50,
      iconColor: Colors.blue.shade700,
      title: "Tailor sent a quote",
      subtitle: "Review the price and delivery date below.",
      children: [
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _openChatWithTailor(job.tailorId),
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.green.shade800,
              size: 18,
            ),
            label: Text(
              "Chat with Tailor",
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 18),
        _infoRow(
          icon: Icons.payments_outlined,
          label: "Quote Amount",
          value: "Tk ${job.quoteAmount?.toStringAsFixed(0) ?? '-'}",
        ),
        const SizedBox(height: 10),
        _infoRow(
          icon: Icons.local_shipping_outlined,
          label: "Delivery Charge",
          value: "Tk ${job.deliveryCharge?.toStringAsFixed(0) ?? '0'}",
        ),
        const SizedBox(height: 10),
        _infoRow(
          icon: Icons.summarize_outlined,
          label: "Total Cost",
          value: "Tk ${job.totalAmount?.toStringAsFixed(0) ?? '-'}",
          emphasize: true,
        ),
        if (job.estimatedDeliveryDate != null) ...[
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.event_available_outlined,
            label: "Est. Delivery",
            value: _formatDateTime(job.estimatedDeliveryDate!),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _promptConfirmTailorJob,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade800,
                  side: BorderSide(color: Colors.green.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Confirm",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _promptRejectTailorJob,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Reject",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// No specific reason is shown — rejection is a plain "no thanks" from
  /// the customer, no rejectionReason field exists on the job anymore.
  Widget _buildRejectedCard(TailorJob job) {
    return _statusCard(
      icon: Icons.cancel_outlined,
      iconBg: Colors.red.shade50,
      iconColor: Colors.red.shade700,
      title: "You declined this quote",
      subtitle:
          "You rejected this tailor's quote. You can request another tailor below.",
      children: [
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _findTailor,
            icon: const Icon(Icons.storefront_rounded),
            label: const Text(
              "Find Another Tailor",
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
    );
  }

  Widget _buildFinalizingCard() {
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF2E7D32)),
          const SizedBox(height: 16),
          const Text(
            "Finalizing your order...",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredCard() {
    return _statusCard(
      icon: Icons.timer_off_outlined,
      iconBg: Colors.grey.shade200,
      iconColor: Colors.black54,
      title: "Tailor selection window closed",
      subtitle: "This order will be delivered directly to you instead.",
    );
  }

  /// The tailor let their 12h response window lapse. Same recovery options
  /// as an outright decline — the order is still open.
  Widget _buildQuoteTimedOutCard() {
    return _statusCard(
      icon: Icons.timer_off_outlined,
      iconBg: Colors.orange.shade50,
      iconColor: Colors.orange.shade800,
      title: "Tailor didn't respond in time",
      subtitle:
          "They had ${TailoringService.tailorQuoteWindow.inHours} hours to send "
          "a quote and didn't. Request another tailor before your selection "
          "window closes.",
      children: [
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _findTailor,
            icon: const Icon(Icons.storefront_rounded),
            label: const Text(
              "Find Another Tailor",
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
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize ? Colors.green.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: emphasize
            ? Border.all(color: Colors.green.shade300, width: 1)
            : null,
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
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontSize: emphasize ? 14 : 13,
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
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
      AppFeedback.show(context, "Couldn't save the sketch. Try again.",
          isError: true);
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
