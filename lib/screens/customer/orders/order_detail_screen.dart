import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sketch2stitch/models/order.dart' as db;
import 'package:sketch2stitch/models/sub_order.dart' as db;
import 'package:sketch2stitch/models/tailor_job.dart' as db;
import 'package:sketch2stitch/models/review.dart' as db;
import 'package:sketch2stitch/models/order_item.dart' as db;
import 'package:sketch2stitch/services/order_service.dart';
import 'package:sketch2stitch/services/review_service.dart';
import '../../../models/measurement.dart';
import 'reviews_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/top_feedback_banner.dart';
import 'package:sketch2stitch/services/user_session.dart';
import '../tailoring_setup_screen.dart';
import '../tailoring_callbacks.dart';

enum OrderDeliveryDestination { retailer, tailor }

enum TailorStatus { notAssigned, pending, quoted, cancelled, confirmed }

class OrderItem {
  final String name;
  final int quantity;
  final String imagePath;
  final String color;
  final String description;
  final String? itemComment;
  final bool canWash;
  final bool canBleach;
  final bool canDryClean;
  final bool canTumbleDry;
  final String ironLevel;
  final double price;
  final double? tailorPrice;
  final String? retailerName;
  final bool showCareInstructions;

  // New fields for Tailor reference
  final OrderDeliveryDestination destination;
  final List<String>? measurementRefImages;
  final String? tailorInstructions;
  final TailorStatus? tailorStatus;
  final DateTime? tailorDeliveryDate;
  final String? tailorJobId;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.imagePath,
    required this.color,
    required this.price,
    this.tailorPrice,
    this.retailerName,
    this.showCareInstructions = true,
    this.description = "Premium quality material with excellent durability and comfort.",
    this.itemComment,
    this.canWash = true,
    this.canBleach = false,
    this.canDryClean = true,
    this.canTumbleDry = true,
    this.ironLevel = "Medium",
    this.destination = OrderDeliveryDestination.retailer,
    this.measurementRefImages,
    this.tailorInstructions,
    this.tailorStatus,
    this.tailorDeliveryDate,
    this.tailorJobId,
  });
}

Widget _buildSmartImage(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  if (path.startsWith('http')) {
    return Image.network(path, width: width, height: height, fit: fit, errorBuilder: errorBuilder);
  } else {
    return Image.asset(path, width: width, height: height, fit: fit, errorBuilder: errorBuilder);
  }
}

class CustomerOrder {
  final String id;
  final String retailerName;
  final Map<String, String> retailerIds;
  final String? tailorName;
  final String? tailorId;
  final List<OrderItem> items;
  final List<db.SubOrder> rawSubOrders;
  final double amount;
  final DateTime orderDate;
  DateTime? deliveryDate;
  String status;
  bool isDelivered;
  final Map<String, String>? retailerReviews;
  final Map<String, double>? retailerRatings;
  final String? tailorReview;
  final double? tailorRating;
  final String deliveryAddress;
  final Map<String, double> deliveryCharges;
  final String? tailorCancellationReason;

  /// The measurement profile this order's tailor job was created against.
  /// `streamDetailedCustomerOrders` has always fetched it; nothing carried
  /// it this far, so "View My Measurements" could only ever report that
  /// there were none.
  final Measurement? tailorMeasurement;

  /// Retailers whose own sub-order has actually reached the customer.
  /// Reviewing is per-party, so a shop that hasn't shipped yet must not be
  /// rateable just because some other part of the order arrived.
  final Set<String> deliveredRetailerNames;

  /// The tailor finished (and therefore delivered) the garment.
  final bool tailorJobCompleted;

  /// When the requested tailor's 12h window to answer closes.
  final DateTime? tailorQuoteDeadline;

  /// The confirmed tailor job still hasn't been paid for. A job stays
  /// "Confirmed" through payment, so this is what separates "accepted, pay
  /// now" from "already settled".
  final bool tailorUnpaid;

  bool get canReviewAnyone =>
      isDelivered &&
      (deliveredRetailerNames.any((r) => retailerReviews?[r] == null) ||
      (tailorJobCompleted && tailorReview == null));

  CustomerOrder({
    required this.id,
    required this.retailerName,
    required this.retailerIds,
    this.tailorName,
    this.tailorId,
    required this.items,
    required this.rawSubOrders,
    required this.amount,
    required this.orderDate,
    required this.status,
    required this.isDelivered,
    required this.deliveryAddress,
    required this.deliveryCharges,
    this.deliveryDate,
    this.retailerReviews,
    this.retailerRatings,
    this.tailorReview,
    this.tailorRating,
    this.tailorCancellationReason,
    this.tailorMeasurement,
    this.deliveredRetailerNames = const {},
    this.tailorJobCompleted = false,
    this.tailorQuoteDeadline,
    this.tailorUnpaid = false,
  });

  String get _allRetailerNames {
    final names = items.map((i) => i.retailerName ?? retailerName).toSet().toList();
    if (names.length <= 1) return names.isNotEmpty ? names.first : "";
    if (names.length == 2) return "${names[0]} & ${names[1]}";
    return "${names[0]}, ${names[1]} & more";
  }

  List<String> get _uniqueRetailerNames {
    return items.map((i) => i.retailerName ?? retailerName).toSet().toList();
  }

  /// The tailoring quote, counted once.
  ///
  /// There is one Tailor-job per ORDER, and its `quoteAmount` is copied onto
  /// every tailored item so each card can display it. Summing across items
  /// therefore charged the same single quote once per garment — a 3-item
  /// order billed the stitching fee three times. Deduplicate by job id.
  double get _confirmedTailoringTotal {
    final seen = <String>{};
    double total = 0;
    for (final item in items) {
      // Deliberately NOT gated on `destination == tailor`: the sub-order's
      // deliveryDestination is reset to 'pending' whenever a tailor is
      // re-hired, which zeroed the confirmed stitching fee out of the grand
      // total while the tailor's delivery charge stayed in it. The job's own
      // status is the only thing that decides whether it is billable.
      if (item.tailorStatus != TailorStatus.confirmed) continue;
      final jobId = item.tailorJobId ?? '';
      if (!seen.add(jobId)) continue;
      total += item.tailorPrice ?? 0.0;
    }
    return total;
  }

  /// What the customer actually owes, at any stage of the order.
  ///
  /// There used to be a second "grand" variant for delivered orders that
  /// summed every delivery charge unconditionally, so the same order could
  /// total differently before and after delivery, and the sheet could list
  /// charges that its own total disagreed with. One rule now: retailer
  /// delivery always counts, tailoring and the tailor's delivery count only
  /// once the tailoring job is confirmed.
  double get totalGrandAmount {
    double delivery = 0;
    deliveryCharges.forEach((key, value) {
      if (key == tailorName) {
        if (hasConfirmedTailor) delivery += value;
      } else {
        delivery += value;
      }
    });

    return amount + _confirmedTailoringTotal + delivery;
  }

  /// True once any item's tailoring job is confirmed — the point at which the
  /// tailor's price and delivery charge become payable.
  bool get hasConfirmedTailor =>
      items.any((item) => item.tailorStatus == TailorStatus.confirmed);

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}

enum OrderFilterPreset { last3Months, last6Months, custom }

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  OrderFilterPreset _filterPreset = OrderFilterPreset.last3Months;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _showOngoing = true;
  String _selectedStatus = "All";
  Stream<List<Map<String, dynamic>>>? _orderStream;

  final Color primaryGreen = const Color(0xFF4F7942);

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _orderStream = OrderService().streamDetailedCustomerOrders(uid);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Structural Data Adapter: Translates raw backend structures into UI models.
  List<CustomerOrder> _mapFromBackend(List<Map<String, dynamic>> dbData) {
    final List<CustomerOrder> results = [];
    // `?? "No address set"` only covered a missing PROFILE. An account whose
    // address field is an empty string got past it and rendered as a blank
    // line under the "Shipping Address" heading — which is what "the address
    // doesn't show" looked like. Trim first, then decide.
    final String profileAddress =
        UserSession.instance.currentProfile.value?.address.trim() ?? "";
    final String deliveryAddress = profileAddress.isEmpty
        ? "No address set — add one in your profile"
        : profileAddress;

    for (var data in dbData) {
      final db.Order order = data['order'];
      final List<Map<String, dynamic>> subOrdersData = data['subOrders'] ?? [];
      final List<Map<String, dynamic>> tailorJobsData = data['tailorJobs'] ?? [];

      final List<db.SubOrder> subOrdersList = subOrdersData.map((s) => s['subOrder'] as db.SubOrder).toList();
      final db.Order orderWithDetails = order.copyWith(
        subOrders: subOrdersList,
        tailorJobs: tailorJobsData.map((t) => t['job'] as db.TailorJob).toList(),
      );

      final List<OrderItem> items = [];
      final Map<String, double> charges = {};
      String? tailorCancellationReason;
      
      double retailerAmount = 0;
      final Set<String> retailerNames = {};

      final List<db.Review> reviews = (data['reviews'] as List?)?.cast<db.Review>() ?? [];
      
      final Map<String, String> currentRetailerIds = {};
      final Set<String> deliveredRetailerNames = {};
      String? tailorIdStr;
      Measurement? tailorMeasurement;
      bool isTailorRejected = false;
      bool tailorJobCompleted = false;
      DateTime? tailorQuoteDeadline;
      bool tailorUnpaid = false;

      for (var soData in subOrdersData) {
        final db.SubOrder so = soData['subOrder'];
        final Map<String, dynamic> retailer = soData['retailer'] ?? {};
        final List<Map<String, dynamic>> itemsData = soData['items'] ?? [];

        retailerAmount += so.itemsSubtotal;
        final String currentRetailerName = retailer['shopName'] ?? "Supplier"; 
        retailerNames.add(currentRetailerName);
        currentRetailerIds[currentRetailerName] = so.retailerId;
        charges[currentRetailerName] =
            (charges[currentRetailerName] ?? 0) + so.deliveryCharge;
        // Only a sub-order that went to the CUSTOMER counts as delivered
        // for review purposes — one handed to the tailor is an internal hop.
        if (so.status == db.SubOrderStatus.delivered &&
            so.deliveryDestination == db.SubOrderDeliveryDestination.customer) {
          deliveredRetailerNames.add(currentRetailerName);
        }
        
        for (var iData in itemsData) {
          final db.OrderItem i = iData['item'];
          final Map<String, dynamic> p = iData['product'] ?? {};

          final List<dynamic> colorOptions = p['colorOptions'] ?? [];
          final option = colorOptions.firstWhere((o) => o['optionId'] == i.optionId, orElse: () => null);
          
          String imagePath = "assets/images/fabrics_rolled.jpg";
          if (option != null && option['image'] != null && (option['image'] as List).isNotEmpty) {
            imagePath = option['image'][0].toString();
          }

          final care = p['careSymbol'] as List? ?? [];
          final careKeys = care
              .map((c) => c.toString().toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''))
              .toList();

          items.add(OrderItem(
            name: p['productName'] ?? "Product", 
            quantity: i.quantity,
            price: (option?['price'] ?? 0).toDouble(), 
            imagePath: imagePath,
            color: option?['color'] ?? "Option ${i.optionId}",
            description: p['description'] ?? "Detailed specification.",
            // `care` holds full labels ("Washable", "Dry Clean Only",
            // "dryCleanOnly"), so this has to match within each label rather
            // than compare the list against a bare key — List.contains('wash')
            // looked for an element exactly equal to 'wash' and never matched,
            // leaving every care flag false.
            canWash: careKeys.any((s) => s.contains('wash')),
            canBleach: careKeys.any((s) => s.contains('bleach')),
            canDryClean: careKeys.any((s) => s.contains('dryclean')),
            canTumbleDry: careKeys.any((s) => s.contains('tumbledry')),
            retailerName: currentRetailerName,
            destination: so.deliveryDestination == db.SubOrderDeliveryDestination.tailor 
                ? OrderDeliveryDestination.tailor 
                : OrderDeliveryDestination.retailer,
          ));
        }
      }

      // Only the NEWEST tailor job describes where this order actually
      // stands. OrderService sorts them newest-first; an order picks up a
      // second job whenever a tailor declines or a quote is turned down and
      // the customer hires someone else, and looping over all of them let a
      // dead job overwrite the live one's price and status — and added its
      // delivery charge to the bill on top.
      if (tailorJobsData.isNotEmpty) {
        final tjData = tailorJobsData.first;
        final db.TailorJob tj = tjData['job'];
        final Map<String, dynamic> tailor = tjData['tailor'] ?? {};
        final List<String> designUrls =
            List<String>.from(tjData['designUrls'] ?? const <String>[]);

        tailorMeasurement = tjData['measurement'] as Measurement?;
        final String artisanName = tailor['name'] ?? "Artisan";
        tailorIdStr = tj.tailorId;
        tailorJobCompleted = tj.status == db.TailorJobStatus.jobCompleted;
        tailorUnpaid = tj.tailorPaymentStatus == db.TailorPaymentStatus.unpaid;
        tailorQuoteDeadline = tj.quoteResponseDeadline ??
            tj.requestedAt?.add(const Duration(hours: 12));
        final TailorStatus tailorStatus = _mapTailorStatus(tj.status);

        // A job nobody is working (declined, rejected, expired) delivers
        // nothing, so it must not carry a delivery charge into the total.
        final bool jobIsLive = tailorStatus == TailorStatus.pending ||
            tailorStatus == TailorStatus.quoted ||
            tailorStatus == TailorStatus.confirmed;
        if (jobIsLive) {
          charges[artisanName] = tj.deliveryCharge ?? 0;
        }

        // Attached to EVERY item, not just tailor-bound ones. The moment a
        // tailor declines, `Sub-orders.deliveryDestination` is reset to
        // 'pending' (OrderService.declineTailorJob), so gating on
        // `destination == tailor` wiped the tailor off this order entirely
        // the instant the customer most needed to see it — no status, no
        // reason, and no "browse tailor" link to recover with. One job
        // covers the whole order anyway.
        for (int i = 0; i < items.length; i++) {
          items[i] = OrderItem(
            name: items[i].name,
            quantity: items[i].quantity,
            price: items[i].price,
            imagePath: items[i].imagePath,
            color: items[i].color,
            description: items[i].description,
            canWash: items[i].canWash,
            canBleach: items[i].canBleach,
            canDryClean: items[i].canDryClean,
            canTumbleDry: items[i].canTumbleDry,
            retailerName: items[i].retailerName,
            destination: items[i].destination,
            tailorPrice: tj.quoteAmount,
            tailorStatus: tailorStatus,
            tailorDeliveryDate: tj.estimatedDeliveryDate,
            tailorJobId: tj.id,
            // Both were on the job all along and only the tailor's own
            // screen ever showed them, so the customer saw "No specific
            // instructions provided" under designs they had uploaded
            // themselves.
            tailorInstructions: tj.specialInstructions,
            measurementRefImages: designUrls,
          );
        }

        if (tj.status == db.TailorJobStatus.cancelled || tj.status == db.TailorJobStatus.tailorDeclined || tj.status == db.TailorJobStatus.rejected) {
          tailorCancellationReason = tj.rejectionReason;
          isTailorRejected = true;
        }
      }

      final Map<String, String> retailerReviewsMap = {};
      final Map<String, double> retailerRatingsMap = {};
      String? tailorReviewStr;
      double? tailorRatingVal;

      for (var r in reviews) {
        if (r.targetRole == db.ReviewTargetRole.tailor && r.targetId == tailorIdStr) {
          tailorReviewStr = r.comment;
          tailorRatingVal = r.rating;
        } else if (r.targetRole == db.ReviewTargetRole.retailer) {
          // Find which retailer this review belongs to based on targetId
          final rName = currentRetailerIds.entries
              .where((e) => e.value == r.targetId)
              .map((e) => e.key)
              .firstOrNull;
          if (rName != null) {
            retailerReviewsMap[rName] = r.comment;
            retailerRatingsMap[rName] = r.rating;
          }
        }
      }

      String mappedStatus = _mapStatusToFrontend(orderWithDetails.statusText);
      // A dead job hands the order back to the customer, which now reads as
      // 'Select a Tailor' rather than the old catch-all 'Order Preparing' —
      // true, but it buries the fact that someone said no. Say that instead.
      if (isTailorRejected &&
          (mappedStatus == 'Select a Tailor' ||
              mappedStatus == 'Choose Tailor or Skip' ||
              mappedStatus == 'Order Preparing')) {
        mappedStatus = 'Tailor Rejected';
      }

      results.add(CustomerOrder(
        id: order.id,
        retailerName: retailerNames.join(", "),
        retailerIds: currentRetailerIds,
        tailorName: order.tailorName,
        tailorId: tailorIdStr,
        items: items,
        rawSubOrders: subOrdersList,
        amount: retailerAmount,
        orderDate: order.orderDate,
        status: mappedStatus,
        isDelivered: order.status == db.OrderStatus.completed,
        deliveryAddress: deliveryAddress,
        deliveryCharges: charges,
        tailorCancellationReason: tailorCancellationReason,
        tailorMeasurement: tailorMeasurement,
        deliveredRetailerNames: deliveredRetailerNames,
        tailorJobCompleted: tailorJobCompleted,
        tailorQuoteDeadline: tailorQuoteDeadline,
        tailorUnpaid: tailorUnpaid,
        retailerReviews: retailerReviewsMap.isNotEmpty ? retailerReviewsMap : null,
        retailerRatings: retailerRatingsMap.isNotEmpty ? retailerRatingsMap : null,
        tailorReview: tailorReviewStr,
        tailorRating: tailorRatingVal,
      ));
    }
    return results;
  }

  TailorStatus _mapTailorStatus(db.TailorJobStatus status) {
    switch (status) {
      case db.TailorJobStatus.pending: return TailorStatus.pending;
      case db.TailorJobStatus.quoted: return TailorStatus.quoted;
      case db.TailorJobStatus.cancelled:
      case db.TailorJobStatus.tailorDeclined:
      case db.TailorJobStatus.rejected: return TailorStatus.cancelled;
      case db.TailorJobStatus.confirmed:
      case db.TailorJobStatus.inProgress:
      case db.TailorJobStatus.jobCompleted: return TailorStatus.confirmed;
      default: return TailorStatus.notAssigned;
    }
  }

  /// Every status this screen can show, in funnel order. Also drives the
  /// filter chips, so the two can't drift apart.
  static const List<String> ongoingStatuses = [
    'Choose Tailor or Skip',
    'Select a Tailor',
    'Waiting for Tailor Response',
    'Need Confirmation',
    'Tailor Rejected',
    'Tailor Confirmed',
    'Order Preparing',
    'Order Packed',
    'Items Delivered',
    'Out for Delivery',
  ];

  /// Maps `Order.statusText` onto this screen's vocabulary.
  ///
  /// The whole front half of the funnel used to land on 'Order Preparing':
  /// 'Awaiting Confirmation' was folded in with it, and 'Awaiting Tailor
  /// Selection' was mislabelled as waiting on a tailor who had never been
  /// asked. Both are decisions the CUSTOMER owes, and each now says so.
  String _mapStatusToFrontend(String backendStatus) {
    switch (backendStatus) {
      case 'Delivered':
        return 'Delivered';
      // Not the same thing as a finished order: every retailer has shipped,
      // but the order hasn't closed. Calling it 'Delivered' put a Delivered
      // badge on a card that still had no review section.
      case 'Items Delivered':
        return 'Items Delivered';
      case 'Order Packed':
        return 'Order Packed';
      case 'Awaiting Confirmation':
        return 'Choose Tailor or Skip';
      case 'Awaiting Tailor Selection':
        return 'Select a Tailor';
      case 'Requested Tailor':
      case 'Tailor Pending':
        return 'Waiting for Tailor Response';
      case 'Quote Received from Tailor':
        return 'Need Confirmation';
      case 'Tailor Confirmed — Stitching Started':
        return 'Tailor Confirmed';
      case 'Stitching Completed':
        return 'Out for Delivery';
      case 'Cancelled':
        return 'Cancelled';
      case 'Preparing Order':
      case 'Processing':
      default:
        return 'Order Preparing';
    }
  }

  DateTime get _startDate {
    final today = DateTime.now();
    switch (_filterPreset) {
      case OrderFilterPreset.last3Months:
        return DateTime(today.year, today.month - 3, today.day);
      case OrderFilterPreset.last6Months:
        return DateTime(today.year, today.month - 6, today.day);
      case OrderFilterPreset.custom:
        return _customStartDate ?? DateTime(today.year, today.month - 3, today.day);
    }
  }

  DateTime get _endDate {
    final today = DateTime.now();
    if (_filterPreset == OrderFilterPreset.custom && _customEndDate != null) {
      return _customEndDate!;
    }
    return DateTime(today.year, today.month, today.day, 23, 59, 59);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.08 : 16.0;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || _orderStream == null) {
      return const Scaffold(body: Center(child: Text("Please sign in to view history.")));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _orderStream,
      builder: (context, snapshot) {
        debugPrint("OrderDetailScreen: StreamBuilder update. State: ${snapshot.connectionState}");
        if (snapshot.hasError) {
          debugPrint("OrderDetailScreen: Stream error: ${snapshot.error}");
          return _buildErrorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final dbData = snapshot.data ?? [];
        if (dbData.isEmpty) {
          // Continue to build normal layout with empty list instead of full-screen empty state
          // so the user can see the Ongoing/Past toggles.
        }

        final orders = _mapFromBackend(dbData);
        final filteredOrders = _applyFiltersToOrders(orders);
        final ongoingOrders = filteredOrders.where((o) => !o.isDelivered).toList();
        final deliveredOrders = filteredOrders.where((o) => o.isDelivered).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF9FBF9),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 24),
              children: [
                _buildHeader(screenWidth, orders: orders),
                const SizedBox(height: 16),
                _buildSearchAndFilter(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _sectionToggle(
                        label: "Ongoing",
                        isSelected: _showOngoing,
                        count: ongoingOrders.length,
                        onTap: () => setState(() {
                          _showOngoing = true;
                          _selectedStatus = "All";
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _sectionToggle(
                        label: "Past Orders",
                        isSelected: !_showOngoing,
                        count: deliveredOrders.length,
                        onTap: () => setState(() {
                          _showOngoing = false;
                          _selectedStatus = "All";
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_showOngoing)
                  _ordersSection(
                    title: "Ongoing Orders",
                    icon: Icons.local_shipping_outlined,
                    orders: ongoingOrders,
                    allOrders: orders,
                    emptyText: "You have no active orders",
                  )
                else
                  _ordersSection(
                    title: "Delivered Orders",
                    icon: Icons.check_circle_outline,
                    orders: deliveredOrders,
                    allOrders: orders,
                    emptyText: "No past orders found",
                  ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync_problem, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Synchronization delay.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Optimizing data flow. Please stand by.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => setState(() {}), child: const Text("Retry")),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth, {List<CustomerOrder>? orders}) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Order History",
            style: TextStyle(
              fontSize: screenWidth > 400 ? 30 : 24,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
        ),
        if (orders != null)
          IconButton(
            onPressed: () => _showFilterSheet(orders),
            icon: Icon(Icons.filter_list, color: primaryGreen),
            tooltip: "Filter orders",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  List<CustomerOrder> _applyFiltersToOrders(List<CustomerOrder> orders) {
    return orders.where((order) {
      final date = order.orderDate;
      final matchesDate = !date.isBefore(_startDate) && !date.isAfter(_endDate);
      final matchesStatus = _selectedStatus == "All" || order.status == _selectedStatus;
      return matchesDate && matchesStatus;
    }).where((order) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final matchesId = order.id.toLowerCase().contains(query);
      final matchesRetailer = order.retailerName.toLowerCase().contains(query);
      final matchesProduct = order.items.any((i) => i.name.toLowerCase().contains(query));
      return matchesId || matchesRetailer || matchesProduct;
    }).toList();
  }

  Widget _buildSearchAndFilter() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: const InputDecoration(
          hintText: "Search order ID, product...",
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  void _showFilterSheet(List<CustomerOrder> allOrders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42, height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Filter orders", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterPreset = OrderFilterPreset.last3Months;
                          _customStartDate = null;
                          _customEndDate = null;
                          _selectedStatus = "All";
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Reset All"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Date Range", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip("Last 3 months", _filterPreset == OrderFilterPreset.last3Months, () {
                      setSheetState(() => _filterPreset = OrderFilterPreset.last3Months);
                      setState(() => _filterPreset = OrderFilterPreset.last3Months);
                    }),
                    _filterChip("Last 6 months", _filterPreset == OrderFilterPreset.last6Months, () {
                      setSheetState(() => _filterPreset = OrderFilterPreset.last6Months);
                      setState(() => _filterPreset = OrderFilterPreset.last6Months);
                    }),
                    _filterChip(
                      _filterPreset == OrderFilterPreset.custom && _customStartDate != null
                          ? "${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}"
                          : "Custom Range",
                      _filterPreset == OrderFilterPreset.custom,
                      () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (range != null) {
                          setSheetState(() {
                            _filterPreset = OrderFilterPreset.custom;
                            _customStartDate = range.start;
                            _customEndDate = range.end.add(const Duration(hours: 23, minutes: 59));
                          });
                          setState(() {
                            _filterPreset = OrderFilterPreset.custom;
                            _customStartDate = range.start;
                            _customEndDate = range.end.add(const Duration(hours: 23, minutes: 59));
                          });
                        }
                      },
                      icon: Icons.calendar_month,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_showOngoing) ...[
                  const Text("Status", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <String>[
                      "All",
                      ...ongoingStatuses,
                    ].map((status) {
                      return _filterChip(status, _selectedStatus == status, () {
                        setSheetState(() => _selectedStatus = status);
                        setState(() => _selectedStatus = status);
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryGreen : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionToggle({required String label, required bool isSelected, required int count, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? primaryGreen : Colors.green.shade100, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: primaryGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))] : [],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.green.shade900, fontSize: 16, fontWeight: FontWeight.w900)),
            Text("$count orders", style: TextStyle(color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _ordersSection({required String title, required IconData icon, required List<CustomerOrder> orders, required List<CustomerOrder> allOrders, required String emptyText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: primaryGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            if (!_showOngoing) ...[
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerReviewsScreen()),
                  );
                },
                icon: const Icon(Icons.star_outline, size: 16),
                label: const Text("See Reviews"),
                style: TextButton.styleFrom(
                  foregroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          _emptyOrdersCard(emptyText)
        else
          ...orders.map((o) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _orderCard(o, allOrders))),
      ],
    );
  }

  Widget _emptyOrdersCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
    );
  }

  Widget _orderCard(CustomerOrder order, List<CustomerOrder> allOrders) {
    final statusColor = _getOrderStatusColor(order.status, order.isDelivered);

    return GestureDetector(
      onTap: () => _showOrderDetail(order, allOrders),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.id, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      Text(order._allRetailerNames, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                  child: Text(order.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildSmartImage(
                      item.imagePath, width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(width: 44, height: 44, color: Colors.green.shade50, child: Icon(Icons.shopping_bag, color: primaryGreen, size: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text("Qty: ${item.quantity} | ${item.color}", style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Text("Tk ${(item.price * item.quantity).toInt()}", style: TextStyle(color: Colors.green.shade900, fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            )),
            const SizedBox(height: 4),
            Row(
              children: [
                _orderInfo(Icons.calendar_today_outlined, _formatDate(order.orderDate)),
                const Spacer(),
                Text(
                  "Total: Tk ${order.totalGrandAmount.toInt()}",
                  style: TextStyle(color: Colors.green.shade900, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            if ((order.retailerReviews?.isNotEmpty ?? false) || order.tailorReview != null) ...[
              const SizedBox(height: 12),
              _buildCardReviewSummary(order),
            ] else if (order.canReviewAnyone) ...[
              const SizedBox(height: 12),
              _buildCardLeaveReviewPrompt(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardReviewSummary(CustomerOrder order) {
    final rating = (order.retailerRatings?.isNotEmpty ?? false) ? order.retailerRatings!.values.first : (order.tailorRating ?? 0.0);
    final review = (order.retailerReviews?.isNotEmpty ?? false) ? order.retailerReviews!.values.first : (order.tailorReview ?? "");
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.blue.shade800, size: 14),
          const SizedBox(width: 4),
          Text(rating.toString(), style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: Text(review, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontStyle: FontStyle.italic))),
        ],
      ),
    );
  }

  Widget _buildCardLeaveReviewPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, color: Colors.orange.shade800, size: 14),
          const SizedBox(width: 6),
          Text("Leave a review", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }

  void _showOrderDetail(CustomerOrder order, List<CustomerOrder> allOrders) {
    final currentOrderRef = allOrders.firstWhere((o) => o.id == order.id);
    final uniqueRetailers = currentOrderRef._uniqueRetailerNames;

    Map<String, double> tempRetailerRatings = {for (var r in uniqueRetailers) r: 0.0};
    Map<String, TextEditingController> retailerControllers = {for (var r in uniqueRetailers) r: TextEditingController()};

    double tempTailorRating = 0;
    final tailorController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (stfContext, setModalState) {
          final bottomInset = MediaQuery.of(stfContext).viewInsets.bottom;
          final currentOrder = allOrders.firstWhere((o) => o.id == order.id);

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Order Details", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Text("ID: ${currentOrder.id}", style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _infoBadge(
                          currentOrder.status,
                          _getOrderStatusColor(currentOrder.status, currentOrder.isDelivered).withValues(alpha: 0.1),
                          _getOrderStatusColor(currentOrder.status, currentOrder.isDelivered),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text("Products", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...currentOrder.items.map((item) => _itemPreviewCard(item)),
                  if (currentOrder.tailorCancellationReason != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red.shade800, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Cancellation: ${currentOrder.tailorCancellationReason}",
                              style: TextStyle(color: Colors.red.shade900, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Keyed off "this order has a tailor job", NOT off where the
                  // fabric is currently routed — a declined job resets
                  // deliveryDestination to 'pending', which used to make this
                  // whole section (and its recovery link) vanish.
                  if (currentOrder.items.any((i) => i.tailorStatus != null)) ...[
                    const SizedBox(height: 30),
                    const Text("Tailor Customization Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // One tailor job covers the whole order — status, quote,
                    // delivery date, reference images and instructions are
                    // all copied onto every item identically. Mapping over
                    // every tailored item rendered the exact same card once
                    // per product; it only needs to be shown once.
                    _tailorCustomizationCard(
                      currentOrder.items.firstWhere((i) => i.tailorStatus != null),
                      currentOrder,
                    ),
                  ],
                  const SizedBox(height: 30),
                  const Text("Order Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _detailRow("Retailer(s)", currentOrder._allRetailerNames),
                  if (currentOrder.tailorName != null) _buildTailorSummaryRow(currentOrder),
                  _detailRow("Total Items", "${currentOrder.totalQuantity} units"),
                  _detailRow("Order Date", _formatDate(currentOrder.orderDate)),
                  if (currentOrder.deliveryDate != null) _detailRow("Delivery Date", _formatDate(currentOrder.deliveryDate!)),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  ...currentOrder.deliveryCharges.entries.where((entry) {
                    // Same rule as `totalGrandAmount`: the tailor's delivery
                    // charge is listed exactly when it is being charged.
                    if (entry.key == currentOrder.tailorName &&
                        !currentOrder.hasConfirmedTailor) {
                      return false;
                    }
                    return true;
                  }).map((entry) => _detailRow("Delivery (${entry.key})", "Tk ${entry.value.toInt()}")),
                  const SizedBox(height: 20),
                  const Text("Shipping Address", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: primaryGreen),
                            const SizedBox(width: 8),
                            Expanded(child: Text(currentOrder.deliveryAddress, style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => launchUrl(
                            Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(currentOrder.deliveryAddress)}'),
                            mode: LaunchMode.externalApplication,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map_outlined, size: 15, color: primaryGreen),
                              const SizedBox(width: 4),
                              Text(
                                'Open in Maps',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen, decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Grand Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text(
                        "Tk ${currentOrder.totalGrandAmount.toInt()}",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                  // Reviewing is only allowed once the entire order is delivered
                  // (i.e. it has moved to the "Past Orders" section).
                  if (currentOrder.isDelivered ||
                      (currentOrder.retailerReviews?.isNotEmpty ?? false) ||
                      currentOrder.tailorReview != null) ...[
                    const SizedBox(height: 35),
                    if ((currentOrder.retailerReviews?.isNotEmpty ?? false) || currentOrder.tailorReview != null) ...[
                      const Text("Your Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (currentOrder.retailerReviews != null)
                        ...currentOrder.retailerReviews!.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _reviewCard("${entry.key} Review", entry.value, currentOrder.retailerRatings?[entry.key] ?? 0.0, Colors.blue),
                        )),
                      if (currentOrder.tailorReview != null) ...[
                        // Named, like the retailer cards beside it — "Tailor
                        // Review" left the reader to work out which of the
                        // order's parties the rating was actually about.
                        _reviewCard("${currentOrder.tailorName ?? 'Tailor'} Review", currentOrder.tailorReview!, currentOrder.tailorRating ?? 0.0, Colors.orange),
                      ],
                      const SizedBox(height: 24),
                    ],

                    if (currentOrder.canReviewAnyone) ...[
                      const Text("Leave a Review", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...uniqueRetailers
                          .where((r) =>
                              currentOrder.deliveredRetailerNames.contains(r) &&
                              currentOrder.retailerReviews?[r] == null)
                          .map((retailer) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildLeaveReviewCard(
                          title: "Rate $retailer",
                          themeColor: Colors.blue,
                          currentRating: tempRetailerRatings[retailer] ?? 0,
                          controller: retailerControllers[retailer]!,
                          onRatingChanged: (r) => setModalState(() => tempRetailerRatings[retailer] = r),
                          onSubmit: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (tempRetailerRatings[retailer] == 0) {
                              AppFeedback.show(context, "Please select a rating for $retailer", isError: true);
                              return;
                            }
                            // No placeholder id: "supplier_id" would have
                            // written a review against an account that
                            // doesn't exist, invisible to everyone.
                            final retailerId = currentOrder.retailerIds[retailer];
                            if (uid == null || retailerId == null || retailerId.isEmpty) {
                              AppFeedback.show(context, "Couldn't identify this shop. Please reopen the order.", isError: true);
                              return;
                            }

                            try {
                              await ReviewService().submitReview(
                                orderId: currentOrder.id,
                                customerId: uid,
                                recipientId: retailerId,
                                rating: tempRetailerRatings[retailer]!,
                                comment: retailerControllers[retailer]!.text,
                                type: db.ReviewTargetRole.retailer,
                              );
                              Navigator.pop(modalContext);
                              AppFeedback.show(context, "Review for $retailer submitted!");
                            } catch (e) {
                              AppFeedback.show(context, "Synchronization delay. Please try again.", isError: true);
                            }
                          },
                        ),
                      )),
                      const SizedBox(height: 12),
                      // Gated on the JOB being finished, not on the fabric
                      // merely having been routed to a tailor — that was true
                      // from the moment the job was created.
                      if (currentOrder.tailorJobCompleted && currentOrder.tailorReview == null)
                        _buildLeaveReviewCard(
                          title: "Rate ${currentOrder.tailorName ?? 'Tailor'}",
                          themeColor: Colors.orange,
                          currentRating: tempTailorRating,
                          controller: tailorController,
                          onRatingChanged: (r) => setModalState(() => tempTailorRating = r),
                          onSubmit: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (tempTailorRating == 0) {
                              AppFeedback.show(context, "Please select a rating", isError: true);
                              return;
                            }
                            final tailorId = currentOrder.tailorId;
                            if (uid == null || tailorId == null || tailorId.isEmpty) {
                              AppFeedback.show(context, "Couldn't identify this tailor. Please reopen the order.", isError: true);
                              return;
                            }

                            try {
                              await ReviewService().submitReview(
                                orderId: currentOrder.id,
                                customerId: uid,
                                recipientId: tailorId,
                                rating: tempTailorRating,
                                comment: tailorController.text,
                                type: db.ReviewTargetRole.tailor,
                              );
                              Navigator.pop(modalContext);
                              AppFeedback.show(context, "Tailor review submitted!");
                            } catch (e) {
                              AppFeedback.show(context, "Synchronization delay. Please try again.", isError: true);
                            }
                          },
                        ),
                    ],
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _itemPreviewCard(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildSmartImage(
                  item.imagePath,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  // The order card above already falls back; without the same
                  // guard here a product whose image 404s rendered Flutter's
                  // broken-image box in the middle of the detail sheet.
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 90,
                    height: 90,
                    color: Colors.green.shade50,
                    child: Icon(Icons.shopping_bag, color: primaryGreen, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("Qty: ${item.quantity} | Color: ${item.color}", style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (item.retailerName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("Retailer: ${item.retailerName}", style: TextStyle(color: primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),
              Text("Tk ${(item.price * item.quantity).toInt()}", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900)),
            ],
          ),
          if (item.showCareInstructions) ...[
            const SizedBox(height: 16),
            const Text("Care Instructions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _careTag(Icons.wash, "Wash", item.canWash),
                _careTag(Icons.biotech, "Bleach", item.canBleach),
                _careTag(Icons.dry_cleaning, "Dry Clean", item.canDryClean),
                _careTag(Icons.iron, "Iron: ${item.ironLevel}", true),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tailorCustomizationCard(OrderItem item, CustomerOrder currentOrder) {
    final bool isDelivered = currentOrder.isDelivered;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // One tailor job, potentially covering several products —
                    // list them all rather than naming just the one item
                    // this card happens to have been built from.
                    Text(
                      currentOrder.items.where((i) => i.tailorStatus != null).map((i) => i.name).join(', '),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    if (isDelivered && item.tailorPrice != null)
                      Text("Stitching Price: Tk ${item.tailorPrice!.toInt()}", style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  if (item.tailorStatus != null && !isDelivered && item.tailorStatus != TailorStatus.notAssigned && item.tailorStatus != TailorStatus.cancelled)
                    _tailorStatusBadge(item.tailorStatus!),
                ],
              ),
            ],
          ),
          if (item.tailorStatus != null && !isDelivered) ...[
            if (item.tailorStatus == TailorStatus.pending)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.blue.shade900, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentOrder.tailorQuoteDeadline != null
                            ? "Tailor will accept or reject your request by "
                                "${_formatDate(currentOrder.tailorQuoteDeadline!)}. "
                                "If they don't, you can pick another tailor."
                            : "Tailor will accept or reject your request within 12 hours.",
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else if (item.tailorStatus == TailorStatus.quoted || item.tailorStatus == TailorStatus.confirmed)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Stitching Price:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text("Tk ${item.tailorPrice?.toInt() ?? 0}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryGreen)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Est. Delivery Date:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(item.tailorDeliveryDate != null ? _formatDate(item.tailorDeliveryDate!) : "TBD", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryGreen)),
                      ],
                    ),
                    if (item.tailorStatus == TailorStatus.quoted) ...[
                      const Divider(height: 20),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TailoringSetupScreen(
                                orderId: currentOrder.id,
                                orderDate: currentOrder.orderDate,
                                savedMeasurements: const [],
                                subOrders: currentOrder.rawSubOrders,
                                callbacks: buildTailoringCallbacks(currentOrder.id),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: "If you want to confirm or reject ", style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                                TextSpan(text: "go to Checkout", style: TextStyle(color: Colors.green.shade800, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    // A job stays "Confirmed" from the moment the quote is
                    // accepted until the stitching fee is actually settled,
                    // and the customer had no way back into the payment step
                    // from here. Same route as the quote link — the setup
                    // screen resumes the job at whatever step it's on.
                    if (item.tailorStatus == TailorStatus.confirmed && currentOrder.tailorUnpaid) ...[
                      const Divider(height: 20),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TailoringSetupScreen(
                                orderId: currentOrder.id,
                                orderDate: currentOrder.orderDate,
                                savedMeasurements: const [],
                                subOrders: currentOrder.rawSubOrders,
                                callbacks: buildTailoringCallbacks(currentOrder.id),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: "To review payment and pay ", style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                                TextSpan(text: "go to Checkout", style: TextStyle(color: Colors.green.shade800, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else if (item.tailorStatus == TailorStatus.notAssigned || item.tailorStatus == TailorStatus.cancelled)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade900, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                          children: [
                            const TextSpan(text: "If you want to assign tailor "),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  // Browsing has to happen inside the
                                  // checkout flow: that's the only path
                                  // that creates the tailor job and writes
                                  // it back to the order.
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TailoringSetupScreen(
                                        orderId: currentOrder.id,
                                        orderDate: currentOrder.orderDate,
                                        savedMeasurements: const [],
                                        subOrders: currentOrder.rawSubOrders,
                                        callbacks: buildTailoringCallbacks(currentOrder.id),
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  "browse tailor",
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w900,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          if (item.measurementRefImages != null && item.measurementRefImages!.isNotEmpty) ...[
            const Text(
              "Reference Images:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: item.measurementRefImages!.length,
              itemBuilder: (context, index) {
                final imgPath = item.measurementRefImages![index];
                return GestureDetector(
                  onTap: () => _showFullScreenImage(imgPath),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildSmartImage(
                      imgPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Instructions:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                item.tailorInstructions ?? "No specific instructions provided.",
                style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showMeasurements(currentOrder.tailorMeasurement),
                icon: const Icon(Icons.straighten, size: 14),
                label: const Text("View My Measurements", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: primaryGreen,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: _buildSmartImage(imagePath, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.download, color: Colors.white, size: 30),
                onPressed: () {
                  AppFeedback.show(context, "Asset synchronization started...");
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _careTag(IconData icon, String label, bool isOk) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isOk ? Colors.green.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(icon, size: 12, color: isOk ? Colors.green.shade700 : Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOk ? Colors.green.shade800 : Colors.grey)),
      ]),
    );
  }

  Widget _infoBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Color _getOrderStatusColor(String status, bool isDelivered) {
    if (isDelivered) return primaryGreen;
    switch (status) {
      // case "Cancelled": return Colors.red.shade800;
      // case "Awaiting artisan": return Colors.orange.shade800;
      // case "Processing": return Colors.blue.shade800;
      case "Tailor Rejected": return Colors.red.shade800;
      case "Cancelled": return Colors.grey.shade700;
      case "Choose Tailor or Skip": return Colors.amber.shade800;
      case "Select a Tailor": return Colors.purple.shade700;
      case "Waiting for Tailor Response": return Colors.orange.shade800;
      case "Need Confirmation": return Colors.deepOrange.shade700;
      case "Order Preparing": return Colors.blue.shade800;
      case "Order Packed": return Colors.teal.shade700;
      case "Items Delivered": return Colors.teal.shade800;
      case "Tailor Confirmed": return Colors.indigo.shade700;
      case "Out for Delivery": return Colors.deepPurple.shade700;
      default: return Colors.blueAccent;
    }
  }

  Widget _tailorStatusBadge(TailorStatus status) {
    final color = _getTailorStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        _getTailorStatusText(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _getTailorStatusText(TailorStatus status) {
    switch (status) {
      case TailorStatus.notAssigned:
      case TailorStatus.pending:
      case TailorStatus.cancelled: return "Sent to Tailor";
      case TailorStatus.quoted: return "Need Confirmation";
      case TailorStatus.confirmed: return "Confirmed";
    }
  }

  Color _getTailorStatusColor(TailorStatus status) {
    switch (status) {
      case TailorStatus.notAssigned: return Colors.grey.shade600;
      case TailorStatus.pending: return Colors.orange.shade800;
      case TailorStatus.cancelled: return Colors.red.shade800;
      case TailorStatus.quoted: return Colors.orange.shade800;
      case TailorStatus.confirmed: return primaryGreen;
    }
  }

  Widget _buildTailorSummaryRow(CustomerOrder order) {
    if (order.tailorName == null) return const SizedBox.shrink();
    final statuses = order.items.map((i) => i.tailorStatus).toSet();
    if (statuses.contains(TailorStatus.cancelled) || statuses.contains(TailorStatus.notAssigned)) {
      if (!statuses.contains(TailorStatus.confirmed) && !statuses.contains(TailorStatus.pending)) {
        return const SizedBox.shrink();
      }
    }
    String displayText = order.tailorName!;
    if (statuses.contains(TailorStatus.pending) && !statuses.contains(TailorStatus.confirmed)) {
      displayText = "$displayText (pending)";
    }
    return _detailRow("Tailor", displayText);
  }

  Widget _reviewCard(String title, String review, double rating, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: themeColor.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  Icon(Icons.star, color: themeColor.withValues(alpha: 0.8), size: 16),
                  const SizedBox(width: 4),
                  Text(rating.toString(), style: TextStyle(color: themeColor.withValues(alpha: 0.9), fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text("\"$review\"", style: const TextStyle(color: Colors.black87, fontSize: 14, fontStyle: FontStyle.italic, height: 1.4, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLeaveReviewCard({
    required String title,
    required Color themeColor,
    required double currentRating,
    required TextEditingController controller,
    required Function(double) onRatingChanged,
    required VoidCallback onSubmit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: themeColor.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) => GestureDetector(
              onTap: () => onRatingChanged(index + 1.0),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(index < currentRating ? Icons.star : Icons.star_outline, color: index < currentRating ? themeColor : themeColor.withValues(alpha: 0.4), size: 28),
              ),
            )),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Write your feedback...",
              hintStyle: const TextStyle(fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("Submit Review", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }

  /// [meas] comes from `CustomerOrder.tailorMeasurement` — the profile the
  /// tailor job was actually created against, which the order stream
  /// already loads. This used to be handed a TailorJob whose `measurements`
  /// list is never populated by any read path, so it always bailed out.
  void _showMeasurements(Measurement? meas) {
    if (meas == null) {
      AppFeedback.show(context, "Specifications not yet available for this assignment.", isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const Text("Body Measurements", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Specifications used for this service assignment.", style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 20),
            Expanded(child: ListView(children: [
              _measurementTile("Upper Bust", meas.upperBustCircumference),
              _measurementTile("Bust", meas.bustCircumference),
              _measurementTile("Under Bust", meas.underBustCircumference),
              _measurementTile("Round Shoulder", meas.roundShoulderCircumference),
              _measurementTile("Waist", meas.waist),
              _measurementTile("Hips", meas.hipsCircumference),
              _measurementTile("Shoulder to Bust", meas.shoulderToBust),
              _measurementTile("Shoulder to Under Bust", meas.shoulderToUnderBust),
              _measurementTile("Shoulder to Knee", meas.shoulderToKnee),
              _measurementTile("Shoulder to Ankle", meas.shoulderToAnkle),
              _measurementTile("Waist to Ankle", meas.waistToAnkle),
              _measurementTile("Thigh", meas.thigh),
              _measurementTile("Knee", meas.knee),
              _measurementTile("Ankle", meas.ankle),
            ])),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _measurementTile(String label, double value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)), child: Text("$value in", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))),
    ]));
  }

  String _formatDate(DateTime date) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }
}
